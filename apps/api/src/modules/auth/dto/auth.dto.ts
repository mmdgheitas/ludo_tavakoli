import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { IsEmail, IsNotEmpty, IsOptional, IsString, Length, Matches, MaxLength, MinLength } from 'class-validator';

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

export class RegisterDto {
  @IsString()
  @Length(3, 24)
  @Matches(/^[\p{L}\p{N}_.\-‌]+$/u)
  username!: string;

  @IsEmail()
  @MaxLength(254)
  email!: string;

  @IsString()
  @MinLength(10)
  @MaxLength(128)
  @Matches(/^(?=.*[a-z])(?=.*[A-Z])(?=.*\d).+$/, {
    message: 'Password must contain uppercase, lowercase and number',
  })
  password!: string;
}

export class LoginDto {
  @IsString()
  @Length(3, 254)
  identifier!: string;

  @IsString()
  @MinLength(10)
  @MaxLength(128)
  password!: string;
}

export class ForgotPasswordDto {
  @IsString()
  @Length(3, 254)
  identifier!: string;
}

export class ResetPasswordDto {
  @IsString()
  @Length(3, 254)
  identifier!: string;

  @IsString()
  @Length(6, 6)
  @Matches(/^\d{6}$/)
  code!: string;

  @IsString()
  @MinLength(10)
  @MaxLength(128)
  @Matches(/^(?=.*[a-z])(?=.*[A-Z])(?=.*\d).+$/)
  newPassword!: string;
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
