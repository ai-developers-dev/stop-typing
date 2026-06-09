import { Download, MousePointerClick, ShieldCheck, Mic } from "lucide-react";
import { Nav } from "../components/nav";

export const metadata = {
  title: "Download Stop Typing for Mac",
  description:
    "Download Stop Typing for macOS. Voice dictation that works in every app. 14-day free trial, no account required.",
};

export default function DownloadPage() {
  return (
    <div className="flex flex-col min-h-screen">
      <Nav />

      {/* Hero */}
      <section className="flex flex-col items-center text-center px-6 pt-20 pb-12 max-w-3xl mx-auto">
        <h1 className="text-4xl sm:text-5xl font-bold tracking-tight leading-[1.1] mb-4">
          Download Stop Typing{" "}
          <span className="bg-gradient-to-r from-[var(--st-primary)] to-[var(--st-primary-container)] bg-clip-text text-transparent">
            for Mac
          </span>
        </h1>
        <p className="text-lg text-[var(--st-on-surface-variant)] max-w-xl mb-8 leading-relaxed">
          14-day free trial — no account required. Runs on macOS 14 or later,
          Apple Silicon and Intel.
        </p>
        <a
          href="/StopTyping.dmg"
          className="inline-flex items-center gap-2 px-8 py-3.5 rounded-full bg-[var(--st-primary)] text-[var(--st-canvas)] font-semibold text-lg hover:bg-[var(--st-primary-container)] transition-colors"
        >
          <Download className="w-5 h-5" />
          Download Stop Typing.dmg
        </a>
        <p className="text-xs text-[var(--st-on-surface-variant)] mt-3">
          Version 1.0 &middot; ~4 MB &middot; Signed with Apple Developer ID
        </p>
      </section>

      {/* Install steps */}
      <section className="px-6 py-12 max-w-2xl mx-auto w-full">
        <h2 className="text-2xl font-bold text-center mb-10">
          Install in under a minute
        </h2>
        <div className="space-y-6">
          <div className="flex gap-4 p-6 rounded-2xl bg-[var(--st-surface-low)] border border-white/5">
            <div className="w-10 h-10 shrink-0 rounded-xl bg-[var(--st-primary)]/10 flex items-center justify-center">
              <MousePointerClick className="w-5 h-5 text-[var(--st-primary)]" />
            </div>
            <div>
              <h3 className="font-semibold mb-1">1. Drag to Applications</h3>
              <p className="text-sm text-[var(--st-on-surface-variant)] leading-relaxed">
                Open the downloaded <code>Stop Typing.dmg</code> and drag{" "}
                <strong>Stop Typing</strong> into your Applications folder.
              </p>
            </div>
          </div>

          <div className="flex gap-4 p-6 rounded-2xl bg-[var(--st-surface-low)] border border-white/5">
            <div className="w-10 h-10 shrink-0 rounded-xl bg-[var(--st-primary)]/10 flex items-center justify-center">
              <ShieldCheck className="w-5 h-5 text-[var(--st-primary)]" />
            </div>
            <div>
              <h3 className="font-semibold mb-1">2. Approve the first launch</h3>
              <p className="text-sm text-[var(--st-on-surface-variant)] leading-relaxed">
                Stop Typing is signed with an Apple Developer ID, and notarization
                is in progress — so the very first launch needs a one-time OK.
                On <strong>macOS 15 (Sequoia)</strong>: open the app once, dismiss
                the warning, then go to System Settings &rarr; Privacy &amp;
                Security and click <strong>&ldquo;Open Anyway&rdquo;</strong>. On{" "}
                <strong>macOS 14</strong>: right-click the app &rarr; Open &rarr;
                Open. macOS remembers after that.
              </p>
            </div>
          </div>

          <div className="flex gap-4 p-6 rounded-2xl bg-[var(--st-surface-low)] border border-white/5">
            <div className="w-10 h-10 shrink-0 rounded-xl bg-[var(--st-primary)]/10 flex items-center justify-center">
              <Mic className="w-5 h-5 text-[var(--st-primary)]" />
            </div>
            <div>
              <h3 className="font-semibold mb-1">3. Start talking</h3>
              <p className="text-sm text-[var(--st-on-surface-variant)] leading-relaxed">
                Click <strong>Start 14-Day Free Trial</strong>, grant Microphone
                and Accessibility access when prompted (the &ldquo;Stop
                Typing&rdquo; menu-bar helper does the typing for you), pick your
                hotkey, and dictate into any app. Have a promo code? Redeem it in
                Settings &rarr; Account.
              </p>
            </div>
          </div>
        </div>
      </section>

      {/* Footer */}
      <footer className="px-6 py-12 border-t border-white/5 mt-auto">
        <div className="max-w-6xl mx-auto flex flex-col sm:flex-row items-center justify-between gap-4">
          <div className="flex items-center gap-2">
            <div className="w-6 h-6 rounded bg-[var(--st-surface)] border border-[var(--st-primary)]/30 flex items-center justify-center">
              <span className="text-[10px] font-bold">ST</span>
            </div>
            <span className="text-sm text-[var(--st-on-surface-variant)]">Stop Typing</span>
          </div>
          <p className="text-xs text-[var(--st-on-surface-variant)]" suppressHydrationWarning>
            &copy; {new Date().getFullYear()} Stop Typing. All rights reserved.
          </p>
        </div>
      </footer>
    </div>
  );
}
