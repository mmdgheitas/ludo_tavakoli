import { Controller, Get, UseGuards } from '@nestjs/common';
import { ApiBearerAuth, ApiTags } from '@nestjs/swagger';
import { CurrentUser } from '../../common/auth/current-user.decorator';
import { JwtPayload } from '../../common/auth/jwt-payload';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { VipService } from './vip.service';

@ApiTags('vip')
@Controller({ path: 'vip', version: '1' })
export class VipController {
  constructor(private readonly vip: VipService) {}
  @Get('offer') offer() { return this.vip.offer(); }
  @Get('status') @ApiBearerAuth() @UseGuards(JwtAuthGuard)
  status(@CurrentUser() user: JwtPayload) { return this.vip.status(user.sub); }
}
