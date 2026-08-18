import { Controller, DefaultValuePipe, Get, ParseIntPipe, Post, Query, UseGuards } from '@nestjs/common';
import { ApiBearerAuth, ApiTags } from '@nestjs/swagger';
import { CurrentUser } from '../../common/auth/current-user.decorator';
import { JwtPayload } from '../../common/auth/jwt-payload';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { WalletService } from './wallet.service';

@ApiTags('wallet')
@ApiBearerAuth()
@UseGuards(JwtAuthGuard)
@Controller({ path: 'wallet', version: '1' })
export class WalletController {
  constructor(private readonly wallet: WalletService) {}
  @Get('transactions')
  history(@CurrentUser() user: JwtPayload, @Query('page', new DefaultValuePipe(1), ParseIntPipe) page: number) { return this.wallet.history(user.sub, page); }
  @Post('daily-reward')
  daily(@CurrentUser() user: JwtPayload) { return this.wallet.claimDaily(user.sub); }
}
