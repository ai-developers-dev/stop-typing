import { NextRequest, NextResponse } from "next/server";
import { sendTrialReminderEmail } from "@/lib/email";
import { getStripe } from "@/lib/stripe";

// Runs daily via cron to send trial reminder emails.
// Sends at 3 days before and 1 day before trial ends.
//
// Vercel Cron config (add to vercel.json):
//   { "crons": [{ "path": "/api/cron/trial-reminders", "schedule": "0 14 * * *" }] }
//
// Secured by CRON_SECRET header to prevent public access.

export async function GET(req: NextRequest) {
  // Verify cron secret (prevent public access)
  const cronSecret = req.headers.get("authorization");
  if (cronSecret !== `Bearer ${process.env.CRON_SECRET}`) {
    // Allow in development without secret
    if (process.env.NODE_ENV === "production") {
      return NextResponse.json({ error: "Unauthorized" }, { status: 401 });
    }
  }

  const stripe = getStripe();
  const now = Math.floor(Date.now() / 1000);
  const sent: string[] = [];

  try {
    // Find all trialing subscriptions
    const subscriptions = await stripe.subscriptions.list({
      status: "trialing",
      limit: 100,
    });

    for (const sub of subscriptions.data) {
      if (!sub.trial_end) continue;

      const daysLeft = Math.ceil((sub.trial_end - now) / 86400);

      // Send reminder at 3 days and 1 day before
      if (daysLeft === 3 || daysLeft === 1) {
        const customer = await stripe.customers.retrieve(sub.customer as string);
        if (customer.deleted || !customer.email) continue;

        try {
          await sendTrialReminderEmail(
            customer.email,
            customer.name || undefined,
            daysLeft
          );
          sent.push(`${customer.email} (${daysLeft}d left)`);
        } catch (err) {
          console.error(`Failed to send reminder to ${customer.email}:`, err);
        }
      }
    }

    return NextResponse.json({
      processed: subscriptions.data.length,
      sent,
      timestamp: new Date().toISOString(),
    });
  } catch (err) {
    console.error("Trial reminder cron failed:", err);
    return NextResponse.json({ error: "Cron failed" }, { status: 500 });
  }
}
