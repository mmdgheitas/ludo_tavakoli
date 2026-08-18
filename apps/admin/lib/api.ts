import { cookies } from 'next/headers';

const baseUrl = process.env.API_BASE_URL ?? 'http://localhost:3001/api/v1';

export async function api<T>(path: string, init?: RequestInit): Promise<T> {
  const token = (await cookies()).get('admin_access')?.value;
  const response = await fetch(`${baseUrl}${path}`, {
    ...init,
    cache: init?.cache ?? 'no-store',
    headers: { 'content-type': 'application/json', ...(token ? { authorization: `Bearer ${token}` } : {}), ...init?.headers },
  });
  if (!response.ok) throw new Error(`API ${response.status}: ${path}`);
  return response.json() as Promise<T>;
}

export async function safeApi<T>(path: string, fallback: T): Promise<T> {
  try { return await api<T>(path); } catch { return fallback; }
}
