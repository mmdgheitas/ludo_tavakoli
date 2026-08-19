import { NextRequest, NextResponse } from 'next/server';
import { cookies } from 'next/headers';

const apiBase = process.env.API_BASE_URL ?? 'http://localhost:3001/api/v1';

async function proxy(request: NextRequest, context: { params: Promise<{ path: string[] }> }) {
  const { path } = await context.params;
  if (!path.length || path.some((segment) => !/^[a-zA-Z0-9_-]+$/.test(segment))) {
    return NextResponse.json({ message: 'Invalid admin path' }, { status: 400 });
  }
  const token = (await cookies()).get('admin_access')?.value;
  if (!token) return NextResponse.json({ message: 'Unauthorized' }, { status: 401 });
  const body = ['GET', 'HEAD'].includes(request.method) ? undefined : await request.text();
  const response = await fetch(`${apiBase}/admin/${path.join('/')}${request.nextUrl.search}`, {
    method: request.method,
    body,
    cache: 'no-store',
    headers: { authorization: `Bearer ${token}`, ...(body ? { 'content-type': 'application/json' } : {}) },
  });
  const text = await response.text();
  return new NextResponse(text || null, { status: response.status, headers: { 'content-type': response.headers.get('content-type') ?? 'application/json' } });
}

export const GET = proxy;
export const POST = proxy;
export const PATCH = proxy;
