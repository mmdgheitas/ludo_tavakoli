import { Body, Controller, Get, Post, UseGuards } from '@nestjs/common';
import { ApiBearerAuth, ApiTags } from '@nestjs/swagger';
import { Throttle } from '@nestjs/throttler';
import { CurrentUser } from '../../common/auth/current-user.decorator';
import { JwtPayload } from '../../common/auth/jwt-payload';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { VerifyPurchaseDto } from './dto/verify-purchase.dto';
import { PaymentsService } from './payments.service';

@ApiTags('payments')
@ApiBearerAuth()
@UseGuards(JwtAuthGuard)
@Controller({ path: 'payments', version: '1' })
export class PaymentsController {
  constructor(private readonly payments: PaymentsService) {}
  @Post('verify')
  @Throttle({ default: { limit: 10, ttl: 60_000 } })
  verify(@CurrentUser() user: JwtPayload, @Body() dto: VerifyPurchaseDto) { return this.payments.verify(user.sub, dto); }
  @Get() history(@CurrentUser() user: JwtPayload) { return this.payments.history(user.sub); }
}
