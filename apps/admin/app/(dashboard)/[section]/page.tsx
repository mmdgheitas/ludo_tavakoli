import { safeApi } from '@/lib/api';
import { Filter, Search } from 'lucide-react';
import { ManagementToolbar, RowActions } from '@/components/management-actions';
import { notFound } from 'next/navigation';

type Row = Record<string, unknown>;
type Config = { title: string; subtitle: string; endpoint: string; columns: Array<{ key: string; label: string }> };
const configs: Record<string, Config> = {
  users: { title: 'مدیریت کاربران', subtitle: 'جست‌وجو، مسدودسازی و ارسال پاداش', endpoint: '/admin/users', columns: [{ key: 'username', label: 'نام کاربر' }, { key: 'email', label: 'ایمیل' }, { key: 'coinBalance', label: 'سکه' }, { key: 'fattahBalance', label: 'فتاح' }, { key: 'status', label: 'وضعیت' }, { key: 'createdAt', label: 'عضویت' }] },
  games: { title: 'بازی‌ها', subtitle: 'پایش مسابقه‌های آنلاین و نتیجه‌ها', endpoint: '/admin/games', columns: [{ key: 'id', label: 'شناسه' }, { key: 'mode', label: 'حالت' }, { key: 'status', label: 'وضعیت' }, { key: 'rewardCoins', label: 'پاداش' }, { key: 'createdAt', label: 'شروع' }] },
  shop: { title: 'فروشگاه', subtitle: 'مدیریت ویترین و قیمت‌گذاری محصولات', endpoint: '/admin/items', columns: [{ key: 'nameFa', label: 'محصول' }, { key: 'type', label: 'نوع' }, { key: 'coinPrice', label: 'قیمت سکه‌ای' }, { key: 'active', label: 'فعال' }] },
  items: { title: 'آیتم‌های بازی', subtitle: 'پوسته‌ها، مهره‌ها و آواتارها', endpoint: '/admin/items', columns: [{ key: 'sku', label: 'SKU' }, { key: 'nameFa', label: 'نام' }, { key: 'type', label: 'نوع' }, { key: 'coinPrice', label: 'قیمت' }, { key: 'active', label: 'وضعیت' }] },
  vip: { title: 'عضویت ویژه', subtitle: 'خریدها و دوره‌های فعال VIP', endpoint: '/admin/vip-purchases', columns: [{ key: 'user', label: 'کاربر' }, { key: 'startDate', label: 'شروع' }, { key: 'expireDate', label: 'انقضا' }, { key: 'priceIrr', label: 'مبلغ' }] },
  fattah: { title: 'مدیریت فتاح', subtitle: 'موجودی‌ها، فروش و مصرف داخل بازی', endpoint: '/admin/transactions', columns: [{ key: 'user', label: 'کاربر' }, { key: 'type', label: 'نوع عملیات' }, { key: 'amount', label: 'مقدار' }, { key: 'status', label: 'وضعیت' }, { key: 'createdAt', label: 'زمان' }] },
  payments: { title: 'پرداخت‌ها', subtitle: 'رسیدهای بازار و مایکت و نتیجه اعتبارسنجی', endpoint: '/admin/payments', columns: [{ key: 'user', label: 'کاربر' }, { key: 'provider', label: 'درگاه' }, { key: 'productSku', label: 'محصول' }, { key: 'amountIrr', label: 'مبلغ' }, { key: 'status', label: 'وضعیت' }] },
  transactions: { title: 'تراکنش‌ها', subtitle: 'دفتر کل تغییرات کیف پول', endpoint: '/admin/transactions', columns: [{ key: 'user', label: 'کاربر' }, { key: 'type', label: 'نوع' }, { key: 'amount', label: 'مبلغ' }, { key: 'balanceAfter', label: 'مانده' }, { key: 'createdAt', label: 'زمان' }] },
  chat: { title: 'گفت‌وگوی سریع', subtitle: 'پیام‌ها و واکنش‌های از پیش تعریف‌شده', endpoint: '/admin/quick-chat', columns: [{ key: 'textFa', label: 'متن' }, { key: 'emoji', label: 'ایموجی' }, { key: 'sortOrder', label: 'ترتیب' }, { key: 'active', label: 'فعال' }] },
  analytics: { title: 'گزارش‌های تحلیلی', subtitle: 'خروجی دقیق شاخص‌های محصول', endpoint: '/analytics/trends', columns: [{ key: 'date', label: 'روز' }, { key: 'users', label: 'کاربر جدید' }, { key: 'games', label: 'بازی' }, { key: 'revenueIrr', label: 'درآمد' }] },
  support: { title: 'تیکت‌های پشتیبانی', subtitle: 'پاسخ‌گویی و پیگیری درخواست بازیکنان', endpoint: '/admin/support-tickets', columns: [{ key: 'user', label: 'کاربر' }, { key: 'subject', label: 'موضوع' }, { key: 'status', label: 'وضعیت' }, { key: 'createdAt', label: 'زمان' }] },
  settings: { title: 'تنظیمات سامانه', subtitle: 'پیکربندی تجاری و عملیاتی', endpoint: '/admin/operations', columns: [{ key: 'name', label: 'شاخص' }, { key: 'value', label: 'مقدار' }] },
};
const number = new Intl.NumberFormat('fa-IR');

export default async function SectionPage({ params }: { params: Promise<{ section: string }> }) {
  const { section } = await params;
  const config = configs[section]; if (!config) notFound();
  const response = await safeApi<Row[] | { items?: Row[] } | Row>(config.endpoint, []);
  let rows: Row[] = Array.isArray(response) ? response : 'items' in response && Array.isArray(response.items) ? response.items : Object.entries(response).map(([name, value]) => ({ name, value }));
  if (section === 'fattah') rows = rows.filter((row) => String(row.type ?? '').includes('FATTAH'));
  return <section>
    <div className="mb-6 flex flex-col justify-between gap-4 sm:flex-row sm:items-end"><div><p className="eyebrow">مدیریت / {config.title}</p><h2 className="mt-1 text-2xl font-black">{config.title}</h2><p className="mt-2 text-xs text-muted">{config.subtitle}</p></div><ManagementToolbar section={section} /></div>
    <div className="panel overflow-hidden">
      <div className="flex flex-col justify-between gap-3 border-b border-line p-4 sm:flex-row"><label className="flex h-11 max-w-sm flex-1 items-center gap-2 rounded-2xl bg-ink/40 px-4"><Search size={17} className="text-muted" /><input className="w-full bg-transparent text-xs outline-none" placeholder={`جست‌وجو در ${config.title}…`} /></label><button className="flex h-11 items-center justify-center gap-2 rounded-2xl border border-line px-4 text-xs text-muted"><Filter size={16} />فیلترها</button></div>
      <div className="overflow-x-auto"><table className="w-full border-collapse text-right"><thead><tr className="bg-white/[.025]">{config.columns.map((column) => <th key={column.key} className="table-cell text-[11px] font-bold text-muted">{column.label}</th>)}<th className="table-cell" /></tr></thead><tbody>
        {rows.map((row, index) => <tr key={String(row.id ?? index)} className="border-t border-line/70 transition hover:bg-white/[.025]">{config.columns.map((column) => <td key={column.key} className="table-cell">{format(row[column.key])}</td>)}<td className="table-cell"><RowActions section={section} row={row} /></td></tr>)}
        {!rows.length && <tr><td colSpan={config.columns.length + 1} className="px-6 py-20 text-center"><div className="mx-auto mb-3 grid h-12 w-12 place-items-center rounded-2xl bg-white/5 text-muted"><Search size={20} /></div><p className="text-sm font-bold">داده‌ای برای نمایش نیست</p><p className="mt-1 text-xs text-muted">پس از اتصال API، اطلاعات این بخش نمایش داده می‌شود.</p></td></tr>}
      </tbody></table></div>
      <div className="flex items-center justify-between border-t border-line p-4 text-[11px] text-muted"><span>{number.format(rows.length)} رکورد</span><span>صفحه ۱ از ۱</span></div>
    </div>
  </section>;
}

function format(value: unknown): string {
  if (value == null) return '—';
  if (typeof value === 'boolean') return value ? 'فعال' : 'غیرفعال';
  if (typeof value === 'number') return number.format(value);
  if (typeof value === 'object') {
    if ('username' in value && typeof value.username === 'string') return value.username;
    return 'جزئیات';
  }
  const text = String(value);
  if (/^\d{4}-\d{2}-\d{2}T/.test(text)) return new Intl.DateTimeFormat('fa-IR', { dateStyle: 'medium' }).format(new Date(text));
  const labels: Record<string, string> = { ACTIVE: 'فعال', BANNED: 'مسدود', SUCCEEDED: 'موفق', FAILED: 'ناموفق', PENDING: 'در انتظار', FINISHED: 'تمام‌شده', WAITING: 'در انتظار', ONLINE_2P: 'آنلاین دو نفره', ONLINE_4P: 'آنلاین چهار نفره', CAFE_BAZAAR: 'کافه‌بازار', MYKET: 'مایکت' };
  return labels[text] ?? text;
}
