import { UserRole } from '@prisma/client';

export interface JwtPayload {
  sub: string;
  role: UserRole;
  type: 'access' | 'refresh';
  sid: string;
  iat?: number;
  exp?: number;
}
