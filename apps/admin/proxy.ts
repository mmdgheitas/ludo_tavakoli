import { NextRequest, NextResponse } from 'next/server';

export function proxy(request: NextRequest) {
  const authenticated = request.cookies.has('admin_access');
  const login = request.nextUrl.pathname === '/login';
  if (!authenticated && !login) return NextResponse.redirect(new URL('/login', request.url));
  if (authenticated && login) return NextResponse.redirect(new URL('/', request.url));
  return NextResponse.next();
}

export const config = { matcher: ['/((?!api|_next/static|_next/image|favicon.ico).*)'] };
