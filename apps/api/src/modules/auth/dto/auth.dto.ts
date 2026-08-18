import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { IsNotEmpty, IsOptional, IsString, Length, Matches, MaxLength, MinLength } from 'class-validator';

export class GuestAuthDto {
  @ApiPropertyOptional({ example: 'آرش' })
  @IsOptional()
  @IsString()
  @Length(2, 24)
  @Matches(/^[\p{L}\p{N}_.\-‌ ]+$/u)
  displayName?: string;

  @ApiProperty({ description: 'Random installation identifier, not hardware fingerprint' })
  @IsString()
  @Length(16, 128)
  deviceId!: string;
}

export class RefreshDto {
  @ApiProperty()
  @IsString()
  @IsNotEmpty()
  refreshToken!: string;
}

export class AdminLoginDto {
  @ApiProperty()
  @IsString()
  @MaxLength(32)
  username!: string;

  @ApiProperty()
  @IsString()
  @MinLength(10)
  @MaxLength(128)
  password!: string;
}
