import { Body, Controller, Get, Post, UseGuards } from '@nestjs/common';
import { ApiBearerAuth, ApiTags } from '@nestjs/swagger';
import { CurrentUser } from '../../common/auth/current-user.decorator';
import { JwtPayload } from '../../common/auth/jwt-payload';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { PurchaseItemDto } from './dto/purchase-item.dto';
import { ShopService } from './shop.service';

@ApiTags('shop')
@Controller({ path: 'shop', version: '1' })
export class ShopController {
  constructor(private readonly shop: ShopService) {}
  @Get('items') list() { return this.shop.list(); }
  @Get('inventory') @ApiBearerAuth() @UseGuards(JwtAuthGuard)
  inventory(@CurrentUser() user: JwtPayload) { return this.shop.inventory(user.sub); }
  @Post('purchase') @ApiBearerAuth() @UseGuards(JwtAuthGuard)
  purchase(@CurrentUser() user: JwtPayload, @Body() dto: PurchaseItemDto) { return this.shop.purchase(user.sub, dto.itemId, dto.idempotencyKey); }
}
