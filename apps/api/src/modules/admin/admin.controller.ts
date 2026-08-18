import { Body, Controller, DefaultValuePipe, Get, Param, ParseIntPipe, ParseUUIDPipe, Patch, Post, Query, UseGuards } from '@nestjs/common';
import { ApiBearerAuth, ApiTags } from '@nestjs/swagger';
import { UserRole } from '@prisma/client';
import { CurrentUser } from '../../common/auth/current-user.decorator';
import { JwtPayload } from '../../common/auth/jwt-payload';
import { Roles } from '../../common/auth/roles.decorator';
import { RolesGuard } from '../../common/auth/roles.guard';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { AdminRewardDto } from '../wallet/dto/wallet.dto';
import { AdminService } from './admin.service';
import { ChangeUserStatusDto, CreateChatDto, CreateItemDto, UpdateChatDto, UpdateItemDto, VipSettingDto } from './dto/admin.dto';

@ApiTags('admin')
@ApiBearerAuth()
@UseGuards(JwtAuthGuard, RolesGuard)
@Roles(UserRole.ADMIN, UserRole.SUPER_ADMIN)
@Controller({ path: 'admin', version: '1' })
export class AdminController {
  constructor(private readonly admin: AdminService) {}

  @Get('users') users(@Query('page', new DefaultValuePipe(1), ParseIntPipe) page: number, @Query('search') search?: string) { return this.admin.users(Math.max(page, 1), search); }
  @Patch('users/:id/status') status(@CurrentUser() actor: JwtPayload, @Param('id', ParseUUIDPipe) id: string, @Body() dto: ChangeUserStatusDto) { return this.admin.changeStatus(actor.sub, id, dto.status, dto.reason); }
  @Post('users/:id/reward') reward(@CurrentUser() actor: JwtPayload, @Param('id', ParseUUIDPipe) id: string, @Body() dto: AdminRewardDto) { return this.admin.reward(actor.sub, id, dto.amount, dto.reason); }

  @Get('games') games(@Query('page', new DefaultValuePipe(1), ParseIntPipe) page: number) { return this.admin.games(Math.max(page, 1)); }
  @Get('transactions') transactions(@Query('page', new DefaultValuePipe(1), ParseIntPipe) page: number) { return this.admin.transactions(Math.max(page, 1)); }
  @Get('vip-purchases') vip(@Query('page', new DefaultValuePipe(1), ParseIntPipe) page: number) { return this.admin.vipPurchases(Math.max(page, 1)); }
  @Patch('settings/vip') updateVip(@CurrentUser() actor: JwtPayload, @Body() dto: VipSettingDto) { return this.admin.updateVipSetting(actor.sub, dto); }
  @Get('payments') payments(@Query('page', new DefaultValuePipe(1), ParseIntPipe) page: number) { return this.admin.payments(Math.max(page, 1)); }
  @Get('operations') operations() { return this.admin.operationalSummary(); }

  @Get('items') items() { return this.admin.items(); }
  @Post('items') createItem(@Body() dto: CreateItemDto) { return this.admin.createItem(dto); }
  @Patch('items/:id') updateItem(@Param('id', ParseUUIDPipe) id: string, @Body() dto: UpdateItemDto) { return this.admin.updateItem(id, dto); }

  @Get('quick-chat') chats() { return this.admin.chats(); }
  @Post('quick-chat') createChat(@Body() dto: CreateChatDto) { return this.admin.createChat(dto); }
  @Patch('quick-chat/:id') updateChat(@Param('id', ParseUUIDPipe) id: string, @Body() dto: UpdateChatDto) { return this.admin.updateChat(id, dto); }
}
