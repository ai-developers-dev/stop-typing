"use client";

import { useUser } from "@clerk/nextjs";
import { useMutation } from "convex/react";
import { api } from "../../../convex/_generated/api";
import { useEffect, useRef } from "react";

/**
 * Syncs the authenticated Clerk user to the Convex `users` table.
 * Sends a welcome email when the user is created for the first time.
 */
export function useStoreUser() {
  const { user, isSignedIn } = useUser();
  const storeUser = useMutation(api.users.getOrCreate);
  const stored = useRef(false);

  useEffect(() => {
    if (!isSignedIn || !user || stored.current) return;

    stored.current = true;
    const email = user.primaryEmailAddress?.emailAddress ?? "";
    const name = [user.firstName, user.lastName].filter(Boolean).join(" ") || undefined;

    storeUser({
      clerkId: user.id,
      email,
      name,
    })
      .then((result) => {
        if (result.isNew) {
          // Send welcome email for new users (fire and forget)
          fetch("/api/email/welcome", {
            method: "POST",
            headers: { "Content-Type": "application/json" },
            body: JSON.stringify({ email, name }),
          }).catch(() => {});
        }
      })
      .catch((err) => {
        console.error("Failed to sync user to Convex:", err);
        stored.current = false;
      });
  }, [isSignedIn, user, storeUser]);
}
