import { ItemType, UserStatus } from '@prisma/client';
import { IsBoolean, IsEnum, IsInt, IsOptional, IsString, IsUUID, Max, MaxLength, Min } from 'class-validator';

export class ChangeUserStatusDto {
  @IsEnum(UserStatus)
  status!: UserStatus;
  @IsString() @MaxLength(200)
  reason!: string;
}

export class CreateItemDto {
  @IsString() @MaxLength(64) sku!: string;
  @IsString() @MaxLength(100) nameFa!: string;
  @IsOptional() @IsString() @MaxLength(500) descriptionFa?: string;
  @IsEnum(ItemType) type!: ItemType;
  @IsOptional() @IsInt() @Min(0) @Max(100_000_000) coinPrice?: number;
  @IsOptional() @IsInt() @Min(0) @Max(10_000_000_000) realPriceIrr?: number;
  @IsOptional() @IsBoolean() active?: boolean;
}

export class UpdateItemDto {
  @IsOptional() @IsString() @MaxLength(100) nameFa?: string;
  @IsOptional() @IsString() @MaxLength(500) descriptionFa?: string;
  @IsOptional() @IsInt() @Min(0) coinPrice?: number;
  @IsOptional() @IsInt() @Min(0) realPriceIrr?: number;
  @IsOptional() @IsBoolean() active?: boolean;
  @IsOptional() @IsInt() sortOrder?: number;
}

export class CreateChatDto {
  @IsString() @MaxLength(80) textFa!: string;
  @IsOptional() @IsString() @MaxLength(16) emoji?: string;
  @IsOptional() @IsInt() sortOrder?: number;
}

export class UpdateChatDto {
  @IsOptional() @IsString() @MaxLength(80) textFa?: string;
  @IsOptional() @IsString() @MaxLength(16) emoji?: string;
  @IsOptional() @IsBoolean() active?: boolean;
  @IsOptional() @IsInt() sortOrder?: number;
}

export class VipSettingDto {
  @IsString() @MaxLength(100) sku!: string;
  @IsString() @MaxLength(100) titleFa!: string;
  @IsInt() @Min(1) @Max(3650) durationDays!: number;
  @IsInt() @Min(1) @Max(10_000_000_000) priceIrr!: number;
}

export class ResourceIdDto { @IsUUID() id!: string; }
