'use client';

import { Bell, LogOut, Search } from 'lucide-react';
import { useRouter } from 'next/navigation';

export function Header() {
  const router = useRouter();
  async function logout() { await fetch('/api/auth/logout', { method: 'POST' }); router.replace('/login'); router.refresh(); }
  return <header className="mb-7 flex items-center justify-between gap-4">
    <div><p className="eyebrow">مرکز عملیات زنده</p><h1 className="mt-1 text-2xl font-black sm:text-3xl">داشبورد مدیریت</h1></div>
    <div className="flex items-center gap-2">
      <label className="hidden h-11 items-center gap-2 rounded-2xl border border-line bg-panel px-4 md:flex"><Search size={17} className="text-muted" /><input aria-label="جست‌وجو" className="w-36 bg-transparent text-xs outline-none" placeholder="جست‌وجوی سریع…" /></label>
      <button className="relative grid h-11 w-11 place-items-center rounded-2xl border border-line bg-panel text-muted hover:text-white"><Bell size={18} /><span className="absolute left-2 top-2 h-2 w-2 rounded-full border-2 border-panel bg-coral" /></button>
      <button onClick={logout} title="خروج" className="grid h-11 w-11 place-items-center rounded-2xl border border-line bg-panel text-muted hover:text-coral"><LogOut size={18} /></button>
    </div>
  </header>;
}
