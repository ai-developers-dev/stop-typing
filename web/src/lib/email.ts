import { Resend } from "resend";

let resendInstance: Resend | null = null;

function getResend(): Resend {
  if (!resendInstance) {
    resendInstance = new Resend(process.env.RESEND_API_KEY!);
  }
  return resendInstance;
}

const from = process.env.EMAIL_FROM || "doug@aideveloper.dev";
const appUrl = process.env.NEXT_PUBLIC_APP_URL || "https://stoptyping.app";

// ─── Welcome Email ───

export async function sendWelcomeEmail(to: string, name?: string) {
  const resend = getResend();

  await resend.emails.send({
    from: `Stop Typing <${from}>`,
    to,
    subject: "Welcome to Stop Typing — Here's how to get started",
    html: welcomeEmailHtml(name || "there", appUrl),
  });
}

function welcomeEmailHtml(name: string, url: string) {
  return `
<!DOCTYPE html>
<html>
<head><meta charset="utf-8"><meta name="viewport" content="width=device-width"></head>
<body style="margin:0;padding:0;background:#0B0E11;font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',Roboto,sans-serif;">
  <div style="max-width:560px;margin:0 auto;padding:40px 24px;">
    <div style="text-align:center;margin-bottom:32px;">
      <div style="display:inline-block;width:48px;height:48px;line-height:48px;border-radius:12px;background:#1A1F25;border:1px solid rgba(105,218,255,0.3);color:#F8F9FE;font-weight:bold;font-size:18px;">ST</div>
    </div>
    <h1 style="color:#F8F9FE;font-size:24px;font-weight:bold;text-align:center;margin:0 0 8px;">Welcome to Stop Typing!</h1>
    <p style="color:#A0A8B4;text-align:center;margin:0 0 32px;font-size:15px;">Hey ${name}, you're all set to dictate anywhere on your Mac.</p>

    <div style="background:#111519;border-radius:16px;padding:24px;margin-bottom:24px;">
      <h2 style="color:#69DAFF;font-size:16px;margin:0 0 16px;">Getting Started</h2>
      <table style="width:100%;" cellpadding="0" cellspacing="0">
        <tr>
          <td style="color:#69DAFF;font-size:20px;font-weight:bold;width:32px;vertical-align:top;padding:4px 12px 16px 0;">1</td>
          <td style="color:#F8F9FE;font-size:14px;padding:4px 0 16px;">
            <strong>Download the app</strong><br>
            <span style="color:#A0A8B4;">Go to your <a href="${url}/dashboard" style="color:#69DAFF;text-decoration:none;">dashboard</a> and click "Download DMG".</span>
          </td>
        </tr>
        <tr>
          <td style="color:#69DAFF;font-size:20px;font-weight:bold;width:32px;vertical-align:top;padding:4px 12px 16px 0;">2</td>
          <td style="color:#F8F9FE;font-size:14px;padding:4px 0 16px;">
            <strong>Install</strong><br>
            <span style="color:#A0A8B4;">Open the DMG and drag Stop Typing to your Applications folder. Double-click to launch.</span>
          </td>
        </tr>
        <tr>
          <td style="color:#69DAFF;font-size:20px;font-weight:bold;width:32px;vertical-align:top;padding:4px 12px 16px 0;">3</td>
          <td style="color:#F8F9FE;font-size:14px;padding:4px 0 16px;">
            <strong>Grant permissions</strong><br>
            <span style="color:#A0A8B4;">Allow Microphone and Accessibility access when prompted. These are required for dictation.</span>
          </td>
        </tr>
        <tr>
          <td style="color:#69DAFF;font-size:20px;font-weight:bold;width:32px;vertical-align:top;padding:4px 12px 0;">4</td>
          <td style="color:#F8F9FE;font-size:14px;padding:4px 0 0;">
            <strong>Start dictating</strong><br>
            <span style="color:#A0A8B4;">Press your hotkey (default: Fn), speak, and watch your words appear. Works in any app.</span>
          </td>
        </tr>
      </table>
    </div>

    <div style="text-align:center;margin-bottom:32px;">
      <a href="${url}/dashboard" style="display:inline-block;padding:12px 32px;background:#69DAFF;color:#0B0E11;font-weight:600;font-size:15px;border-radius:999px;text-decoration:none;">Go to Dashboard</a>
    </div>

    <p style="color:#A0A8B4;text-align:center;font-size:13px;margin:0;">
      Questions? Reply to this email — we read every message.
    </p>

    <div style="border-top:1px solid rgba(255,255,255,0.05);margin-top:32px;padding-top:16px;text-align:center;">
      <span style="color:#A0A8B4;font-size:11px;">Stop Typing — Voice Dictation for Mac</span>
    </div>
  </div>
</body>
</html>`;
}

// ─── Trial Reminder Email ───

export async function sendTrialReminderEmail(
  to: string,
  name: string | undefined,
  daysLeft: number
) {
  const resend = getResend();

  await resend.emails.send({
    from: `Stop Typing <${from}>`,
    to,
    subject:
      daysLeft === 1
        ? "Your Stop Typing Pro trial ends tomorrow"
        : `Your Stop Typing Pro trial ends in ${daysLeft} days`,
    html: trialReminderHtml(name || "there", daysLeft, appUrl),
  });
}

// ─── Subscription Confirmed Email ───

export async function sendSubscriptionConfirmedEmail(to: string, name?: string) {
  const resend = getResend();
  await resend.emails.send({
    from: `Stop Typing <${from}>`,
    to,
    subject: "Your Stop Typing Pro plan is active!",
    html: subscriptionConfirmedHtml(name || "there", appUrl),
  });
}

// ─── Subscription Canceled Email ───

export async function sendSubscriptionCanceledEmail(to: string, name?: string) {
  const resend = getResend();
  await resend.emails.send({
    from: `Stop Typing <${from}>`,
    to,
    subject: "Your Stop Typing Pro plan has been canceled",
    html: subscriptionCanceledHtml(name || "there", appUrl),
  });
}

// ─── HTML Templates ───

function trialReminderHtml(name: string, daysLeft: number, url: string) {
  const urgency = daysLeft <= 1 ? "tomorrow" : `in ${daysLeft} days`;
  return `
<!DOCTYPE html>
<html>
<head><meta charset="utf-8"><meta name="viewport" content="width=device-width"></head>
<body style="margin:0;padding:0;background:#0B0E11;font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',Roboto,sans-serif;">
  <div style="max-width:560px;margin:0 auto;padding:40px 24px;">
    <div style="text-align:center;margin-bottom:32px;">
      <div style="display:inline-block;width:48px;height:48px;line-height:48px;border-radius:12px;background:#1A1F25;border:1px solid rgba(105,218,255,0.3);color:#F8F9FE;font-weight:bold;font-size:18px;">ST</div>
    </div>
    <h1 style="color:#F8F9FE;font-size:24px;font-weight:bold;text-align:center;margin:0 0 8px;">Your Pro trial ends ${urgency}</h1>
    <p style="color:#A0A8B4;text-align:center;margin:0 0 32px;font-size:15px;">Hey ${name}, just a heads up — your 14-day Pro trial is almost over.</p>

    <div style="background:#111519;border-radius:16px;padding:24px;margin-bottom:24px;">
      <h2 style="color:#69DAFF;font-size:16px;margin:0 0 16px;">What happens next?</h2>
      <ul style="color:#A0A8B4;font-size:14px;line-height:1.8;padding-left:20px;margin:0;">
        <li>Your card will be charged <strong style="color:#F8F9FE;">$9.99/month</strong> to continue Pro</li>
        <li>You'll keep cloud-powered 262x real-time transcription</li>
        <li>Cancel anytime from your dashboard — no questions asked</li>
      </ul>
    </div>

    <div style="background:#111519;border-radius:16px;padding:24px;margin-bottom:24px;">
      <h2 style="color:#F8F9FE;font-size:16px;margin:0 0 8px;">Don't want to continue?</h2>
      <p style="color:#A0A8B4;font-size:14px;margin:0;">No worries — you can cancel from your <a href="${url}/dashboard" style="color:#69DAFF;text-decoration:none;">dashboard</a> before the trial ends. You'll still have access to the free tier with local on-device transcription.</p>
    </div>

    <div style="text-align:center;margin-bottom:32px;">
      <a href="${url}/dashboard" style="display:inline-block;padding:12px 32px;background:#69DAFF;color:#0B0E11;font-weight:600;font-size:15px;border-radius:999px;text-decoration:none;">Manage Subscription</a>
    </div>

    <div style="border-top:1px solid rgba(255,255,255,0.05);margin-top:32px;padding-top:16px;text-align:center;">
      <span style="color:#A0A8B4;font-size:11px;">Stop Typing — Voice Dictation for Mac</span>
    </div>
  </div>
</body>
</html>`;
}

function subscriptionConfirmedHtml(name: string, url: string) {
  return `<!DOCTYPE html><html><head><meta charset="utf-8"><meta name="viewport" content="width=device-width"></head>
<body style="margin:0;padding:0;background:#0B0E11;font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',Roboto,sans-serif;">
  <div style="max-width:560px;margin:0 auto;padding:40px 24px;">
    <div style="text-align:center;margin-bottom:32px;"><div style="display:inline-block;width:48px;height:48px;line-height:48px;border-radius:12px;background:#1A1F25;border:1px solid rgba(105,218,255,0.3);color:#F8F9FE;font-weight:bold;font-size:18px;">ST</div></div>
    <h1 style="color:#F8F9FE;font-size:24px;font-weight:bold;text-align:center;margin:0 0 8px;">You're on Pro!</h1>
    <p style="color:#A0A8B4;text-align:center;margin:0 0 32px;font-size:15px;">Hey ${name}, your Stop Typing Pro plan is now active.</p>
    <div style="background:#111519;border-radius:16px;padding:24px;margin-bottom:24px;">
      <h2 style="color:#69DAFF;font-size:16px;margin:0 0 16px;">What you get with Pro</h2>
      <ul style="color:#A0A8B4;font-size:14px;line-height:2;padding-left:20px;margin:0;">
        <li><strong style="color:#F8F9FE;">Cloud transcription</strong> — 262x real-time speed</li>
        <li><strong style="color:#F8F9FE;">Highest accuracy</strong> — Whisper Large v3 model</li>
        <li><strong style="color:#F8F9FE;">Smart vocabulary</strong> — technical terms, proper names</li>
        <li><strong style="color:#F8F9FE;">Priority support</strong> — reply to any email</li>
      </ul>
    </div>
    <div style="background:#111519;border-radius:16px;padding:24px;margin-bottom:24px;">
      <h2 style="color:#F8F9FE;font-size:16px;margin:0 0 8px;">Enable Pro in the app</h2>
      <p style="color:#A0A8B4;font-size:14px;margin:0;">Open Stop Typing on your Mac. The app will automatically detect your Pro subscription and unlock cloud transcription on your next recording.</p>
    </div>
    <div style="text-align:center;margin-bottom:32px;"><a href="${url}/dashboard" style="display:inline-block;padding:12px 32px;background:#69DAFF;color:#0B0E11;font-weight:600;font-size:15px;border-radius:999px;text-decoration:none;">Go to Dashboard</a></div>
    <p style="color:#A0A8B4;text-align:center;font-size:13px;margin:0;">Manage your subscription anytime from your dashboard.</p>
    <div style="border-top:1px solid rgba(255,255,255,0.05);margin-top:32px;padding-top:16px;text-align:center;"><span style="color:#A0A8B4;font-size:11px;">Stop Typing — Voice Dictation for Mac</span></div>
  </div>
</body></html>`;
}

function subscriptionCanceledHtml(name: string, url: string) {
  return `<!DOCTYPE html><html><head><meta charset="utf-8"><meta name="viewport" content="width=device-width"></head>
<body style="margin:0;padding:0;background:#0B0E11;font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',Roboto,sans-serif;">
  <div style="max-width:560px;margin:0 auto;padding:40px 24px;">
    <div style="text-align:center;margin-bottom:32px;"><div style="display:inline-block;width:48px;height:48px;line-height:48px;border-radius:12px;background:#1A1F25;border:1px solid rgba(105,218,255,0.3);color:#F8F9FE;font-weight:bold;font-size:18px;">ST</div></div>
    <h1 style="color:#F8F9FE;font-size:24px;font-weight:bold;text-align:center;margin:0 0 8px;">We're sorry to see you go</h1>
    <p style="color:#A0A8B4;text-align:center;margin:0 0 32px;font-size:15px;">Hey ${name}, your Pro plan has been canceled.</p>
    <div style="background:#111519;border-radius:16px;padding:24px;margin-bottom:24px;">
      <h2 style="color:#F8F9FE;font-size:16px;margin:0 0 16px;">What changes</h2>
      <ul style="color:#A0A8B4;font-size:14px;line-height:2;padding-left:20px;margin:0;">
        <li><span style="color:#F87171;">&#10007;</span> Cloud transcription is no longer available</li>
        <li><span style="color:#F87171;">&#10007;</span> Smart vocabulary and highest accuracy disabled</li>
        <li><span style="color:#4ADE80;">&#10003;</span> <strong style="color:#F8F9FE;">Local transcription still works</strong> — free forever</li>
        <li><span style="color:#4ADE80;">&#10003;</span> <strong style="color:#F8F9FE;">All your settings are preserved</strong></li>
      </ul>
    </div>
    <div style="background:#111519;border-radius:16px;padding:24px;margin-bottom:24px;">
      <h2 style="color:#F8F9FE;font-size:16px;margin:0 0 8px;">Changed your mind?</h2>
      <p style="color:#A0A8B4;font-size:14px;margin:0;">You can resubscribe anytime from your dashboard. Your Pro features will be restored instantly — no setup required.</p>
    </div>
    <div style="text-align:center;margin-bottom:32px;"><a href="${url}/dashboard" style="display:inline-block;padding:12px 32px;background:#69DAFF;color:#0B0E11;font-weight:600;font-size:15px;border-radius:999px;text-decoration:none;">Resubscribe to Pro</a></div>
    <p style="color:#A0A8B4;text-align:center;font-size:13px;margin:0;">We'd love to hear why you canceled — reply to this email with any feedback.</p>
    <div style="border-top:1px solid rgba(255,255,255,0.05);margin-top:32px;padding-top:16px;text-align:center;"><span style="color:#A0A8B4;font-size:11px;">Stop Typing — Voice Dictation for Mac</span></div>
  </div>
</body></html>`;
}
