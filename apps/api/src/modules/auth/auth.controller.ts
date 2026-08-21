import { Body, Controller, Delete, Get, Headers, Ip, Param, ParseUUIDPipe, Post, UseGuards } from '@nestjs/common';
import { ApiBearerAuth, ApiTags } from '@nestjs/swagger';
import { Throttle } from '@nestjs/throttler';
import { JwtPayload } from '../../common/auth/jwt-payload';
import { CurrentUser } from '../../common/auth/current-user.decorator';
import { AuthService } from './auth.service';
import { AdminLoginDto, ForgotPasswordDto, GuestAuthDto, LoginDto, RefreshDto, RegisterDto, ResetPasswordDto } from './dto/auth.dto';
import { JwtAuthGuard } from './jwt-auth.guard';

@ApiTags('auth')
@Controller({ path: 'auth', version: '1' })
export class AuthController {
  constructor(private readonly auth: AuthService) {}

  @Post('register')
  @Throttle({ default: { limit: 5, ttl: 60_000 } })
  register(@Body() dto: RegisterDto, @Ip() ipAddress: string, @Headers('user-agent') userAgent?: string) {
    return this.auth.register(dto, { ipAddress, userAgent });
  }

  @Post('login')
  @Throttle({ default: { limit: 8, ttl: 60_000 } })
  login(@Body() dto: LoginDto, @Ip() ipAddress: string, @Headers('user-agent') userAgent?: string) {
    return this.auth.login(dto, { ipAddress, userAgent });
  }

  @Post('password/forgot')
  @Throttle({ default: { limit: 3, ttl: 60_000 } })
  async forgot(@Body() dto: ForgotPasswordDto): Promise<{ accepted: true }> {
    await this.auth.forgotPassword(dto);
    return { accepted: true };
  }

  @Post('password/reset')
  @Throttle({ default: { limit: 5, ttl: 60_000 } })
  async reset(@Body() dto: ResetPasswordDto): Promise<{ success: true }> {
    await this.auth.resetPassword(dto);
    return { success: true };
  }

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

  @Get('sessions')
  @ApiBearerAuth()
  @UseGuards(JwtAuthGuard)
  sessions(@CurrentUser() user: JwtPayload) { return this.auth.sessions(user.sub); }

  @Post('session/heartbeat')
  @ApiBearerAuth()
  @UseGuards(JwtAuthGuard)
  async heartbeat(@CurrentUser() user: JwtPayload): Promise<{ alive: true }> {
    await this.auth.heartbeat(user.sub, user.sid);
    return { alive: true };
  }

  @Delete('sessions/:id')
  @ApiBearerAuth()
  @UseGuards(JwtAuthGuard)
  async revoke(@CurrentUser() user: JwtPayload, @Param('id', ParseUUIDPipe) id: string): Promise<{ success: true }> {
    await this.auth.revokeSession(user.sub, id);
    return { success: true };
  }

  @Post('logout')
  @ApiBearerAuth()
  @UseGuards(JwtAuthGuard)
  async logout(@CurrentUser() user: JwtPayload): Promise<{ success: true }> {
    await this.auth.logout(user.sub, user.sid);
    return { success: true };
  }
}
