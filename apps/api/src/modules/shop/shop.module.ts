import { Module } from '@nestjs/common';
import { AuthModule } from '../auth/auth.module';
import { ShopController } from './shop.controller';
import { ShopService } from './shop.service';

@Module({ imports: [AuthModule], controllers: [ShopController], providers: [ShopService], exports: [ShopService] })
export class ShopModule {}
