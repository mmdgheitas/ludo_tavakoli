'use client';

import { FormEvent, useState } from 'react';
import { useRouter } from 'next/navigation';
import { CirclePlus, LoaderCircle, MoreHorizontal } from 'lucide-react';

type Row = Record<string, unknown>;

async function mutate(path: string, method: 'POST' | 'PATCH', body: Record<string, unknown>) {
  const response = await fetch(`/api/admin/${path}`, { method, headers: { 'content-type': 'application/json' }, body: JSON.stringify(body) });
  if (!response.ok) throw new Error((await response.json().catch(() => null) as { message?: string } | null)?.message ?? 'عملیات انجام نشد');
}

export function ManagementToolbar({ section }: { section: string }) {
  const router = useRouter();
  const [open, setOpen] = useState(false);
  const [loading, setLoading] = useState(false);
  const supported = ['items', 'shop', 'chat', 'vip'].includes(section);
  if (!supported) return null;

  async function submit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault(); setLoading(true);
    const values = Object.fromEntries(new FormData(event.currentTarget));
    try {
      if (section === 'items' || section === 'shop') {
        await mutate('items', 'POST', { sku: values.sku, nameFa: values.nameFa, descriptionFa: values.descriptionFa || undefined, type: values.type, coinPrice: Number(values.coinPrice), active: true });
      } else if (section === 'chat') {
        await mutate('quick-chat', 'POST', { textFa: values.textFa, emoji: values.emoji || undefined, sortOrder: Number(values.sortOrder || 0) });
      } else {
        await mutate('settings/vip', 'PATCH', { sku: values.sku, titleFa: values.titleFa, durationDays: Number(values.durationDays), priceIrr: Number(values.priceIrr) });
      }
      setOpen(false); router.refresh();
    } catch (error) { alert(error instanceof Error ? error.message : 'عملیات ناموفق بود'); }
    finally { setLoading(false); }
  }

  return <>
    <button onClick={() => setOpen(true)} className="flex h-11 items-center justify-center gap-2 rounded-2xl bg-mint px-5 text-xs font-black text-ink"><CirclePlus size={17} />{section === 'vip' ? 'ویرایش تنظیمات VIP' : 'افزودن مورد جدید'}</button>
    {open && <div className="fixed inset-0 z-50 grid place-items-center bg-black/70 p-4" onMouseDown={() => setOpen(false)}><form onSubmit={submit} onMouseDown={(event) => event.stopPropagation()} className="panel w-full max-w-md space-y-4 p-6"><h3 className="text-lg font-black">{section === 'vip' ? 'تنظیم عضویت ویژه' : 'ایجاد مورد جدید'}</h3>
      {(section === 'items' || section === 'shop') && <><Field name="sku" label="شناسه SKU" required /><Field name="nameFa" label="نام فارسی" required /><Field name="descriptionFa" label="توضیحات" /><label className="block text-xs text-muted">نوع<select name="type" className="mt-2 h-12 w-full rounded-xl border border-line bg-ink px-3 text-white"><option value="PIECE_SKIN">پوسته مهره</option><option value="AVATAR">آواتار</option><option value="FATTAH">فتاح</option><option value="SPECIAL">ویژه</option></select></label><Field name="coinPrice" label="قیمت سکه‌ای" type="number" required /></>}
      {section === 'chat' && <><Field name="textFa" label="متن پیام" required /><Field name="emoji" label="ایموجی" /><Field name="sortOrder" label="ترتیب" type="number" /></>}
      {section === 'vip' && <><Field name="sku" label="SKU" defaultValue="vip.30d" required /><Field name="titleFa" label="عنوان فارسی" defaultValue="عضویت ویژه یک‌ماهه" required /><Field name="durationDays" label="مدت (روز)" type="number" defaultValue="30" required /><Field name="priceIrr" label="قیمت (ریال)" type="number" required /></>}
      <div className="flex gap-2"><button disabled={loading} className="h-11 flex-1 rounded-xl bg-mint font-bold text-ink">{loading ? <LoaderCircle className="mx-auto animate-spin" size={18} /> : 'ذخیره'}</button><button type="button" onClick={() => setOpen(false)} className="h-11 rounded-xl border border-line px-5 text-muted">انصراف</button></div>
    </form></div>}
  </>;
}

export function RowActions({ section, row }: { section: string; row: Row }) {
  const router = useRouter();
  const id = String(row.id ?? '');
  if (!id || !['users', 'items', 'shop', 'chat', 'support'].includes(section)) return <MoreHorizontal size={16} className="text-muted" />;
  async function act() {
    try {
      if (section === 'users') {
        const choice = prompt('برای مسدودسازی ban و برای پاداش reward را وارد کنید:');
        if (choice === 'ban') await mutate(`users/${id}/status`, 'PATCH', { status: row.status === 'BANNED' ? 'ACTIVE' : 'BANNED', reason: prompt('دلیل تغییر وضعیت:') ?? 'Admin action' });
        if (choice === 'reward') await mutate(`users/${id}/reward`, 'POST', { amount: Number(prompt('مقدار سکه:') ?? 0), reason: prompt('دلیل پاداش:') ?? 'Admin reward' });
      } else if (section === 'items' || section === 'shop') {
        await mutate(`items/${id}`, 'PATCH', { active: !Boolean(row.active) });
      } else if (section === 'chat') {
        await mutate(`quick-chat/${id}`, 'PATCH', { active: !Boolean(row.active) });
      } else {
        await mutate(`support-tickets/${id}`, 'PATCH', { status: 'RESOLVED', response: prompt('پاسخ پشتیبانی:') ?? 'بررسی و حل شد.' });
      }
      router.refresh();
    } catch (error) { alert(error instanceof Error ? error.message : 'عملیات ناموفق بود'); }
  }
  return <button onClick={act} className="rounded-xl border border-line px-3 py-2 text-[11px] text-mint">مدیریت</button>;
}

function Field({ name, label, type = 'text', required = false, defaultValue }: { name: string; label: string; type?: string; required?: boolean; defaultValue?: string }) {
  return <label className="block text-xs text-muted">{label}<input name={name} type={type} required={required} defaultValue={defaultValue} className="mt-2 h-12 w-full rounded-xl border border-line bg-ink px-3 text-white outline-none focus:border-mint" /></label>;
}
