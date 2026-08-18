import { IsInt, IsString, Max, MaxLength, Min } from 'class-validator';

export class AdminRewardDto {
  @IsInt()
  @Min(1)
  @Max(1_000_000)
  amount!: number;

  @IsString()
  @MaxLength(200)
  reason!: string;
}
