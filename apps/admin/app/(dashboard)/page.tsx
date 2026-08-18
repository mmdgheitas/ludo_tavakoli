import { safeApi } from '@/lib/api';
import { DashboardCharts } from '@/components/dashboard-charts';
import { ArrowLeft, CircleDollarSign, Crown, Gamepad2, Rocket, TrendingUp, UserRoundCheck, UsersRound } from 'lucide-react';
import Link from 'next/link';

type Stats = { totalUsers: number; dailyActiveUsers: number; onlineUsers: number; gamesPlayed: number; finishedGames: number; vipPurchases: number; fattahPurchases: number; revenueIrr: number };
type Trend = { date: string; users: number; games: number; revenueIrr: number };
const empty: Stats = { totalUsers: 0, dailyActiveUsers: 0, onlineUsers: 0, gamesPlayed: 0, finishedGames: 0, vipPurchases: 0, fattahPurchases: 0, revenueIrr: 0 };
const number = new Intl.NumberFormat('fa-IR');

export default async function DashboardPage() {
  const [stats, trends] = await Promise.all([safeApi<Stats>('/analytics/dashboard', empty), safeApi<Trend[]>('/analytics/trends', [])]);
  const cards = [
    { label: 'کل کاربران', value: stats.totalUsers, hint: `${number.format(stats.dailyActiveUsers)} فعال امروز`, icon: UsersRound, color: 'text-mint', bg: 'bg-mint/10' },
    { label: 'کاربران آنلاین', value: stats.onlineUsers, hint: 'همین حالا در بازی', icon: UserRoundCheck, color: 'text-emerald-400', bg: 'bg-emerald-400/10' },
    { label: 'بازی‌های امروز', value: stats.gamesPlayed, hint: `${number.format(stats.finishedGames)} بازی تمام‌شده`, icon: Gamepad2, color: 'text-gold', bg: 'bg-gold/10' },
    { label: 'درآمد این ماه', value: stats.revenueIrr, suffix: ' ریال', hint: 'پرداخت تأییدشده', icon: CircleDollarSign, color: 'text-coral', bg: 'bg-coral/10' },
  ];
  return <div className="space-y-6">
    <section className="grid gap-4 sm:grid-cols-2 xl:grid-cols-4">{cards.map(({ label, value, suffix, hint, icon: Icon, color, bg }) => <article key={label} className="panel p-5">
      <div className="flex items-start justify-between"><div><p className="text-xs font-bold text-muted">{label}</p><p className="mt-3 text-2xl font-black">{number.format(value)}<small className="mr-1 text-[10px] font-normal text-muted">{suffix}</small></p></div><span className={`grid h-11 w-11 place-items-center rounded-2xl ${bg} ${color}`}><Icon size={21} /></span></div>
      <div className="mt-4 flex items-center gap-1 text-[10px] text-muted"><TrendingUp size={13} className={color} /><span>{hint}</span></div>
    </article>)}</section>

    <section className="grid gap-5 xl:grid-cols-[1fr_330px]">
      <article className="panel overflow-hidden p-5 sm:p-6"><div className="mb-2 flex items-center justify-between"><div><p className="eyebrow">هفت روز گذشته</p><h2 className="mt-1 text-lg font-black">روند بازی و جذب کاربر</h2></div><Link href="/analytics" className="flex items-center gap-1 text-xs font-bold text-mint">گزارش کامل <ArrowLeft size={15} /></Link></div><DashboardCharts data={trends} /></article>
      <article className="panel p-5 sm:p-6"><p className="eyebrow">فروش این ماه</p><h2 className="mt-1 text-lg font-black">محصولات درآمدزا</h2><div className="mt-7 space-y-5">
        <Product icon={Crown} label="عضویت ویژه" count={stats.vipPurchases} color="bg-gold" />
        <Product icon={Rocket} label="آیتم فتاح" count={stats.fattahPurchases} color="bg-coral" />
        <Product icon={CircleDollarSign} label="مجموع درآمد" count={stats.revenueIrr} color="bg-mint" money />
      </div><Link href="/payments" className="mt-8 flex h-11 items-center justify-center rounded-2xl border border-line text-xs font-bold text-muted hover:bg-white/5 hover:text-white">مشاهده تراکنش‌ها</Link></article>
    </section>

    <section className="panel flex flex-col justify-between gap-5 overflow-hidden p-6 sm:flex-row sm:items-center"><div><span className="rounded-full bg-mint/10 px-3 py-1 text-[10px] font-bold text-mint">وضعیت سامانه</span><h2 className="mt-3 text-lg font-black">همه سرویس‌های اصلی در حال پایش هستند</h2><p className="mt-1 text-xs text-muted">سلامت API، صف بازی و تأیید پرداخت را از بخش عملیات بررسی کنید.</p></div><div className="flex items-center gap-3"><span className="relative flex h-3 w-3"><span className="absolute inline-flex h-full w-full animate-ping rounded-full bg-emerald-400 opacity-60" /><span className="relative inline-flex h-3 w-3 rounded-full bg-emerald-400" /></span><span className="text-xs font-bold text-emerald-400">عملیاتی</span></div></section>
  </div>;
}

function Product({ icon: Icon, label, count, color, money = false }: { icon: typeof Crown; label: string; count: number; color: string; money?: boolean }) {
  return <div className="flex items-center gap-3"><span className={`grid h-10 w-10 place-items-center rounded-xl ${color}/15`}><Icon size={19} className={color.replace('bg-', 'text-')} /></span><div className="min-w-0 flex-1"><p className="text-xs font-bold">{label}</p><div className="mt-2 h-1.5 overflow-hidden rounded-full bg-line"><div className={`h-full w-2/3 rounded-full ${color}`} /></div></div><b className="text-xs">{number.format(count)}{money && <small className="mr-1 font-normal text-muted">ریال</small>}</b></div>;
}
