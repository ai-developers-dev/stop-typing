"use client";

import { useQuery } from "convex/react";
import { api } from "../../../convex/_generated/api";
import { UserButton } from "@clerk/nextjs";
import { Download, CreditCard, ExternalLink, Shield, Wallet, Pencil } from "lucide-react";
import { useState, useEffect } from "react";
import Link from "next/link";
import { CustomerModal } from "../components/customer-modal";

type BillingInfo = {
  paymentMethod: { brand: string; last4: string; expMonth: number; expYear: number } | null;
  billing: {
    status: string;
    currentPeriodStart: number;
    currentPeriodEnd: number;
    cancelAtPeriodEnd: boolean;
    trialEnd: number | null;
    amount: number | null;
    currency: string;
    interval: string;
  } | null;
};

export default function DashboardPage() {
  const user = useQuery(api.users.getCurrentUser);
  const subscription = useQuery(api.subscriptions.getMySubscription);
  const [checkoutLoading, setCheckoutLoading] = useState(false);
  const [portalLoading, setPortalLoading] = useState(false);
  const [billing, setBilling] = useState<BillingInfo | null>(null);
  const [showEditModal, setShowEditModal] = useState(false);

  const hasSub = subscription !== null && subscription !== undefined;
  const status = subscription?.status;

  // Fetch billing info from Stripe when subscription exists
  useEffect(() => {
    if (!subscription?.stripeCustomerId) return;
    fetch(`/api/stripe/billing?customerId=${subscription.stripeCustomerId}`)
      .then((r) => r.json())
      .then(setBilling)
      .catch(() => {});
  }, [subscription?.stripeCustomerId]);

  async function handleCheckout() {
    setCheckoutLoading(true);
    try {
      const res = await fetch("/api/stripe/checkout", { method: "POST" });
      const data = await res.json();
      if (data.url) window.location.href = data.url;
    } catch (err) {
      console.error("Checkout failed:", err);
    } finally {
      setCheckoutLoading(false);
    }
  }

  async function handlePortal() {
    if (!subscription?.stripeCustomerId) return;
    setPortalLoading(true);
    try {
      const res = await fetch("/api/stripe/portal", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ customerId: subscription.stripeCustomerId }),
      });
      const data = await res.json();
      if (data.url) window.location.href = data.url;
    } catch (err) {
      console.error("Portal failed:", err);
    } finally {
      setPortalLoading(false);
    }
  }

  const card = billing?.paymentMethod;
  const bill = billing?.billing;

  return (
    <div className="min-h-screen">
      <nav className="flex items-center justify-between px-6 py-4 max-w-4xl mx-auto w-full">
        <Link href="/" className="flex items-center gap-2">
          <div className="w-8 h-8 rounded-lg bg-[var(--st-surface)] border border-[var(--st-primary)]/30 flex items-center justify-center">
            <span className="text-sm font-bold">ST</span>
          </div>
          <span className="font-semibold">Stop Typing</span>
        </Link>
        <UserButton signOutOptions={{ redirectUrl: "/" }} />
      </nav>

      <main className="max-w-4xl mx-auto px-6 py-12">
        <h1 className="text-3xl font-bold mb-2">
          {user ? `Welcome, ${user.name || user.email}` : "Dashboard"}
        </h1>
        <p className="text-[var(--st-on-surface-variant)] mb-10">
          Manage your subscription and download Stop Typing.
        </p>

        <div className="grid grid-cols-1 sm:grid-cols-2 gap-6">
          {/* Download Card */}
          <div className="p-6 rounded-2xl bg-[var(--st-surface-low)] border border-white/5">
            <div className="w-10 h-10 rounded-xl bg-[var(--st-primary)]/10 flex items-center justify-center mb-4">
              <Download className="w-5 h-5 text-[var(--st-primary)]" />
            </div>
            <h2 className="font-semibold text-lg mb-2">Download</h2>
            <p className="text-sm text-[var(--st-on-surface-variant)] mb-6">
              Download Stop Typing for macOS. Drag to Applications and launch.
            </p>
            <a
              href="https://github.com/ai-developers-dev/stop-typing/releases/latest"
              target="_blank"
              rel="noopener noreferrer"
              className="inline-flex items-center gap-2 px-5 py-2.5 rounded-full bg-[var(--st-primary)] text-[var(--st-canvas)] text-sm font-semibold hover:bg-[var(--st-primary-container)] transition-colors"
            >
              <Download className="w-4 h-4" />
              Download for Mac
              <ExternalLink className="w-3 h-3" />
            </a>
          </div>

          {/* Subscription & Billing Card */}
          <div className="p-6 rounded-2xl bg-[var(--st-surface-low)] border border-white/5">
            <div className="w-10 h-10 rounded-xl bg-[var(--st-primary)]/10 flex items-center justify-center mb-4">
              <CreditCard className="w-5 h-5 text-[var(--st-primary)]" />
            </div>
            <h2 className="font-semibold text-lg mb-4">Subscription</h2>

            {/* Plan & Status */}
            <div className="space-y-3 mb-5">
              <div className="flex items-center justify-between">
                <span className="text-sm text-[var(--st-on-surface-variant)]">Plan</span>
                <StatusBadge status={status || "free"} />
              </div>

              {bill?.amount && (
                <div className="flex items-center justify-between">
                  <span className="text-sm text-[var(--st-on-surface-variant)]">Price</span>
                  <span className="text-sm font-medium">
                    ${bill.amount.toFixed(2)}/{bill.interval}
                  </span>
                </div>
              )}

              {status === "trialing" && (subscription?.trialEndsAt || bill?.trialEnd) && (
                <div className="flex items-center justify-between">
                  <span className="text-sm text-[var(--st-on-surface-variant)]">Trial ends</span>
                  <span className="text-sm">
                    {new Date(subscription?.trialEndsAt || bill?.trialEnd || 0).toLocaleDateString()}
                  </span>
                </div>
              )}

              {(status === "active" || status === "trialing") && (subscription?.currentPeriodEnd || bill?.currentPeriodEnd) && (
                <div className="flex items-center justify-between">
                  <span className="text-sm text-[var(--st-on-surface-variant)]">Next billing</span>
                  <span className="text-sm">
                    {new Date(subscription?.currentPeriodEnd || bill?.currentPeriodEnd || 0).toLocaleDateString()}
                  </span>
                </div>
              )}

              {bill?.cancelAtPeriodEnd && (
                <div className="px-3 py-2 rounded-lg bg-yellow-400/10 text-yellow-400 text-xs">
                  Cancels at end of billing period
                </div>
              )}
            </div>

            {/* Payment Method */}
            {card && (
              <div className="p-3 rounded-lg bg-[var(--st-surface)] border border-white/5 mb-5">
                <div className="flex items-center justify-between">
                  <div className="flex items-center gap-3">
                    <Wallet className="w-4 h-4 text-[var(--st-on-surface-variant)]" />
                    <div>
                      <p className="text-sm font-medium capitalize">{card.brand} •••• {card.last4}</p>
                      <p className="text-xs text-[var(--st-on-surface-variant)]">
                        Expires {String(card.expMonth).padStart(2, "0")}/{card.expYear}
                      </p>
                    </div>
                  </div>
                  <button
                    onClick={handlePortal}
                    className="text-xs text-[var(--st-primary)] hover:underline"
                  >
                    Edit
                  </button>
                </div>
              </div>
            )}

            {/* Actions */}
            <div className="space-y-3">
              {!hasSub || status === "canceled" ? (
                <>
                  <button
                    onClick={handleCheckout}
                    disabled={checkoutLoading}
                    className="w-full inline-flex items-center justify-center gap-2 px-5 py-2.5 rounded-full bg-[var(--st-primary)] text-[var(--st-canvas)] text-sm font-semibold hover:bg-[var(--st-primary-container)] transition-colors disabled:opacity-50"
                  >
                    {checkoutLoading ? "Redirecting..." : "Start 14-Day Free Trial — $9.99/mo"}
                  </button>
                  <p className="text-xs text-[var(--st-on-surface-variant)] text-center">
                    No charge during trial. Cancel anytime.
                  </p>
                </>
              ) : (
                <button
                  onClick={handlePortal}
                  disabled={portalLoading}
                  className="w-full inline-flex items-center justify-center gap-2 px-5 py-2.5 rounded-full border border-white/10 text-sm font-medium hover:bg-[var(--st-surface)] transition-colors disabled:opacity-50"
                >
                  {portalLoading ? "Redirecting..." : "Manage Subscription"}
                </button>
              )}
            </div>
          </div>

          {/* Account Card */}
          <div
            onClick={() => user && setShowEditModal(true)}
            className="p-6 rounded-2xl bg-[var(--st-surface-low)] border border-white/5 sm:col-span-2 cursor-pointer hover:border-[var(--st-primary)]/20 transition-colors"
          >
            <div className="flex items-center justify-between mb-4">
              <div className="flex items-center gap-3">
                <div className="w-10 h-10 rounded-xl bg-[var(--st-primary)]/10 flex items-center justify-center">
                  <Shield className="w-5 h-5 text-[var(--st-primary)]" />
                </div>
                <h2 className="font-semibold text-lg">Account</h2>
              </div>
              <Pencil className="w-4 h-4 text-[var(--st-on-surface-variant)]" />
            </div>
            {user ? (
              <div className="grid grid-cols-2 gap-4 text-sm">
                <div>
                  <span className="text-[var(--st-on-surface-variant)]">Email</span>
                  <p className="font-medium">{user.email}</p>
                </div>
                <div>
                  <span className="text-[var(--st-on-surface-variant)]">Member since</span>
                  <p className="font-medium">{new Date(user.createdAt).toLocaleDateString()}</p>
                </div>
              </div>
            ) : (
              <p className="text-sm text-[var(--st-on-surface-variant)]">Loading...</p>
            )}
          </div>
        </div>

        {/* Edit Profile Modal */}
        {showEditModal && user && (
          <CustomerModal
            customer={{
              _id: user._id,
              name: user.name || "",
              email: user.email,
              clerkId: user.clerkId,
              createdAt: user.createdAt,
              subscription: subscription ? {
                status: subscription.status,
                stripeCustomerId: subscription.stripeCustomerId,
                stripeSubscriptionId: subscription.stripeSubscriptionId,
                trialEndsAt: subscription.trialEndsAt,
                currentPeriodEnd: subscription.currentPeriodEnd,
              } : null,
            }}
            onClose={() => setShowEditModal(false)}
            isAdmin={false}
          />
        )}
      </main>
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
