import { ConflictException, Injectable, NotFoundException } from '@nestjs/common';
import { Prisma } from '@prisma/client';
import { PrismaService } from '../../prisma/prisma.service';
import { UpdateProfileDto } from './dto/update-profile.dto';

@Injectable()
export class UsersService {
  constructor(private readonly prisma: PrismaService) {}

  async findProfile(id: string) {
    const user = await this.prisma.user.findUnique({
      where: { id },
      select: {
        id: true, username: true, avatarUrl: true, coinBalance: true,
        fattahBalance: true, vipExpiresAt: true, role: true, status: true, createdAt: true,
      },
    });
    if (!user) throw new NotFoundException('User not found');
    await this.prisma.user.update({ where: { id }, data: { lastSeenAt: new Date() } });
    return user;
  }

  async updateProfile(id: string, dto: UpdateProfileDto) {
    try {
      return await this.prisma.user.update({
        where: { id },
        data: { username: dto.username?.trim(), avatarUrl: dto.avatarUrl },
        select: { id: true, username: true, avatarUrl: true, coinBalance: true, fattahBalance: true, vipExpiresAt: true },
      });
    } catch (error) {
      if (error instanceof Prisma.PrismaClientKnownRequestError && error.code === 'P2002') {
        throw new ConflictException('Username is already in use');
      }
      throw error;
    }
  }
}
