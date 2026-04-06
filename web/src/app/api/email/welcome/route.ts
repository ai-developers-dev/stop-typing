import { auth } from "@clerk/nextjs/server";
import { NextResponse } from "next/server";
import { sendWelcomeEmail } from "@/lib/email";

// Called after user signs up to send welcome email
export async function POST(req: Request) {
  const { userId } = await auth();
  if (!userId) {
    return NextResponse.json({ error: "Unauthorized" }, { status: 401 });
  }

  const { email, name } = await req.json();
  if (!email) {
    return NextResponse.json({ error: "Missing email" }, { status: 400 });
  }

  try {
    await sendWelcomeEmail(email, name);
    return NextResponse.json({ sent: true });
  } catch (err) {
    console.error("Welcome email failed:", err);
    return NextResponse.json({ error: "Failed to send email" }, { status: 500 });
  }
}
