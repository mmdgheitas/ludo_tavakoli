import { createHash, randomBytes, randomInt, randomUUID } from 'node:crypto';
import { BadRequestException, ConflictException, Injectable, UnauthorizedException } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { JwtService } from '@nestjs/jwt';
import { Prisma, User, UserRole, UserStatus } from '@prisma/client';
import { compare, hash } from 'bcryptjs';
import { JwtPayload } from '../../common/auth/jwt-payload';
import { PrismaService } from '../../prisma/prisma.service';
import { AdminLoginDto, ForgotPasswordDto, GuestAuthDto, LoginDto, RegisterDto, ResetPasswordDto } from './dto/auth.dto';
import { MailService } from './mail.service';

interface SessionContext { ipAddress?: string; userAgent?: string }

export type PublicUser = Pick<User, 'id' | 'username' | 'email' | 'avatarUrl' | 'coinBalance' | 'fattahBalance' | 'vipExpiresAt' | 'role'>;

export interface AuthResponse {
  accessToken: string;
  refreshToken: string;
  user: PublicUser;
}

@Injectable()
export class AuthService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly jwt: JwtService,
    private readonly config: ConfigService,
    private readonly mail: MailService,
  ) {}

  async register(dto: RegisterDto, context: SessionContext): Promise<AuthResponse> {
    const username = this.normalizeUsername(dto.username);
    const email = dto.email.trim().toLowerCase();
    const existing = await this.prisma.user.findFirst({
      where: { OR: [{ username }, { email }] },
      select: { username: true, email: true },
    });
    if (existing?.username === username) throw new ConflictException('Username is already in use');
    if (existing?.email === email) throw new ConflictException('Email is already in use');
    try {
      const user = await this.prisma.user.create({
        data: { username, email, passwordHash: await hash(dto.password, 12) },
      });
      return this.issueTokens(user, context);
    } catch (error) {
      if (error instanceof Prisma.PrismaClientKnownRequestError && error.code === 'P2002') {
        throw new ConflictException('Username or email is already in use');
      }
      throw error;
    }
  }

  async login(dto: LoginDto, context: SessionContext): Promise<AuthResponse> {
    const identifier = dto.identifier.trim().toLowerCase();
    const user = await this.prisma.user.findFirst({
      where: { OR: [{ username: identifier }, { email: identifier }] },
    });
    if (!user?.passwordHash || user.status !== UserStatus.ACTIVE || !(await compare(dto.password, user.passwordHash))) {
      throw new UnauthorizedException('Invalid username/email or password');
    }
    await this.prisma.user.update({ where: { id: user.id }, data: { lastSeenAt: new Date() } });
    return this.issueTokens(user, context);
  }

  async guest(dto: GuestAuthDto, context: SessionContext): Promise<AuthResponse> {
    let user = await this.prisma.user.findUnique({ where: { deviceId: dto.deviceId } });
    if (user?.status === UserStatus.BANNED) throw new UnauthorizedException('Account is banned');
    if (!user) {
      const username = await this.uniqueUsername(dto.displayName);
      user = await this.prisma.user.create({ data: { username, deviceId: dto.deviceId } });
    } else {
      user = await this.prisma.user.update({ where: { id: user.id }, data: { lastSeenAt: new Date() } });
    }
    return this.issueTokens(user, context);
  }

  async adminLogin(dto: AdminLoginDto, context: SessionContext): Promise<AuthResponse> {
    const user = await this.prisma.user.findUnique({ where: { username: this.normalizeUsername(dto.username) } });
    if (!user?.passwordHash || user.status !== UserStatus.ACTIVE || user.role === UserRole.PLAYER || !(await compare(dto.password, user.passwordHash))) {
      throw new UnauthorizedException('Invalid credentials');
    }
    return this.issueTokens(user, context);
  }

  async refresh(rawToken: string, context: SessionContext): Promise<AuthResponse> {
    let payload: JwtPayload;
    try { payload = await this.jwt.verifyAsync<JwtPayload>(rawToken, { secret: this.refreshSecret }); }
    catch { throw new UnauthorizedException('Refresh token is invalid or expired'); }
    if (payload.type !== 'refresh' || !payload.sid) throw new UnauthorizedException('Invalid token type');
    const session = await this.prisma.refreshSession.findUnique({ where: { id: payload.sid }, include: { user: true } });
    if (!session || session.tokenHash !== this.hash(rawToken) || session.expiresAt <= new Date() || session.revokedAt) {
      if (session?.revokedAt) {
        await this.prisma.refreshSession.updateMany({ where: { userId: payload.sub, revokedAt: null }, data: { revokedAt: new Date() } });
      }
      throw new UnauthorizedException('Refresh session is unavailable');
    }
    if (session.user.status !== UserStatus.ACTIVE) throw new UnauthorizedException('Account is unavailable');
    await this.prisma.refreshSession.update({ where: { id: session.id }, data: { revokedAt: new Date(), lastUsedAt: new Date() } });
    return this.issueTokens(session.user, context);
  }

  async forgotPassword(dto: ForgotPasswordDto): Promise<void> {
    const identifier = dto.identifier.trim().toLowerCase();
    const user = await this.prisma.user.findFirst({
      where: { OR: [{ username: identifier }, { email: identifier }] },
      select: { id: true, email: true },
    });
    if (!user?.email) return;
    const code = randomInt(100000, 1000000).toString();
    await this.prisma.$transaction([
      this.prisma.passwordResetToken.deleteMany({ where: { userId: user.id } }),
      this.prisma.passwordResetToken.create({
        data: {
          userId: user.id,
          codeHash: this.resetCodeHash(user.id, code),
          expiresAt: new Date(Date.now() + 15 * 60_000),
        },
      }),
    ]);
    await this.mail.sendPasswordReset(user.email, code);
  }

  async resetPassword(dto: ResetPasswordDto): Promise<void> {
    const identifier = dto.identifier.trim().toLowerCase();
    const user = await this.prisma.user.findFirst({
      where: { OR: [{ username: identifier }, { email: identifier }] },
      select: { id: true },
    });
    if (!user) throw new BadRequestException('Reset code is invalid or expired');
    const token = await this.prisma.passwordResetToken.findFirst({
      where: { userId: user.id, consumedAt: null, expiresAt: { gt: new Date() }, attempts: { lt: 5 } },
      orderBy: { createdAt: 'desc' },
    });
    if (!token || token.codeHash !== this.resetCodeHash(user.id, dto.code)) {
      if (token) await this.prisma.passwordResetToken.update({ where: { id: token.id }, data: { attempts: { increment: 1 } } });
      throw new BadRequestException('Reset code is invalid or expired');
    }
    await this.prisma.$transaction([
      this.prisma.user.update({ where: { id: user.id }, data: { passwordHash: await hash(dto.newPassword, 12) } }),
      this.prisma.passwordResetToken.update({ where: { id: token.id }, data: { consumedAt: new Date() } }),
      this.prisma.refreshSession.updateMany({ where: { userId: user.id, revokedAt: null }, data: { revokedAt: new Date() } }),
    ]);
  }

  sessions(userId: string) {
    return this.prisma.refreshSession.findMany({
      where: { userId, revokedAt: null, expiresAt: { gt: new Date() } },
      orderBy: { lastUsedAt: 'desc' },
      select: { id: true, userAgent: true, ipAddress: true, createdAt: true, lastUsedAt: true, expiresAt: true },
    });
  }

  async heartbeat(userId: string, sessionId: string): Promise<void> {
    await this.prisma.$transaction([
      this.prisma.refreshSession.updateMany({ where: { id: sessionId, userId, revokedAt: null }, data: { lastUsedAt: new Date() } }),
      this.prisma.user.update({ where: { id: userId }, data: { lastSeenAt: new Date() } }),
    ]);
  }

  async revokeSession(userId: string, sessionId: string): Promise<void> {
    await this.prisma.refreshSession.updateMany({ where: { id: sessionId, userId, revokedAt: null }, data: { revokedAt: new Date() } });
  }

  async logout(userId: string, sessionId?: string): Promise<void> {
    await this.prisma.refreshSession.updateMany({
      where: { userId, ...(sessionId ? { id: sessionId } : {}), revokedAt: null },
      data: { revokedAt: new Date() },
    });
  }

  private async issueTokens(user: User, context: SessionContext): Promise<AuthResponse> {
    const activeSessions = await this.prisma.refreshSession.findMany({
      where: { userId: user.id, revokedAt: null, expiresAt: { gt: new Date() } },
      orderBy: { lastUsedAt: 'asc' },
      select: { id: true },
    });
    if (activeSessions.length >= 10) {
      await this.prisma.refreshSession.updateMany({
        where: { id: { in: activeSessions.slice(0, activeSessions.length - 9).map((session) => session.id) } },
        data: { revokedAt: new Date() },
      });
    }
    const sessionId = randomUUID();
    const accessPayload: JwtPayload = { sub: user.id, role: user.role, type: 'access', sid: sessionId };
    const refreshPayload: JwtPayload = { sub: user.id, role: user.role, type: 'refresh', sid: sessionId };
    const accessToken = await this.jwt.signAsync(accessPayload, { expiresIn: this.accessTtlSeconds });
    const refreshToken = await this.jwt.signAsync(refreshPayload, { secret: this.refreshSecret, expiresIn: this.refreshDays * 86_400 });
    await this.prisma.refreshSession.create({
      data: {
        id: sessionId,
        userId: user.id,
        tokenHash: this.hash(refreshToken),
        expiresAt: new Date(Date.now() + this.refreshDays * 86_400_000),
        ipAddress: context.ipAddress,
        userAgent: context.userAgent?.slice(0, 256),
      },
    });
    return { accessToken, refreshToken, user: this.publicUser(user) };
  }

  private publicUser(user: User): PublicUser {
    return {
      id: user.id, username: user.username, email: user.email, avatarUrl: user.avatarUrl,
      coinBalance: user.coinBalance, fattahBalance: user.fattahBalance,
      vipExpiresAt: user.vipExpiresAt, role: user.role,
    };
  }

  private normalizeUsername(username: string): string {
    return username.trim().replace(/\s+/g, '_').toLowerCase();
  }

  private async uniqueUsername(requested?: string): Promise<string> {
    const base = requested ? this.normalizeUsername(requested).slice(0, 24) : this.guestCode();
    if (!(await this.prisma.user.findUnique({ where: { username: base }, select: { id: true } }))) return base;
    for (let attempt = 0; attempt < 10; attempt += 1) {
      const candidate = `${base.slice(0, 26)}_${randomBytes(2).toString('hex')}`;
      if (!(await this.prisma.user.findUnique({ where: { username: candidate }, select: { id: true } }))) return candidate;
    }
    return this.guestCode();
  }

  private guestCode(): string {
    return [...randomBytes(4)].map((value) => String.fromCharCode(65 + (value % 26))).join('.');
  }

  private hash(value: string): string { return createHash('sha256').update(value).digest('hex'); }
  private resetCodeHash(userId: string, code: string): string {
    const secret = this.config.get<string>('PASSWORD_RESET_SECRET') ?? this.refreshSecret;
    return this.hash(`${secret}:${userId}:${code}`);
  }
  private get refreshSecret(): string { return this.config.get<string>('JWT_REFRESH_SECRET') ?? 'development-refresh-secret-change-me'; }
  private get refreshDays(): number { return Number(this.config.get<string>('REFRESH_TOKEN_DAYS') ?? 30); }
  private get accessTtlSeconds(): number {
    const raw = this.config.get<string>('ACCESS_TOKEN_TTL') ?? '15m';
    const match = /^(\d+)([smhd])?$/.exec(raw);
    if (!match) return 900;
    const units: Record<string, number> = { s: 1, m: 60, h: 3600, d: 86400 };
    return Number(match[1]) * units[match[2] ?? 's'];
  }
}
