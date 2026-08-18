import { Header } from '@/components/header';
import { Sidebar } from '@/components/sidebar';

export default function DashboardLayout({ children }: { children: React.ReactNode }) {
  return <div className="min-h-screen"><Sidebar /><main className="mx-auto max-w-[1500px] px-5 py-6 lg:mr-[260px] lg:px-8 lg:py-8"><Header />{children}</main></div>;
}
