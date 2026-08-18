import { BadRequestException, Injectable } from '@nestjs/common';
import { PrismaService } from '../../prisma/prisma.service';
import { GamesService } from '../games/games.service';

@Injectable()
export class ChatService {
  constructor(private readonly prisma: PrismaService, private readonly games: GamesService) {}

  messages() {
    return this.prisma.quickChat.findMany({ where: { active: true }, orderBy: { sortOrder: 'asc' }, select: { id: true, textFa: true, emoji: true } });
  }

  async validate(userId: string, gameId: string, messageId: string) {
    await this.games.getForUser(gameId, userId);
    const message = await this.prisma.quickChat.findFirst({ where: { id: messageId, active: true }, select: { id: true, textFa: true, emoji: true } });
    if (!message) throw new BadRequestException('Quick-chat message is unavailable');
    return { ...message, userId, gameId, sentAt: new Date().toISOString() };
  }
}
