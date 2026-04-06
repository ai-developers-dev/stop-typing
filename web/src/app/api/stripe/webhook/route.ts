import { NextRequest, NextResponse } from "next/server";
import { getStripe } from "@/lib/stripe";
import { sendSubscriptionConfirmedEmail, sendSubscriptionCanceledEmail } from "@/lib/email";
import Stripe from "stripe";

export async function POST(req: NextRequest) {
  const body = await req.text();
  const signature = req.headers.get("stripe-signature")!;
  const stripe = getStripe();

  let event: Stripe.Event;
  try {
    event = stripe.webhooks.constructEvent(
      body,
      signature,
      process.env.STRIPE_WEBHOOK_SECRET!
    );
  } catch (err) {
    console.error("Webhook signature verification failed:", err);
    return NextResponse.json({ error: "Invalid signature" }, { status: 400 });
  }

  // Forward to Convex HTTP Action for database updates
  const convexSiteUrl = process.env.CONVEX_SITE_URL;
  if (convexSiteUrl) {
    try {
      await fetch(`${convexSiteUrl}/stripe`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          type: event.type,
          data: event.data.object,
          eventId: event.id,
        }),
      });
    } catch (err) {
      console.error("Failed to forward webhook to Convex:", err);
    }
  }

  // Send transactional emails based on subscription events
  try {
    if (event.type === "customer.subscription.updated") {
      const sub = event.data.object as Stripe.Subscription;
      const previousAttrs = event.data.previous_attributes as Partial<Stripe.Subscription> | undefined;

      // Trial → Active (first payment after trial)
      if (sub.status === "active" && previousAttrs?.status === "trialing") {
        const customer = await stripe.customers.retrieve(sub.customer as string);
        if (!customer.deleted && customer.email) {
          await sendSubscriptionConfirmedEmail(customer.email, customer.name || undefined);
        }
      }
    }

    if (event.type === "customer.subscription.deleted") {
      const sub = event.data.object as Stripe.Subscription;
      const customer = await stripe.customers.retrieve(sub.customer as string);
      if (!customer.deleted && customer.email) {
        await sendSubscriptionCanceledEmail(customer.email, customer.name || undefined);
      }
    }
  } catch (err) {
    console.error("Failed to send subscription email:", err);
    // Don't fail the webhook — email is best-effort
  }

  return NextResponse.json({ received: true });
}
