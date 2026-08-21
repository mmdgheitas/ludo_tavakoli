import { Injectable, UnauthorizedException } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { PassportStrategy } from '@nestjs/passport';
import { UserStatus } from '@prisma/client';
import { ExtractJwt, Strategy } from 'passport-jwt';
import { JwtPayload } from '../../common/auth/jwt-payload';
import { PrismaService } from '../../prisma/prisma.service';

@Injectable()
export class JwtStrategy extends PassportStrategy(Strategy) {
  constructor(config: ConfigService, private readonly prisma: PrismaService) {
    super({
      jwtFromRequest: ExtractJwt.fromAuthHeaderAsBearerToken(),
      ignoreExpiration: false,
      secretOrKey: config.get<string>('JWT_ACCESS_SECRET') ?? 'development-access-secret-change-me-now',
    });
  }

  async validate(payload: JwtPayload): Promise<JwtPayload> {
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
