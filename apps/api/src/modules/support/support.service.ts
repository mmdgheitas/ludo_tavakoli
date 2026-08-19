import { Injectable } from '@nestjs/common';
import { PrismaService } from '../../prisma/prisma.service';
import { CreateSupportTicketDto } from './dto/support.dto';

@Injectable()
export class SupportService {
  constructor(private readonly prisma: PrismaService) {}

  create(userId: string, dto: CreateSupportTicketDto) {
    return this.prisma.supportTicket.create({
      data: { userId, subject: dto.subject.trim(), message: dto.message.trim() },
      select: { id: true, subject: true, message: true, status: true, response: true, createdAt: true, updatedAt: true },
    });
  }

  list(userId: string) {
    return this.prisma.supportTicket.findMany({
      where: { userId },
      orderBy: { createdAt: 'desc' },
      select: { id: true, subject: true, message: true, status: true, response: true, createdAt: true, updatedAt: true },
    });
  }
}
