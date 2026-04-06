"use client";

import { useState, useEffect } from "react";
import { useMutation } from "convex/react";
import { api } from "../../../convex/_generated/api";
import { Id } from "../../../convex/_generated/dataModel";
import { X, Trash2, Wallet, CreditCard } from "lucide-react";

type CustomerData = {
  _id: Id<"users">;
  name: string;
  email: string;
  clerkId: string;
  createdAt: number;
  subscription?: {
    status: string;
    stripeCustomerId?: string;
    stripeSubscriptionId?: string;
    trialEndsAt?: number;
    currentPeriodEnd?: number;
  } | null;
};

type BillingCard = {
  id: string;
  brand: string;
  last4: string;
  expMonth: number;
  expYear: number;
};

type BillingData = {
  cards: BillingCard[];
  subscriptions: {
    id: string;
    status: string;
    amount: number | null;
    currency: string;
    interval: string;
    currentPeriodEnd: number;
    cancelAtPeriodEnd: boolean;
    trialEnd: number | null;
  }[];
};

export function CustomerModal({
  customer,
  onClose,
  isAdmin,
}: {
  customer: CustomerData;
  onClose: () => void;
  isAdmin: boolean;
}) {
  const [name, setName] = useState(customer.name || "");
  const [email, setEmail] = useState(customer.email);
  const [saving, setSaving] = useState(false);
  const [deleting, setDeleting] = useState(false);
  const [confirmDelete, setConfirmDelete] = useState(false);
  const [billing, setBilling] = useState<BillingData | null>(null);
  const [portalLoading, setPortalLoading] = useState(false);

  const updateCustomer = useMutation(api.admin.updateCustomer);
  const deleteCustomer = useMutation(api.admin.deleteCustomer);
  const updateMyProfile = useMutation(api.users.updateMyProfile);

  const stripeCustomerId = customer.subscription?.stripeCustomerId;
  const sub = customer.subscription;

  // Fetch billing from Stripe
  useEffect(() => {
    if (!stripeCustomerId) return;
    const endpoint = isAdmin
      ? `/api/admin/billing?customerId=${stripeCustomerId}`
      : `/api/stripe/billing?customerId=${stripeCustomerId}`;

    fetch(endpoint)
      .then((r) => r.json())
      .then((data) => {
        if (!data.error) setBilling(data);
      })
      .catch(() => {});
  }, [stripeCustomerId, isAdmin]);

  async function handleSave() {
    setSaving(true);
    try {
      if (isAdmin) {
        await updateCustomer({ userId: customer._id, name, email });
      } else {
        await updateMyProfile({ name, email });
      }
      onClose();
    } catch (err) {
      console.error("Save failed:", err);
    } finally {
      setSaving(false);
    }
  }

  async function handleDelete() {
    if (!confirmDelete) {
      setConfirmDelete(true);
      return;
    }
    setDeleting(true);
    try {
      await deleteCustomer({ userId: customer._id });
      onClose();
    } catch (err) {
      console.error("Delete failed:", err);
    } finally {
      setDeleting(false);
    }
  }

  async function handlePortal() {
    if (!stripeCustomerId) return;
    setPortalLoading(true);
    try {
      const res = await fetch("/api/stripe/portal", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ customerId: stripeCustomerId }),
      });
      const data = await res.json();
      if (data.url) window.location.href = data.url;
    } catch (err) {
      console.error("Portal failed:", err);
    } finally {
      setPortalLoading(false);
    }
  }

  const stripeSub = billing?.subscriptions?.[0];
  const cards = billing?.cards || [];

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center">
      {/* Backdrop */}
      <div className="absolute inset-0 bg-black/60 backdrop-blur-sm" onClick={onClose} />

      {/* Modal */}
      <div className="relative w-full max-w-lg max-h-[90vh] overflow-y-auto rounded-2xl bg-[var(--st-canvas)] border border-white/10 shadow-2xl">
        {/* Header */}
        <div className="flex items-center justify-between p-6 border-b border-white/5">
          <h2 className="text-lg font-bold">{isAdmin ? "Customer Details" : "Edit Profile"}</h2>
          <button onClick={onClose} className="p-1 rounded-lg hover:bg-[var(--st-surface)] transition-colors">
            <X className="w-5 h-5 text-[var(--st-on-surface-variant)]" />
          </button>
        </div>

        <div className="p-6 space-y-6">
          {/* Edit Form */}
          <div className="space-y-4">
            <div>
              <label className="block text-xs text-[var(--st-on-surface-variant)] mb-1.5">Name</label>
              <input
                type="text"
                value={name}
                onChange={(e) => setName(e.target.value)}
                className="w-full px-3 py-2 rounded-lg bg-[var(--st-surface)] border border-white/10 text-sm focus:outline-none focus:ring-1 focus:ring-[var(--st-primary)]"
              />
            </div>
            <div>
              <label className="block text-xs text-[var(--st-on-surface-variant)] mb-1.5">Email</label>
              <input
                type="email"
                value={email}
                onChange={(e) => setEmail(e.target.value)}
                className="w-full px-3 py-2 rounded-lg bg-[var(--st-surface)] border border-white/10 text-sm focus:outline-none focus:ring-1 focus:ring-[var(--st-primary)]"
              />
            </div>

            {isAdmin && (
              <div className="grid grid-cols-2 gap-4 text-sm">
                <div>
                  <span className="text-xs text-[var(--st-on-surface-variant)]">Clerk ID</span>
                  <p className="font-mono text-xs mt-1 break-all">{customer.clerkId}</p>
                </div>
                <div>
                  <span className="text-xs text-[var(--st-on-surface-variant)]">Signed Up</span>
                  <p className="text-xs mt-1">{new Date(customer.createdAt).toLocaleDateString()}</p>
                </div>
              </div>
            )}
          </div>

          {/* Subscription Info */}
          {sub && (
            <div className="p-4 rounded-xl bg-[var(--st-surface-low)] border border-white/5 space-y-3">
              <h3 className="text-sm font-semibold flex items-center gap-2">
                <CreditCard className="w-4 h-4 text-[var(--st-primary)]" />
                Subscription
              </h3>
              <div className="flex items-center justify-between">
                <span className="text-xs text-[var(--st-on-surface-variant)]">Status</span>
                <StatusBadge status={sub.status} />
              </div>
              {stripeSub?.amount && (
                <div className="flex items-center justify-between">
                  <span className="text-xs text-[var(--st-on-surface-variant)]">Price</span>
                  <span className="text-xs font-medium">${stripeSub.amount.toFixed(2)}/{stripeSub.interval}</span>
                </div>
              )}
              {(sub.trialEndsAt || stripeSub?.trialEnd) && (
                <div className="flex items-center justify-between">
                  <span className="text-xs text-[var(--st-on-surface-variant)]">Trial Ends</span>
                  <span className="text-xs">{new Date(sub.trialEndsAt || stripeSub?.trialEnd || 0).toLocaleDateString()}</span>
                </div>
              )}
              {(sub.currentPeriodEnd || stripeSub?.currentPeriodEnd) && (
                <div className="flex items-center justify-between">
                  <span className="text-xs text-[var(--st-on-surface-variant)]">Next Billing</span>
                  <span className="text-xs">{new Date(sub.currentPeriodEnd || stripeSub?.currentPeriodEnd || 0).toLocaleDateString()}</span>
                </div>
              )}
            </div>
          )}

          {/* Payment Methods */}
          {cards.length > 0 && (
            <div className="p-4 rounded-xl bg-[var(--st-surface-low)] border border-white/5 space-y-3">
              <h3 className="text-sm font-semibold flex items-center gap-2">
                <Wallet className="w-4 h-4 text-[var(--st-primary)]" />
                Payment Method
              </h3>
              {cards.map((card) => (
                <div key={card.id} className="flex items-center justify-between">
                  <div>
                    <p className="text-sm font-medium capitalize">{card.brand} •••• {card.last4}</p>
                    <p className="text-xs text-[var(--st-on-surface-variant)]">
                      Expires {String(card.expMonth).padStart(2, "0")}/{card.expYear}
                    </p>
                  </div>
                  <button
                    onClick={handlePortal}
                    disabled={portalLoading}
                    className="text-xs text-[var(--st-primary)] hover:underline"
                  >
                    {portalLoading ? "..." : "Edit"}
                  </button>
                </div>
              ))}
            </div>
          )}

          {!sub && (
            <div className="p-4 rounded-xl bg-[var(--st-surface-low)] border border-white/5">
              <p className="text-sm text-[var(--st-on-surface-variant)]">Free plan — no payment method on file</p>
            </div>
          )}
        </div>

        {/* Footer Actions */}
        <div className="flex items-center justify-between p-6 border-t border-white/5">
          {isAdmin ? (
            <button
              onClick={handleDelete}
              disabled={deleting}
              className={`inline-flex items-center gap-2 px-4 py-2 rounded-lg text-sm transition-colors ${
                confirmDelete
                  ? "bg-red-500 text-white hover:bg-red-600"
                  : "text-red-400 hover:bg-red-400/10"
              }`}
            >
              <Trash2 className="w-4 h-4" />
              {deleting ? "Deleting..." : confirmDelete ? "Confirm Delete" : "Delete"}
            </button>
          ) : (
            <div />
          )}

          <div className="flex items-center gap-3">
            <button
              onClick={onClose}
              className="px-4 py-2 rounded-lg text-sm text-[var(--st-on-surface-variant)] hover:bg-[var(--st-surface)] transition-colors"
            >
              Cancel
            </button>
            <button
              onClick={handleSave}
              disabled={saving}
              className="px-5 py-2 rounded-lg bg-[var(--st-primary)] text-[var(--st-canvas)] text-sm font-semibold hover:bg-[var(--st-primary-container)] transition-colors disabled:opacity-50"
            >
              {saving ? "Saving..." : "Save Changes"}
            </button>
          </div>
        </div>
      </div>
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
    <span className={`inline-flex px-2 py-0.5 rounded-full text-[10px] font-medium ${styles[status] || styles.free}`}>
      {status === "past_due" ? "Past Due" : status.charAt(0).toUpperCase() + status.slice(1)}
    </span>
  );
}
