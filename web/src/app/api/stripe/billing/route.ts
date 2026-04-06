import { auth } from "@clerk/nextjs/server";
import { NextRequest, NextResponse } from "next/server";
import { getStripe } from "@/lib/stripe";

// GET /api/stripe/billing?customerId=cus_xxx
// Returns payment method (last4, brand) and subscription details
export async function GET(req: NextRequest) {
  const { userId } = await auth();
  if (!userId) {
    return NextResponse.json({ error: "Unauthorized" }, { status: 401 });
  }

  const customerId = req.nextUrl.searchParams.get("customerId");
  if (!customerId) {
    return NextResponse.json({ error: "Missing customerId" }, { status: 400 });
  }

  const stripe = getStripe();

  try {
    // Get customer's default payment method
    const customer = await stripe.customers.retrieve(customerId, {
      expand: ["default_source"],
    });

    if (customer.deleted) {
      return NextResponse.json({ error: "Customer deleted" }, { status: 404 });
    }

    // Get payment methods
    const paymentMethods = await stripe.paymentMethods.list({
      customer: customerId,
      type: "card",
      limit: 1,
    });

    const card = paymentMethods.data[0]?.card;

    // Get active subscriptions
    const subscriptions = await stripe.subscriptions.list({
      customer: customerId,
      status: "all",
      limit: 1,
      expand: ["data.plan.product"],
    });

    const sub = subscriptions.data[0];
    const plan = sub?.items?.data[0]?.price;

    return NextResponse.json({
      paymentMethod: card
        ? {
            brand: card.brand,
            last4: card.last4,
            expMonth: card.exp_month,
            expYear: card.exp_year,
          }
        : null,
      billing: sub
        ? {
            status: sub.status,
            currentPeriodStart: sub.current_period_start * 1000,
            currentPeriodEnd: sub.current_period_end * 1000,
            cancelAtPeriodEnd: sub.cancel_at_period_end,
            trialEnd: sub.trial_end ? sub.trial_end * 1000 : null,
            amount: plan?.unit_amount ? plan.unit_amount / 100 : null,
            currency: plan?.currency || "usd",
            interval: plan?.recurring?.interval || "month",
          }
        : null,
    });
  } catch (err) {
    console.error("Stripe billing fetch failed:", err);
    return NextResponse.json({ error: "Failed to fetch billing" }, { status: 500 });
  }
}
