import type { Metadata } from 'next';
import './globals.css';

export const metadata: Metadata = {
  title: { default: 'مدیریت منچ ایرانی', template: '%s | منچ ایرانی' },
  description: 'سامانه مدیریت بازی منچ ایرانی',
  robots: { index: false, follow: false },
};

export default function RootLayout({ children }: Readonly<{ children: React.ReactNode }>) {
  return <html lang="fa" dir="rtl"><body>{children}</body></html>;
}
