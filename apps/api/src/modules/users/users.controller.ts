import { Body, Controller, Get, Patch, UseGuards } from '@nestjs/common';
import { ApiBearerAuth, ApiTags } from '@nestjs/swagger';
import { CurrentUser } from '../../common/auth/current-user.decorator';
import { JwtPayload } from '../../common/auth/jwt-payload';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { UpdateProfileDto } from './dto/update-profile.dto';
import { UsersService } from './users.service';

@ApiTags('users')
@ApiBearerAuth()
@UseGuards(JwtAuthGuard)
@Controller({ path: 'users', version: '1' })
export class UsersController {
  constructor(private readonly users: UsersService) {}
  @Get('me')
  me(@CurrentUser() user: JwtPayload) { return this.users.findProfile(user.sub); }
  @Patch('me')
  update(@CurrentUser() user: JwtPayload, @Body() dto: UpdateProfileDto) { return this.users.updateProfile(user.sub, dto); }
}
