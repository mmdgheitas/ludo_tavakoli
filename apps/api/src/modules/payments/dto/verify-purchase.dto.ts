import { ApiProperty } from '@nestjs/swagger';
import { PaymentProvider } from '@prisma/client';
import { IsEnum, IsString, Length, MaxLength } from 'class-validator';

export class VerifyPurchaseDto {
  @ApiProperty({ enum: PaymentProvider })
  @IsEnum(PaymentProvider)
  provider!: PaymentProvider;

  @IsString()
  @Length(3, 100)
  productSku!: string;

  @IsString()
  @Length(16, 4096)
  purchaseToken!: string;

  @IsString()
  @MaxLength(128)
  providerTransactionId!: string;
}
