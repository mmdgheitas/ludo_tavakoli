import { createHash, randomBytes } from 'node:crypto';
import { Injectable, UnauthorizedException } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { JwtService } from '@nestjs/jwt';
import { User, UserRole, UserStatus } from '@prisma/client';
import { compare } from 'bcryptjs';
import { JwtPayload } from '../../common/auth/jwt-payload';
import { PrismaService } from '../../prisma/prisma.service';
import { AdminLoginDto, GuestAuthDto } from './dto/auth.dto';

interface SessionContext { ipAddress?: string; userAgent?: string }

export type PublicUser = Pick<User, 'id' | 'username' | 'avatarUrl' | 'coinBalance' | 'fattahBalance' | 'vipExpiresAt' | 'role'>;

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
  ) {}

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
    const user = await this.prisma.user.findUnique({ where: { username: dto.username } });
    if (!user?.passwordHash || user.status !== UserStatus.ACTIVE || user.role === UserRole.PLAYER) {
      throw new UnauthorizedException('Invalid credentials');
    }
    if (!(await compare(dto.password, user.passwordHash))) throw new UnauthorizedException('Invalid credentials');
    return this.issueTokens(user, context);
  }

  async refresh(rawToken: string, context: SessionContext): Promise<AuthResponse> {
    let payload: JwtPayload;
    try {
      payload = await this.jwt.verifyAsync<JwtPayload>(rawToken, {
        secret: this.refreshSecret,
      });
    } catch {
      throw new UnauthorizedException('Refresh token is invalid or expired');
    }
    if (payload.type !== 'refresh') throw new UnauthorizedException('Invalid token type');
    const hash = this.hash(rawToken);
    const session = await this.prisma.refreshSession.findUnique({
      where: { tokenHash: hash },
      include: { user: true },
    });
    if (!session || session.expiresAt <= new Date() || session.revokedAt) {
      if (session?.revokedAt) {
        await this.prisma.refreshSession.updateMany({ where: { userId: payload.sub, revokedAt: null }, data: { revokedAt: new Date() } });
      }
      throw new UnauthorizedException('Refresh session is unavailable');
    }
    if (session.user.status !== UserStatus.ACTIVE) throw new UnauthorizedException('Account is unavailable');
    await this.prisma.refreshSession.update({ where: { id: session.id }, data: { revokedAt: new Date() } });
    return this.issueTokens(session.user, context);
  }

  async logout(userId: string): Promise<void> {
    await this.prisma.refreshSession.updateMany({ where: { userId, revokedAt: null }, data: { revokedAt: new Date() } });
  }

  private async issueTokens(user: User, context: SessionContext): Promise<AuthResponse> {
    const accessPayload: JwtPayload = { sub: user.id, role: user.role, type: 'access' };
    const refreshPayload: JwtPayload = { sub: user.id, role: user.role, type: 'refresh' };
    const accessToken = await this.jwt.signAsync(accessPayload, { expiresIn: this.accessTtlSeconds });
    const refreshToken = await this.jwt.signAsync(refreshPayload, {
      secret: this.refreshSecret,
      expiresIn: this.refreshDays * 86_400,
    });
    await this.prisma.refreshSession.create({
      data: {
        userId: user.id,
        tokenHash: this.hash(refreshToken),
        expiresAt: new Date(Date.now() + this.refreshDays * 86_400_000),
        ipAddress: context.ipAddress,
        userAgent: context.userAgent?.slice(0, 256),
      },
    });
    return {
      accessToken,
      refreshToken,
      user: {
        id: user.id,
        username: user.username,
        avatarUrl: user.avatarUrl,
        coinBalance: user.coinBalance,
        fattahBalance: user.fattahBalance,
        vipExpiresAt: user.vipExpiresAt,
        role: user.role,
      },
    };
  }

  private async uniqueUsername(requested?: string): Promise<string> {
    const base = requested?.trim().replace(/\s+/g, '_').slice(0, 24) || this.guestCode();
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

  private hash(value: string): string {
    return createHash('sha256').update(value).digest('hex');
  }

  private get refreshSecret(): string {
    return this.config.get<string>('JWT_REFRESH_SECRET') ?? 'development-refresh-secret-change-me';
  }

  private get refreshDays(): number {
    return Number(this.config.get<string>('REFRESH_TOKEN_DAYS') ?? 30);
  }

  private get accessTtlSeconds(): number {
    const raw = this.config.get<string>('ACCESS_TOKEN_TTL') ?? '15m';
    const match = /^(\d+)([smhd])?$/.exec(raw);
    if (!match) return 900;
    const units: Record<string, number> = { s: 1, m: 60, h: 3600, d: 86400 };
    return Number(match[1]) * units[match[2] ?? 's'];
  }
}
