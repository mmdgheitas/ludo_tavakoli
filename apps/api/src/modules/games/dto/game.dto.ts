import { ApiProperty } from '@nestjs/swagger';
import { GameMode } from '@prisma/client';
import { IsEnum, IsInt, IsString, IsUUID, Length, Matches, Max, Min } from 'class-validator';

export class CreateRoomDto {
  @ApiProperty({ enum: [GameMode.ONLINE_2P, GameMode.ONLINE_4P] })
  @IsEnum(GameMode)
  mode!: GameMode;
}

export class JoinRoomCodeDto {
  @IsString()
  @Length(6, 8)
  @Matches(/^[A-Za-z0-9]+$/)
  roomCode!: string;
}

export class MoveTokenDto {
  @IsInt()
  @Min(0)
  @Max(3)
  tokenIndex!: number;
}

export class FattahDto {
  @IsUUID()
  targetUserId!: string;
  @IsInt()
  @Min(0)
  @Max(3)
  targetTokenIndex!: number;
}

/**
 * Socket payloads must be classes: a TypeScript interface erases to `Object`,
 * which the gateway `ValidationPipe` skips, so decorators on `FattahDto` would
 * never run for `game:fattah`. These wrappers make the real-time path validate
 * exactly like the REST path.
 */
export class GameCommandDto {
  @IsUUID()
  gameId!: string;
}

export class MoveSocketDto extends MoveTokenDto {
  @IsUUID()
  gameId!: string;
}

export class FattahSocketDto extends FattahDto {
  @IsUUID()
  gameId!: string;
}
