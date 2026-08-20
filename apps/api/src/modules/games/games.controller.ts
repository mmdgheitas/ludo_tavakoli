import { Body, Controller, Get, Param, ParseUUIDPipe, Post, UseGuards } from '@nestjs/common';
import { ApiBearerAuth, ApiTags } from '@nestjs/swagger';
import { CurrentUser } from '../../common/auth/current-user.decorator';
import { JwtPayload } from '../../common/auth/jwt-payload';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { CreateRoomDto, FattahDto, JoinRoomCodeDto, MoveTokenDto } from './dto/game.dto';
import { GamesService } from './games.service';

@ApiTags('games')
@ApiBearerAuth()
@UseGuards(JwtAuthGuard)
@Controller({ path: 'games', version: '1' })
export class GamesController {
  constructor(private readonly games: GamesService) {}

  @Post('rooms')
  create(@CurrentUser() user: JwtPayload, @Body() dto: CreateRoomDto) { return this.games.createRoom(user.sub, dto.mode); }

  @Post('rooms/join')
  joinCode(@CurrentUser() user: JwtPayload, @Body() dto: JoinRoomCodeDto) { return this.games.joinRoomByCode(dto.roomCode, user.sub); }

  @Post(':id/join')
  join(@CurrentUser() user: JwtPayload, @Param('id', ParseUUIDPipe) id: string) { return this.games.joinRoom(id, user.sub); }

  @Get('active/me')
  active(@CurrentUser() user: JwtPayload) { return this.games.activeForUser(user.sub); }

  @Get(':id/state')
  state(@CurrentUser() user: JwtPayload, @Param('id', ParseUUIDPipe) id: string) { return this.games.getForUser(id, user.sub); }

  @Post(':id/roll')
  roll(@CurrentUser() user: JwtPayload, @Param('id', ParseUUIDPipe) id: string) { return this.games.roll(id, user.sub); }

  @Post(':id/move')
  move(@CurrentUser() user: JwtPayload, @Param('id', ParseUUIDPipe) id: string, @Body() dto: MoveTokenDto) { return this.games.move(id, user.sub, dto.tokenIndex); }

  @Post(':id/forfeit')
  forfeit(@CurrentUser() user: JwtPayload, @Param('id', ParseUUIDPipe) id: string) { return this.games.forfeit(id, user.sub); }

  @Post(':id/fattah')
  fattah(@CurrentUser() user: JwtPayload, @Param('id', ParseUUIDPipe) id: string, @Body() dto: FattahDto) {
    return this.games.useFattah(id, user.sub, dto.targetUserId, dto.targetTokenIndex);
  }
}
