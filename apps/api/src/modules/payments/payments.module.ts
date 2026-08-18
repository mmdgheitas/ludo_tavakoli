import { Module } from '@nestjs/common';
import { AuthModule } from '../auth/auth.module';
import { PaymentsController } from './payments.controller';
import { PaymentsService } from './payments.service';
import { ProviderVerifierService } from './provider-verifier.service';

@Module({ imports: [AuthModule], controllers: [PaymentsController], providers: [PaymentsService, ProviderVerifierService], exports: [PaymentsService] })
export class PaymentsModule {}
