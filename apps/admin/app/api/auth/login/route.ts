import { NextRequest, NextResponse } from 'next/server';

export async function POST(request: NextRequest) {
  const body: unknown = await request.json();
  const response = await fetch(`${process.env.API_BASE_URL ?? 'http://localhost:3001/api/v1'}/auth/admin/login`, {
    method: 'POST', headers: { 'content-type': 'application/json' }, body: JSON.stringify(body), cache: 'no-store',
  });
  if (!response.ok) return NextResponse.json({ message: 'نام کاربری یا رمز عبور درست نیست.' }, { status: 401 });
  const data = await response.json() as { accessToken: string; refreshToken: string };
  const result = NextResponse.json({ success: true });
  result.cookies.set('admin_access', data.accessToken, { httpOnly: true, secure: process.env.NODE_ENV === 'production', sameSite: 'strict', path: '/', maxAge: 15 * 60 });
  result.cookies.set('admin_refresh', data.refreshToken, { httpOnly: true, secure: process.env.NODE_ENV === 'production', sameSite: 'strict', path: '/api/auth', maxAge: 30 * 86400 });
  return result;
}
