'use client';

import { Area, AreaChart, CartesianGrid, ResponsiveContainer, Tooltip, XAxis, YAxis } from 'recharts';

type Trend = { date: string; users: number; games: number; revenueIrr: number };

const faDigits = new Intl.NumberFormat('fa-IR');
export function DashboardCharts({ data }: { data: Trend[] }) {
  return <div className="h-[280px] w-full" dir="ltr"><ResponsiveContainer width="100%" height="100%"><AreaChart data={data} margin={{ top: 16, right: 6, left: -24, bottom: 0 }}>
    <defs><linearGradient id="games" x1="0" y1="0" x2="0" y2="1"><stop offset="0%" stopColor="#2fc8b3" stopOpacity={0.42} /><stop offset="95%" stopColor="#2fc8b3" stopOpacity={0} /></linearGradient></defs>
    <CartesianGrid vertical={false} stroke="#302842" strokeDasharray="4 5" />
    <XAxis dataKey="date" axisLine={false} tickLine={false} tick={{ fill: '#857b99', fontSize: 10 }} tickFormatter={(value: string) => value.slice(5)} />
    <YAxis axisLine={false} tickLine={false} tick={{ fill: '#857b99', fontSize: 10 }} tickFormatter={(value: number) => faDigits.format(value)} />
    <Tooltip contentStyle={{ background: '#201a31', border: '1px solid #3a304f', borderRadius: 16, direction: 'rtl' }} labelStyle={{ color: '#9990ad' }} />
    <Area type="monotone" dataKey="games" name="بازی" stroke="#2fc8b3" strokeWidth={3} fill="url(#games)" />
    <Area type="monotone" dataKey="users" name="کاربر جدید" stroke="#f4b844" strokeWidth={2} fill="transparent" />
  </AreaChart></ResponsiveContainer></div>;
}
