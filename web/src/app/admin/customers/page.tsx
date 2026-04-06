"use client";

import { useQuery } from "convex/react";
import { api } from "../../../../convex/_generated/api";
import { useState } from "react";
import { CustomerModal } from "../../components/customer-modal";

type CustomerRow = NonNullable<ReturnType<typeof useQuery<typeof api.admin.listCustomers>>>[number];

export default function CustomersPage() {
  const customers = useQuery(api.admin.listCustomers);
  const [statusFilter, setStatusFilter] = useState("all");
  const [selectedCustomer, setSelectedCustomer] = useState<CustomerRow | null>(null);

  if (!customers) {
    return (
      <div className="flex items-center justify-center h-64">
        <div className="animate-spin w-8 h-8 border-2 border-[var(--st-primary)] border-t-transparent rounded-full" />
      </div>
    );
  }

  const filtered =
    statusFilter === "all"
      ? customers
      : statusFilter === "free"
        ? customers.filter((c) => !c.subscription)
        : customers.filter((c) => c.subscription?.status === statusFilter);

  return (
    <div>
      <div className="flex items-center justify-between mb-8">
        <h1 className="text-2xl font-bold">Customers</h1>
        <select
          value={statusFilter}
          onChange={(e) => setStatusFilter(e.target.value)}
          className="px-3 py-2 rounded-lg bg-[var(--st-surface)] border border-white/10 text-sm text-[var(--st-on-surface)] focus:outline-none focus:ring-1 focus:ring-[var(--st-primary)]"
        >
          <option value="all">All ({customers.length})</option>
          <option value="active">Active</option>
          <option value="trialing">Trialing</option>
          <option value="past_due">Past Due</option>
          <option value="canceled">Canceled</option>
          <option value="free">Free</option>
        </select>
      </div>

      <div className="rounded-2xl bg-[var(--st-surface-low)] border border-white/5 overflow-hidden">
        <table className="w-full">
          <thead>
            <tr className="border-b border-white/5 text-left text-xs text-[var(--st-on-surface-variant)]">
              <th className="px-6 py-3 font-medium">Name</th>
              <th className="px-6 py-3 font-medium">Email</th>
              <th className="px-6 py-3 font-medium">Status</th>
              <th className="px-6 py-3 font-medium">Trial Ends</th>
              <th className="px-6 py-3 font-medium">Next Billing</th>
              <th className="px-6 py-3 font-medium">Signed Up</th>
            </tr>
          </thead>
          <tbody>
            {filtered.map((c) => (
              <tr
                key={c._id}
                onClick={() => setSelectedCustomer(c)}
                className="border-b border-white/5 last:border-0 hover:bg-[var(--st-surface)]/50 transition-colors cursor-pointer"
              >
                <td className="px-6 py-3 text-sm font-medium">{c.name}</td>
                <td className="px-6 py-3 text-sm text-[var(--st-on-surface-variant)]">{c.email}</td>
                <td className="px-6 py-3">
                  <StatusBadge status={c.subscription?.status || "free"} />
                </td>
                <td className="px-6 py-3 text-sm text-[var(--st-on-surface-variant)]">
                  {c.subscription?.trialEndsAt
                    ? new Date(c.subscription.trialEndsAt).toLocaleDateString()
                    : "—"}
                </td>
                <td className="px-6 py-3 text-sm text-[var(--st-on-surface-variant)]">
                  {c.subscription?.currentPeriodEnd
                    ? new Date(c.subscription.currentPeriodEnd).toLocaleDateString()
                    : "—"}
                </td>
                <td className="px-6 py-3 text-sm text-[var(--st-on-surface-variant)]">
                  {new Date(c.createdAt).toLocaleDateString()}
                </td>
              </tr>
            ))}
            {filtered.length === 0 && (
              <tr>
                <td colSpan={6} className="px-6 py-8 text-center text-sm text-[var(--st-on-surface-variant)]">
                  No customers found
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
