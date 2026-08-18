'use client';

import { Dice5, Eye, EyeOff, LoaderCircle, LockKeyhole, UserRound } from 'lucide-react';
import { FormEvent, useState } from 'react';
import { useRouter } from 'next/navigation';

export default function LoginPage() {
  const router = useRouter();
  const [show, setShow] = useState(false);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState('');

  async function submit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault(); setLoading(true); setError('');
    const form = new FormData(event.currentTarget);
    const response = await fetch('/api/auth/login', { method: 'POST', headers: { 'content-type': 'application/json' }, body: JSON.stringify({ username: form.get('username'), password: form.get('password') }) });
    setLoading(false);
    if (!response.ok) { const data = await response.json() as { message?: string }; setError(data.message ?? 'ورود ناموفق بود.'); return; }
    router.replace('/'); router.refresh();
  }

  return <main className="relative grid min-h-screen place-items-center overflow-hidden p-5">
    <div className="pointer-events-none absolute -right-24 -top-24 h-96 w-96 rounded-full bg-mint/10 blur-3xl" />
    <div className="pointer-events-none absolute -bottom-32 -left-20 h-96 w-96 rounded-full bg-gold/10 blur-3xl" />
    <section className="relative w-full max-w-[430px] rounded-4xl border border-white/10 bg-panel/90 p-8 shadow-2xl backdrop-blur-xl sm:p-10">
      <div className="mb-8 flex flex-col items-center">
        <div className="mb-5 grid h-20 w-20 place-items-center rounded-[26px] bg-gradient-to-br from-mint to-emerald-600 text-ink shadow-[0_18px_44px_rgba(47,200,179,.22)]"><Dice5 size={42} strokeWidth={2.4} /></div>
        <h1 className="text-2xl font-black">مدیریت منچ ایرانی</h1>
        <p className="mt-2 text-sm text-muted">ورود امن به مرکز عملیات بازی</p>
      </div>
      <form onSubmit={submit} className="space-y-4">
        <label className="block"><span className="mb-2 block text-xs font-bold text-muted">نام کاربری</span><span className="flex h-14 items-center gap-3 rounded-2xl border border-line bg-ink/45 px-4 focus-within:border-mint/60"><UserRound size={19} className="text-muted" /><input required name="username" autoComplete="username" className="w-full bg-transparent text-sm outline-none placeholder:text-muted/50" placeholder="نام کاربری مدیر" /></span></label>
        <label className="block"><span className="mb-2 block text-xs font-bold text-muted">رمز عبور</span><span className="flex h-14 items-center gap-3 rounded-2xl border border-line bg-ink/45 px-4 focus-within:border-mint/60"><LockKeyhole size={19} className="text-muted" /><input required minLength={10} name="password" type={show ? 'text' : 'password'} autoComplete="current-password" className="w-full bg-transparent text-sm outline-none placeholder:text-muted/50" placeholder="••••••••••••" /><button type="button" onClick={() => setShow(!show)} className="text-muted hover:text-white" aria-label="نمایش رمز">{show ? <EyeOff size={18} /> : <Eye size={18} />}</button></span></label>
        {error && <p role="alert" className="rounded-xl border border-coral/25 bg-coral/10 px-4 py-3 text-xs text-coral">{error}</p>}
        <button disabled={loading} className="mt-2 flex h-14 w-full items-center justify-center rounded-2xl bg-mint font-black text-ink transition hover:bg-[#4ad7c3] disabled:opacity-60">{loading ? <LoaderCircle className="animate-spin" /> : 'ورود به داشبورد'}</button>
      </form>
      <div className="mt-7 flex items-center justify-center gap-2 text-[11px] text-muted"><LockKeyhole size={13} /><span>ارتباط رمزنگاری‌شده و ثبت کامل فعالیت مدیران</span></div>
    </section>
  </main>;
}
