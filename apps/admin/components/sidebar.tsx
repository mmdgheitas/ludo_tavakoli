'use client';

import { BadgeDollarSign, BarChart3, Crown, Dice5, Gamepad2, Headphones, LayoutDashboard, MessageCircleMore, PackageOpen, ReceiptText, Rocket, Settings, ShoppingBag, UsersRound } from 'lucide-react';
import Link from 'next/link';
import { usePathname } from 'next/navigation';

const nav = [
  { href: '/', label: 'نمای کلی', icon: LayoutDashboard },
  { href: '/users', label: 'کاربران', icon: UsersRound },
  { href: '/games', label: 'بازی‌ها', icon: Gamepad2 },
  { href: '/shop', label: 'فروشگاه', icon: ShoppingBag },
  { href: '/items', label: 'آیتم‌ها', icon: PackageOpen },
  { href: '/vip', label: 'عضویت ویژه', icon: Crown },
  { href: '/fattah', label: 'فتاح', icon: Rocket },
  { href: '/payments', label: 'پرداخت‌ها', icon: BadgeDollarSign },
  { href: '/transactions', label: 'تراکنش‌ها', icon: ReceiptText },
  { href: '/chat', label: 'گفت‌وگوی سریع', icon: MessageCircleMore },
  { href: '/analytics', label: 'گزارش‌ها', icon: BarChart3 },
  { href: '/support', label: 'پشتیبانی', icon: Headphones },
];

export function Sidebar() {
  const pathname = usePathname();
  return <aside className="fixed inset-y-0 right-0 z-30 hidden w-[260px] border-l border-line bg-[#181326]/95 p-5 backdrop-blur-xl lg:block">
    <div className="mb-8 flex items-center gap-3 px-2 py-2"><span className="grid h-11 w-11 place-items-center rounded-2xl bg-mint text-ink"><Dice5 size={26} /></span><span><b className="block text-[15px]">منچ ایرانی</b><small className="text-[10px] text-muted">مرکز مدیریت</small></span></div>
    <nav className="space-y-1">{nav.map(({ href, label, icon: Icon }) => {
      const active = pathname === href;
      return <Link key={href} href={href} className={`group flex items-center gap-3 rounded-2xl px-4 py-3 text-[13px] font-bold transition ${active ? 'bg-mint text-ink shadow-[0_8px_24px_rgba(47,200,179,.14)]' : 'text-muted hover:bg-white/5 hover:text-white'}`}><Icon size={19} strokeWidth={active ? 2.5 : 1.8} /><span>{label}</span>{active && <span className="mr-auto h-1.5 w-1.5 rounded-full bg-ink/70" />}</Link>;
    })}</nav>
    <div className="absolute bottom-5 left-5 right-5"><Link href="/settings" className="flex items-center gap-3 rounded-2xl border border-line px-4 py-3 text-xs text-muted hover:bg-white/5"><Settings size={18} /><span>تنظیمات سامانه</span></Link></div>
  </aside>;
}
