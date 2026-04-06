"use client";

import { useQuery } from "convex/react";
import { useConvexAuth } from "convex/react";
import { api } from "../../../convex/_generated/api";
import { UserButton } from "@clerk/nextjs";
import { usePathname } from "next/navigation";
import Link from "next/link";
import { LayoutDashboard, Users, ShieldCheck } from "lucide-react";

const navItems = [
  { href: "/admin", label: "Dashboard", icon: LayoutDashboard },
  { href: "/admin/customers", label: "Customers", icon: Users },
];

export default function AdminLayout({ children }: { children: React.ReactNode }) {
  const { isAuthenticated, isLoading: isAuthLoading } = useConvexAuth();
  const isAdmin = useQuery(api.admin.isAdmin);

  // Still loading auth token or query result — show spinner, never flash "Access Denied"
  if (isAuthLoading || isAdmin === undefined || (!isAuthenticated && isAdmin === false)) {
    return (
      <div className="flex items-center justify-center min-h-screen">
        <div className="animate-spin w-8 h-8 border-2 border-[var(--st-primary)] border-t-transparent rounded-full" />
      </div>
    );
  }

  // Auth is fully loaded AND isAdmin is definitively false — deny access
  if (isAuthenticated && isAdmin === false) {
    return (
      <div className="flex items-center justify-center min-h-screen">
        <div className="p-8 rounded-2xl bg-[var(--st-surface-low)] border border-white/5 text-center max-w-md">
          <ShieldCheck className="w-12 h-12 text-red-400 mx-auto mb-4" />
          <h1 className="text-xl font-bold mb-2">Access Denied</h1>
          <p className="text-[var(--st-on-surface-variant)] text-sm mb-6">
            You don&apos;t have admin access. Contact the administrator if you believe this is an error.
          </p>
          <Link
            href="/"
            className="inline-flex px-5 py-2.5 rounded-full bg-[var(--st-surface)] border border-white/10 text-sm hover:bg-[var(--st-surface-high)] transition-colors"
          >
            Go Home
          </Link>
        </div>
      </div>
    );
  }

  return <AdminShell>{children}</AdminShell>;
}

function AdminShell({ children }: { children: React.ReactNode }) {
  const pathname = usePathname();

  return (
    <div className="flex min-h-screen">
      {/* Sidebar */}
      <aside className="w-60 border-r border-white/5 p-4 flex flex-col">
        <div className="flex items-center gap-2 px-3 py-2 mb-6">
          <div className="w-8 h-8 rounded-lg bg-[var(--st-surface)] border border-[var(--st-primary)]/30 flex items-center justify-center">
            <span className="text-sm font-bold">ST</span>
          </div>
          <div>
            <span className="font-semibold text-sm">Stop Typing</span>
            <span className="block text-[10px] text-[var(--st-primary)]">Admin</span>
          </div>
        </div>

        <nav className="flex-1 space-y-1">
          {navItems.map((item) => {
            const isActive = pathname === item.href;
            return (
              <Link
                key={item.href}
                href={item.href}
                className={`flex items-center gap-3 px-3 py-2 rounded-lg text-sm transition-colors ${
                  isActive
                    ? "bg-[var(--st-primary)]/10 text-[var(--st-primary)]"
                    : "text-[var(--st-on-surface-variant)] hover:text-white hover:bg-[var(--st-surface)]"
                }`}
              >
                <item.icon className="w-4 h-4" />
                {item.label}
              </Link>
            );
          })}
        </nav>

        <div className="pt-4 border-t border-white/5">
          <UserButton signOutOptions={{ redirectUrl: "/" }} />
        </div>
      </aside>

      {/* Main content */}
      <main className="flex-1 p-8">{children}</main>
    </div>
  );
}
