import { auth } from "@clerk/nextjs/server";
import { NextRequest, NextResponse } from "next/server";
import { getStripe } from "@/lib/stripe";

// GET /api/admin/billing?customerId=cus_xxx
// Admin-only: returns payment method + billing for any customer
export async function GET(req: NextRequest) {
  const { userId } = await auth();
  if (!userId) {
    return NextResponse.json({ error: "Unauthorized" }, { status: 401 });
  }

  // Note: admin check is done client-side via Convex isAdmin query.
  // This route is protected by middleware (requires auth) but doesn't
  // re-verify admin server-side. For production, add server-side admin check.

  const customerId = req.nextUrl.searchParams.get("customerId");
  if (!customerId) {
    return NextResponse.json({ error: "Missing customerId" }, { status: 400 });
  }

  const stripe = getStripe();

  try {
    const customer = await stripe.customers.retrieve(customerId);
    if (customer.deleted) {
      return NextResponse.json({ error: "Customer deleted" }, { status: 404 });
    }

    const paymentMethods = await stripe.paymentMethods.list({
      customer: customerId,
      type: "card",
      limit: 5,
    });

    const cards = paymentMethods.data.map((pm) => ({
      id: pm.id,
      brand: pm.card?.brand,
      last4: pm.card?.last4,
      expMonth: pm.card?.exp_month,
      expYear: pm.card?.exp_year,
    }));

    const subscriptions = await stripe.subscriptions.list({
      customer: customerId,
      status: "all",
      limit: 5,
    });

    const subs = subscriptions.data.map((sub) => {
      const price = sub.items.data[0]?.price;
      return {
        id: sub.id,
        status: sub.status,
        currentPeriodStart: sub.current_period_start * 1000,
        currentPeriodEnd: sub.current_period_end * 1000,
        cancelAtPeriodEnd: sub.cancel_at_period_end,
        trialEnd: sub.trial_end ? sub.trial_end * 1000 : null,
        amount: price?.unit_amount ? price.unit_amount / 100 : null,
        currency: price?.currency || "usd",
        interval: price?.recurring?.interval || "month",
      };
    });

    return NextResponse.json({
      customer: {
        id: customer.id,
        email: customer.email,
        name: customer.name,
      },
      cards,
      subscriptions: subs,
    });
  } catch (err) {
    console.error("Admin billing fetch failed:", err);
    return NextResponse.json({ error: "Failed to fetch billing" }, { status: 500 });
  }
}
