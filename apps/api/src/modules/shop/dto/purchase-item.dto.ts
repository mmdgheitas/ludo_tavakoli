import { IsString, IsUUID, Length } from 'class-validator';

export class EquipItemDto {
  @IsUUID()
  itemId!: string;
}

export class PurchaseItemDto {
  @IsUUID()
  itemId!: string;

  @IsString()
  @Length(16, 128)
  idempotencyKey!: string;
}
