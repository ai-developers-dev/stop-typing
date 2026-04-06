import { httpRouter } from "convex/server";
import { httpAction } from "./_generated/server";
import { api, internal } from "./_generated/api";

const http = httpRouter();

// Receives Stripe webhook events forwarded from /api/stripe/webhook
http.route({
  path: "/stripe",
  method: "POST",
  handler: httpAction(async (ctx, request) => {
    const body = await request.json();
    const { type, data, eventId } = body;

    // Idempotency check
    const existing = await ctx.runQuery(api.webhookEvents.getByEventId, {
      stripeEventId: eventId,
    });
    if (existing) {
      return new Response(JSON.stringify({ already_processed: true }), {
        status: 200,
      });
    }

    // Process subscription events
    if (
      type === "customer.subscription.created" ||
      type === "customer.subscription.updated"
    ) {
      const sub = data;
      const status = mapStripeStatus(sub.status);
      if (status) {
        await ctx.runMutation(api.subscriptions.updateByStripeSubscription, {
          stripeSubscriptionId: sub.id,
          status,
          currentPeriodEnd: sub.current_period_end
            ? sub.current_period_end * 1000
            : undefined,
        });
      }
    }

    if (type === "customer.subscription.deleted") {
      await ctx.runMutation(api.subscriptions.updateByStripeSubscription, {
        stripeSubscriptionId: data.id,
        status: "canceled",
        currentPeriodEnd: undefined,
      });
    }

    // Log the event
    await ctx.runMutation(api.webhookEvents.log, {
      stripeEventId: eventId,
      type,
    });

    return new Response(JSON.stringify({ received: true }), { status: 200 });
  }),
});

function mapStripeStatus(
  stripeStatus: string
): "trialing" | "active" | "past_due" | "canceled" | "unpaid" | null {
  switch (stripeStatus) {
    case "trialing":
      return "trialing";
    case "active":
      return "active";
    case "past_due":
      return "past_due";
    case "canceled":
      return "canceled";
    case "unpaid":
      return "unpaid";
    default:
      return null;
  }
}

export default http;
