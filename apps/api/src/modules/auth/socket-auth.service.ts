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
    if (payload.type !== 'access') throw new UnauthorizedException('Invalid token type');
    const user = await this.prisma.user.findUnique({ where: { id: payload.sub }, select: { status: true, role: true } });
    if (!user || user.status !== UserStatus.ACTIVE) throw new UnauthorizedException('Account is unavailable');
    return { ...payload, role: user.role };
  }
}
