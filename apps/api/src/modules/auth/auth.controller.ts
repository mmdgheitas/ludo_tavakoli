import { Body, Controller, Headers, Ip, Post, UseGuards } from '@nestjs/common';
import { ApiBearerAuth, ApiTags } from '@nestjs/swagger';
import { Throttle } from '@nestjs/throttler';
import { JwtPayload } from '../../common/auth/jwt-payload';
import { CurrentUser } from '../../common/auth/current-user.decorator';
import { AuthService } from './auth.service';
import { AdminLoginDto, GuestAuthDto, RefreshDto } from './dto/auth.dto';
import { JwtAuthGuard } from './jwt-auth.guard';

@ApiTags('auth')
@Controller({ path: 'auth', version: '1' })
export class AuthController {
  constructor(private readonly auth: AuthService) {}

  @Post('guest')
  @Throttle({ default: { limit: 10, ttl: 60_000 } })
  guest(@Body() dto: GuestAuthDto, @Ip() ipAddress: string, @Headers('user-agent') userAgent?: string) {
    return this.auth.guest(dto, { ipAddress, userAgent });
  }

  @Post('refresh')
  @Throttle({ default: { limit: 20, ttl: 60_000 } })
  refresh(@Body() dto: RefreshDto, @Ip() ipAddress: string, @Headers('user-agent') userAgent?: string) {
    return this.auth.refresh(dto.refreshToken, { ipAddress, userAgent });
  }

  @Post('admin/login')
  @Throttle({ default: { limit: 5, ttl: 60_000 } })
  adminLogin(@Body() dto: AdminLoginDto, @Ip() ipAddress: string, @Headers('user-agent') userAgent?: string) {
    return this.auth.adminLogin(dto, { ipAddress, userAgent });
  }

  @Post('logout')
  @ApiBearerAuth()
  @UseGuards(JwtAuthGuard)
  async logout(@CurrentUser() user: JwtPayload): Promise<{ success: true }> {
    await this.auth.logout(user.sub);
    return { success: true };
  }
}
