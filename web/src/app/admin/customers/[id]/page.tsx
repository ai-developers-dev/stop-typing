"use client";

import { useQuery } from "convex/react";
import { api } from "../../../../../convex/_generated/api";
import { useParams } from "next/navigation";
import Link from "next/link";
import { ArrowLeft, User, CreditCard, ExternalLink, Wallet } from "lucide-react";
import { Id } from "../../../../../convex/_generated/dataModel";
import { useState, useEffect } from "react";

type AdminBilling = {
  customer: { id: string; email: string; name: string | null };
  cards: { id: string; brand: string; last4: string; expMonth: number; expYear: number }[];
  subscriptions: {
    id: string;
    status: string;
    currentPeriodStart: number;
    currentPeriodEnd: number;
    cancelAtPeriodEnd: boolean;
    trialEnd: number | null;
    amount: number | null;
    currency: string;
    interval: string;
  }[];
};

export default function CustomerDetailPage() {
  const params = useParams();
  const userId = params.id as Id<"users">;
  const customer = useQuery(api.admin.getCustomer, { userId });
  const [billing, setBilling] = useState<AdminBilling | null>(null);
  const [billingError, setBillingError] = useState(false);

  const stripeCustomerId = customer?.subscription?.stripeCustomerId;

  useEffect(() => {
    if (!stripeCustomerId) return;
    fetch(`/api/admin/billing?customerId=${stripeCustomerId}`)
      .then((r) => r.json())
      .then((data) => {
        if (data.error) {
          setBillingError(true);
        } else {
          setBilling(data);
        }
      })
      .catch(() => setBillingError(true));
  }, [stripeCustomerId]);

  if (customer === undefined) {
    return (
      <div className="flex items-center justify-center h-64">
        <div className="animate-spin w-8 h-8 border-2 border-[var(--st-primary)] border-t-transparent rounded-full" />
      </div>
    );
  }

  if (!customer) {
    return (
      <div className="text-center py-20">
        <p className="text-[var(--st-on-surface-variant)]">Customer not found</p>
      </div>
    );
  }

  const sub = customer.subscription;
  const stripeSub = billing?.subscriptions?.[0];

  return (
    <div>
      <Link
        href="/admin/customers"
        className="inline-flex items-center gap-2 text-sm text-[var(--st-on-surface-variant)] hover:text-white mb-6 transition-colors"
      >
        <ArrowLeft className="w-4 h-4" />
        Back to Customers
      </Link>

      <h1 className="text-2xl font-bold mb-8">{customer.name || customer.email}</h1>

      <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
        {/* Profile Card */}
        <div className="p-6 rounded-2xl bg-[var(--st-surface-low)] border border-white/5">
          <div className="flex items-center gap-3 mb-6">
            <div className="w-10 h-10 rounded-xl bg-[var(--st-primary)]/10 flex items-center justify-center">
              <User className="w-5 h-5 text-[var(--st-primary)]" />
            </div>
            <h2 className="font-semibold text-lg">Profile</h2>
          </div>
          <div className="space-y-4">
            <InfoRow label="Name" value={customer.name || "—"} />
            <InfoRow label="Email" value={customer.email} />
            <InfoRow label="Clerk ID" value={customer.clerkId} mono />
            <InfoRow label="Signed Up" value={new Date(customer.createdAt).toLocaleString()} />
          </div>
        </div>

        {/* Subscription Card */}
        <div className="p-6 rounded-2xl bg-[var(--st-surface-low)] border border-white/5">
          <div className="flex items-center gap-3 mb-6">
            <div className="w-10 h-10 rounded-xl bg-[var(--st-primary)]/10 flex items-center justify-center">
              <CreditCard className="w-5 h-5 text-[var(--st-primary)]" />
            </div>
            <h2 className="font-semibold text-lg">Subscription</h2>
          </div>

          {sub ? (
            <div className="space-y-4">
              <div className="flex items-center justify-between">
                <span className="text-sm text-[var(--st-on-surface-variant)]">Status</span>
                <StatusBadge status={sub.status} />
              </div>

              {stripeSub?.amount && (
                <InfoRow
                  label="Price"
                  value={`$${stripeSub.amount.toFixed(2)}/${stripeSub.interval}`}
                />
              )}
              {!stripeSub?.amount && <InfoRow label="Plan" value="Pro — $9.99/mo" />}

              {sub.trialEndsAt && (
                <InfoRow label="Trial Ends" value={new Date(sub.trialEndsAt).toLocaleString()} />
              )}
              {sub.currentPeriodEnd && (
                <InfoRow label="Next Billing" value={new Date(sub.currentPeriodEnd).toLocaleString()} />
              )}

              {stripeSub?.cancelAtPeriodEnd && (
                <div className="px-3 py-2 rounded-lg bg-yellow-400/10 text-yellow-400 text-xs">
                  Cancels at end of billing period
                </div>
              )}

              <InfoRow label="Stripe Customer" value={sub.stripeCustomerId} mono />

              {sub.stripeCustomerId && (
                <a
                  href={`https://dashboard.stripe.com/customers/${sub.stripeCustomerId}`}
                  target="_blank"
                  rel="noopener noreferrer"
                  className="inline-flex items-center gap-2 text-sm text-[var(--st-primary)] hover:underline"
                >
                  View in Stripe
                  <ExternalLink className="w-3 h-3" />
                </a>
              )}
            </div>
          ) : (
            <p className="text-sm text-[var(--st-on-surface-variant)]">
              No subscription — Free tier
            </p>
          )}
        </div>

        {/* Payment Methods Card */}
        {billing?.cards && billing.cards.length > 0 && (
          <div className="p-6 rounded-2xl bg-[var(--st-surface-low)] border border-white/5 lg:col-span-2">
            <div className="flex items-center gap-3 mb-6">
              <div className="w-10 h-10 rounded-xl bg-[var(--st-primary)]/10 flex items-center justify-center">
                <Wallet className="w-5 h-5 text-[var(--st-primary)]" />
              </div>
              <h2 className="font-semibold text-lg">Payment Methods</h2>
            </div>
            <div className="space-y-3">
              {billing.cards.map((card) => (
                <div
                  key={card.id}
                  className="flex items-center justify-between p-3 rounded-lg bg-[var(--st-surface)] border border-white/5"
                >
                  <div className="flex items-center gap-3">
                    <CreditCard className="w-4 h-4 text-[var(--st-on-surface-variant)]" />
                    <div>
                      <p className="text-sm font-medium capitalize">
                        {card.brand} •••• {card.last4}
                      </p>
                      <p className="text-xs text-[var(--st-on-surface-variant)]">
                        Expires {String(card.expMonth).padStart(2, "0")}/{card.expYear}
                      </p>
                    </div>
                  </div>
                  <span className="text-xs text-[var(--st-on-surface-variant)]">{card.id.slice(0, 12)}...</span>
                </div>
              ))}
            </div>
          </div>
        )}

        {/* No billing data */}
        {stripeCustomerId && !billing && !billingError && (
          <div className="p-6 rounded-2xl bg-[var(--st-surface-low)] border border-white/5 lg:col-span-2 text-center">
            <div className="animate-spin w-6 h-6 border-2 border-[var(--st-primary)] border-t-transparent rounded-full mx-auto mb-2" />
            <p className="text-sm text-[var(--st-on-surface-variant)]">Loading billing details from Stripe...</p>
          </div>
        )}

        {billingError && (
          <div className="p-6 rounded-2xl bg-[var(--st-surface-low)] border border-white/5 lg:col-span-2">
            <p className="text-sm text-[var(--st-on-surface-variant)]">
              Could not load billing details. Stripe keys may not be configured.
            </p>
          </div>
        )}
      </div>
    </div>
  );
}

function InfoRow({ label, value, mono }: { label: string; value: string; mono?: boolean }) {
  return (
    <div className="flex items-start justify-between gap-4">
      <span className="text-sm text-[var(--st-on-surface-variant)] shrink-0">{label}</span>
      <span className={`text-sm text-right break-all ${mono ? "font-mono text-xs" : ""}`}>{value}</span>
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
  };

  return (
    <span className={`inline-flex px-2.5 py-0.5 rounded-full text-xs font-medium ${styles[status] || "bg-white/5 text-white"}`}>
      {status === "past_due" ? "Past Due" : status.charAt(0).toUpperCase() + status.slice(1)}
    </span>
  );
}
