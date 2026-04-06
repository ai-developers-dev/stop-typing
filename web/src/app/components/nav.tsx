"use client";

import { useUser, SignInButton, UserButton } from "@clerk/nextjs";
import { useQuery } from "convex/react";
import { api } from "../../../convex/_generated/api";
import Link from "next/link";

export function Nav() {
  const { isSignedIn, isLoaded } = useUser();
  const isAdmin = useQuery(api.admin.isAdmin);

  return (
    <nav className="flex items-center justify-between px-6 py-4 max-w-6xl mx-auto w-full">
      <Link href="/" className="flex items-center gap-2">
        <div className="w-8 h-8 rounded-lg bg-[var(--st-surface)] border border-[var(--st-primary)]/30 flex items-center justify-center">
          <span className="text-sm font-bold text-[var(--st-on-surface)]">ST</span>
        </div>
        <span className="font-semibold text-lg">Stop Typing</span>
      </Link>

      <div className="flex items-center gap-4">
        {!isLoaded ? (
          <div className="w-20" />
        ) : isSignedIn ? (
          <>
            {isAdmin && (
              <Link
                href="/admin"
                className="text-sm text-[var(--st-primary)] hover:text-white transition-colors"
              >
                Admin
              </Link>
            )}
            <Link
              href="/dashboard"
              className="text-sm text-[var(--st-on-surface-variant)] hover:text-white transition-colors"
            >
              Dashboard
            </Link>
            <UserButton signOutOptions={{ redirectUrl: "/" }} />
          </>
        ) : (
          <>
            <SignInButton mode="modal">
              <button className="text-sm text-[var(--st-on-surface-variant)] hover:text-white transition-colors">
                Sign In
              </button>
            </SignInButton>
            <SignInButton mode="modal">
              <button className="text-sm font-medium px-4 py-2 rounded-full bg-[var(--st-primary)] text-[var(--st-canvas)] hover:bg-[var(--st-primary-container)] transition-colors">
                Get Started
              </button>
            </SignInButton>
          </>
        )}
      </div>
    </nav>
  );
}
