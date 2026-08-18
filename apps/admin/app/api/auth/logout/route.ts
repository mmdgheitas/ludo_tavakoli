import { NextResponse } from 'next/server';

export async function POST() {
  const response = NextResponse.json({ success: true });
  response.cookies.delete('admin_access');
  response.cookies.delete('admin_refresh');
  return response;
}
