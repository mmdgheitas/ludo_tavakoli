import { Body, Controller, Get, Post, UseGuards } from '@nestjs/common';
import { ApiBearerAuth, ApiTags } from '@nestjs/swagger';
import { CurrentUser } from '../../common/auth/current-user.decorator';
import { JwtPayload } from '../../common/auth/jwt-payload';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { CreateSupportTicketDto } from './dto/support.dto';
import { SupportService } from './support.service';

@ApiTags('support')
@ApiBearerAuth()
@UseGuards(JwtAuthGuard)
@Controller({ path: 'support', version: '1' })
export class SupportController {
  constructor(private readonly support: SupportService) {}

  @Get('tickets')
  list(@CurrentUser() user: JwtPayload) { return this.support.list(user.sub); }

  @Post('tickets')
  create(@CurrentUser() user: JwtPayload, @Body() dto: CreateSupportTicketDto) {
    return this.support.create(user.sub, dto);
  }
}
