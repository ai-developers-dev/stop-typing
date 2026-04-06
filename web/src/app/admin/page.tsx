"use client";

import { useQuery } from "convex/react";
import { api } from "../../../convex/_generated/api";
import { Users, CreditCard, Clock, DollarSign, AlertTriangle } from "lucide-react";
import { useState } from "react";
import { CustomerModal } from "../components/customer-modal";

type CustomerRow = NonNullable<ReturnType<typeof useQuery<typeof api.admin.listCustomers>>>[number];

export default function AdminDashboard() {
  const stats = useQuery(api.admin.getStats);
  const customers = useQuery(api.admin.listCustomers);
  const [selectedCustomer, setSelectedCustomer] = useState<CustomerRow | null>(null);

  if (!stats || !customers) {
    return (
      <div className="flex items-center justify-center h-64">
        <div className="animate-spin w-8 h-8 border-2 border-[var(--st-primary)] border-t-transparent rounded-full" />
      </div>
    );
  }

  const recentCustomers = customers.slice(0, 10);

  return (
    <div>
      <h1 className="text-2xl font-bold mb-8">Dashboard</h1>

      {/* Stats Grid */}
      <div className="grid grid-cols-2 lg:grid-cols-5 gap-4 mb-10">
        <StatCard icon={Users} label="Total Users" value={stats.totalUsers} />
        <StatCard icon={CreditCard} label="Active" value={stats.active} color="text-green-400" />
        <StatCard icon={Clock} label="Trialing" value={stats.trialing} color="text-blue-400" />
        <StatCard icon={AlertTriangle} label="Past Due" value={stats.pastDue} color="text-yellow-400" />
        <StatCard icon={DollarSign} label="MRR" value={`$${stats.mrr.toFixed(2)}`} color="text-[var(--st-primary)]" />
      </div>

      {/* Recent Customers */}
      <div className="rounded-2xl bg-[var(--st-surface-low)] border border-white/5 overflow-hidden">
        <div className="px-6 py-4 border-b border-white/5">
          <h2 className="font-semibold">Recent Customers</h2>
        </div>
        <table className="w-full">
          <thead>
            <tr className="border-b border-white/5 text-left text-xs text-[var(--st-on-surface-variant)]">
              <th className="px-6 py-3 font-medium">Name</th>
              <th className="px-6 py-3 font-medium">Email</th>
              <th className="px-6 py-3 font-medium">Status</th>
              <th className="px-6 py-3 font-medium">Signed Up</th>
            </tr>
          </thead>
          <tbody>
            {recentCustomers.map((c) => (
              <tr
                key={c._id}
                onClick={() => setSelectedCustomer(c)}
                className="border-b border-white/5 last:border-0 hover:bg-[var(--st-surface)]/50 transition-colors cursor-pointer"
              >
                <td className="px-6 py-3 text-sm">{c.name}</td>
                <td className="px-6 py-3 text-sm text-[var(--st-on-surface-variant)]">{c.email}</td>
                <td className="px-6 py-3">
                  <StatusBadge status={c.subscription?.status || "free"} />
                </td>
                <td className="px-6 py-3 text-sm text-[var(--st-on-surface-variant)]">
                  {new Date(c.createdAt).toLocaleDateString()}
                </td>
              </tr>
            ))}
            {recentCustomers.length === 0 && (
              <tr>
                <td colSpan={4} className="px-6 py-8 text-center text-sm text-[var(--st-on-surface-variant)]">
                  No customers yet
                </td>
              </tr>
            )}
          </tbody>
        </table>
      </div>

      {/* Customer Modal */}
      {selectedCustomer && (
        <CustomerModal
          customer={selectedCustomer}
          onClose={() => setSelectedCustomer(null)}
          isAdmin={true}
        />
      )}
    </div>
  );
}

function StatCard({
  icon: Icon,
  label,
  value,
  color,
}: {
  icon: React.ElementType;
  label: string;
  value: string | number;
  color?: string;
}) {
  return (
    <div className="p-5 rounded-2xl bg-[var(--st-surface-low)] border border-white/5">
      <div className="flex items-center gap-2 mb-2">
        <Icon className={`w-4 h-4 ${color || "text-[var(--st-on-surface-variant)]"}`} />
        <span className="text-xs text-[var(--st-on-surface-variant)]">{label}</span>
      </div>
      <span className={`text-2xl font-bold ${color || ""}`}>{value}</span>
    </div>
  );
}

function StatusBadge({ status }: { status: string }) {
  const styles: Record<string, string> = {
    active: "bg-green-400/10 text-green-400",
    trialing: "bg-blue-400/10 text-blue-400",
    past_due: "bg-yellow-400/10 text-yellow-400",
    canceled: "bg-gray-400/10 text-gray-400",
    unpaid: "bg-red-400/10 text-red-400",
    free: "bg-white/5 text-[var(--st-on-surface-variant)]",
  };

  return (
    <span className={`inline-flex px-2.5 py-0.5 rounded-full text-xs font-medium ${styles[status] || styles.free}`}>
      {status === "past_due" ? "Past Due" : status.charAt(0).toUpperCase() + status.slice(1)}
    </span>
  );
}
