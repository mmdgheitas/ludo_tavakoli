import { Injectable, UnauthorizedException } from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import { UserStatus } from '@prisma/client';
import { JwtPayload } from '../../common/auth/jwt-payload';
import { PrismaService } from '../../prisma/prisma.service';

@Injectable()
export class SocketAuthService {
  constructor(private readonly jwt: JwtService, private readonly prisma: PrismaService) {}

  async validate(token: string): Promise<JwtPayload> {
    const payload = await this.jwt.verifyAsync<JwtPayload>(token);
    if (payload.type !== 'access' || !payload.sid) throw new UnauthorizedException('Invalid token type');
    const [user, session] = await Promise.all([
      this.prisma.user.findUnique({ where: { id: payload.sub }, select: { status: true, role: true } }),
      this.prisma.refreshSession.findUnique({ where: { id: payload.sid }, select: { userId: true, revokedAt: true, expiresAt: true } }),
    ]);
    if (!user || user.status !== UserStatus.ACTIVE) throw new UnauthorizedException('Account is unavailable');
    if (!session || session.userId !== payload.sub || session.revokedAt || session.expiresAt <= new Date()) {
      throw new UnauthorizedException('Session is no longer active');
    }
    return { ...payload, role: user.role };
  }
}
