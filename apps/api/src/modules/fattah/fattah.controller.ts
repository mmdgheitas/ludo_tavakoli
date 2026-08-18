import { Controller, Get, UseGuards } from '@nestjs/common';
import { ApiBearerAuth, ApiTags } from '@nestjs/swagger';
import { CurrentUser } from '../../common/auth/current-user.decorator';
import { JwtPayload } from '../../common/auth/jwt-payload';
import { PrismaService } from '../../prisma/prisma.service';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';

@ApiTags('fattah')
@ApiBearerAuth()
@UseGuards(JwtAuthGuard)
@Controller({ path: 'fattah', version: '1' })
export class FattahController {
  constructor(private readonly prisma: PrismaService) {}
  @Get('balance')
  async balance(@CurrentUser() user: JwtPayload) {
    const result = await this.prisma.user.findUniqueOrThrow({ where: { id: user.sub }, select: { fattahBalance: true } });
    return { balance: result.fattahBalance, maxUsagePerGame: 1 };
  }
}
