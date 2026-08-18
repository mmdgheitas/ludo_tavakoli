import { Module } from '@nestjs/common';
import { AuthModule } from '../auth/auth.module';
import { FattahController } from './fattah.controller';

@Module({ imports: [AuthModule], controllers: [FattahController] })
export class FattahModule {}
