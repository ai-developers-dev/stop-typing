import { Mic, Shield, Globe, Zap, Cloud, Keyboard, ChevronRight, Download } from "lucide-react";
import { Nav } from "./components/nav";

export default function Home() {
  return (
    <div className="flex flex-col min-h-screen">
      <Nav />

      {/* Hero */}
      <section className="flex flex-col items-center text-center px-6 pt-24 pb-20 max-w-4xl mx-auto">
        <div className="inline-flex items-center gap-2 px-4 py-1.5 rounded-full bg-[var(--st-surface)] border border-[var(--st-primary)]/20 mb-8">
          <span className="w-2 h-2 rounded-full bg-[var(--st-secondary)] animate-pulse" />
          <span className="text-sm text-[var(--st-on-surface-variant)]">Now with Pro cloud transcription</span>
        </div>
        <h1 className="text-5xl sm:text-7xl font-bold tracking-tight leading-[1.1] mb-6">
          Stop Typing.{" "}
          <span className="bg-gradient-to-r from-[var(--st-primary)] to-[var(--st-primary-container)] bg-clip-text text-transparent">
            Start Talking.
          </span>
        </h1>
        <p className="text-lg sm:text-xl text-[var(--st-on-surface-variant)] max-w-2xl mb-10 leading-relaxed">
          Voice dictation that works everywhere on your Mac. Press a hotkey, speak, and watch your words appear.
          Local AI for privacy. Pro cloud for speed and accuracy.
        </p>
        <div className="flex flex-col sm:flex-row gap-4">
          <a
            href="/sign-up"
            className="inline-flex items-center gap-2 px-8 py-3.5 rounded-full bg-[var(--st-primary)] text-[var(--st-canvas)] font-semibold text-lg hover:bg-[var(--st-primary-container)] transition-colors"
          >
            <Download className="w-5 h-5" />
            Download Free
          </a>
          <a
            href="/sign-up"
            className="inline-flex items-center gap-2 px-8 py-3.5 rounded-full border border-[var(--st-primary)]/30 text-[var(--st-primary)] font-semibold text-lg hover:bg-[var(--st-surface)] transition-colors"
          >
            Start Pro Trial
            <ChevronRight className="w-5 h-5" />
          </a>
        </div>
      </section>

      {/* Features */}
      <section className="px-6 py-20 max-w-6xl mx-auto w-full">
        <h2 className="text-3xl font-bold text-center mb-4">Why Stop Typing?</h2>
        <p className="text-[var(--st-on-surface-variant)] text-center mb-16 max-w-xl mx-auto">
          Built for developers, writers, and anyone who thinks faster than they type.
        </p>
        <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-6">
          {features.map((f) => (
            <div
              key={f.title}
              className="p-6 rounded-2xl bg-[var(--st-surface-low)] border border-white/5 hover:border-[var(--st-primary)]/20 transition-colors"
            >
              <div className="w-10 h-10 rounded-xl bg-[var(--st-primary)]/10 flex items-center justify-center mb-4">
                <f.icon className="w-5 h-5 text-[var(--st-primary)]" />
              </div>
              <h3 className="font-semibold text-lg mb-2">{f.title}</h3>
              <p className="text-sm text-[var(--st-on-surface-variant)] leading-relaxed">{f.description}</p>
            </div>
          ))}
        </div>
      </section>

      {/* How It Works */}
      <section className="px-6 py-20 max-w-4xl mx-auto w-full">
        <h2 className="text-3xl font-bold text-center mb-16">How It Works</h2>
        <div className="grid grid-cols-1 sm:grid-cols-3 gap-8">
          {steps.map((s, i) => (
            <div key={s.title} className="text-center">
              <div className="w-12 h-12 rounded-full bg-[var(--st-primary)]/10 border border-[var(--st-primary)]/20 flex items-center justify-center mx-auto mb-4">
                <span className="text-[var(--st-primary)] font-bold">{i + 1}</span>
              </div>
              <h3 className="font-semibold mb-2">{s.title}</h3>
              <p className="text-sm text-[var(--st-on-surface-variant)]">{s.description}</p>
            </div>
          ))}
        </div>
      </section>

      {/* Pricing */}
      <section className="px-6 py-20 max-w-4xl mx-auto w-full" id="pricing">
        <h2 className="text-3xl font-bold text-center mb-4">Simple Pricing</h2>
        <p className="text-[var(--st-on-surface-variant)] text-center mb-16">
          Start free. Upgrade when you need more speed and accuracy.
        </p>
        <div className="grid grid-cols-1 sm:grid-cols-2 gap-6 max-w-3xl mx-auto">
          {/* Free */}
          <div className="p-8 rounded-2xl bg-[var(--st-surface-low)] border border-white/5">
            <h3 className="font-semibold text-xl mb-1">Free</h3>
            <p className="text-sm text-[var(--st-on-surface-variant)] mb-6">Local on-device transcription</p>
            <div className="text-4xl font-bold mb-6">
              $0<span className="text-lg font-normal text-[var(--st-on-surface-variant)]">/month</span>
            </div>
            <ul className="space-y-3 mb-8">
              {freeFeatures.map((f) => (
                <li key={f} className="flex items-start gap-2 text-sm text-[var(--st-on-surface-variant)]">
                  <span className="text-green-400 mt-0.5">&#10003;</span>
                  {f}
                </li>
              ))}
            </ul>
            <a
              href="/sign-up"
              className="block text-center py-3 rounded-full border border-white/10 text-sm font-medium hover:bg-[var(--st-surface)] transition-colors"
            >
              Download Free
            </a>
          </div>

          {/* Pro */}
          <div className="p-8 rounded-2xl bg-[var(--st-surface-low)] border border-[var(--st-primary)]/30 relative">
            <div className="absolute -top-3 left-1/2 -translate-x-1/2 px-3 py-1 rounded-full bg-[var(--st-primary)] text-[var(--st-canvas)] text-xs font-semibold">
              14-day free trial
            </div>
            <h3 className="font-semibold text-xl mb-1">Pro</h3>
            <p className="text-sm text-[var(--st-on-surface-variant)] mb-6">Cloud-powered transcription</p>
            <div className="text-4xl font-bold mb-6">
              $9.99<span className="text-lg font-normal text-[var(--st-on-surface-variant)]">/month</span>
            </div>
            <ul className="space-y-3 mb-8">
              {proFeatures.map((f) => (
                <li key={f} className="flex items-start gap-2 text-sm text-[var(--st-on-surface-variant)]">
                  <span className="text-[var(--st-primary)] mt-0.5">&#10003;</span>
                  {f}
                </li>
              ))}
            </ul>
            <a
              href="/sign-up"
              className="block text-center py-3 rounded-full bg-[var(--st-primary)] text-[var(--st-canvas)] text-sm font-semibold hover:bg-[var(--st-primary-container)] transition-colors"
            >
              Start Free Trial
            </a>
          </div>
        </div>
      </section>

      {/* FAQ */}
      <section className="px-6 py-20 max-w-3xl mx-auto w-full">
        <h2 className="text-3xl font-bold text-center mb-16">Frequently Asked Questions</h2>
        <div className="space-y-6">
          {faqs.map((faq) => (
            <details key={faq.q} className="group p-6 rounded-2xl bg-[var(--st-surface-low)] border border-white/5">
              <summary className="font-medium cursor-pointer list-none flex items-center justify-between">
                {faq.q}
                <ChevronRight className="w-4 h-4 text-[var(--st-on-surface-variant)] group-open:rotate-90 transition-transform" />
              </summary>
              <p className="mt-4 text-sm text-[var(--st-on-surface-variant)] leading-relaxed">{faq.a}</p>
            </details>
          ))}
        </div>
      </section>

      {/* Footer */}
      <footer className="px-6 py-12 border-t border-white/5">
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

// Data

const features = [
  {
    icon: Mic,
    title: "Works Everywhere",
    description: "Dictate into any app — Slack, VS Code, email, browser, terminal. If you can type there, you can talk there.",
  },
  {
    icon: Shield,
    title: "Privacy First",
    description: "Free tier runs entirely on your Mac. No audio leaves your device. No cloud, no data collection.",
  },
  {
    icon: Zap,
    title: "262x Real-Time (Pro)",
    description: "Pro cloud transcription powered by Groq processes your speech at 262x real-time speed.",
  },
  {
    icon: Globe,
    title: "100+ Languages",
    description: "Auto-detect your language or pin a specific one. Supports over 100 languages out of the box.",
  },
  {
    icon: Cloud,
    title: "Smart Vocabulary",
    description: "Pro models understand technical jargon — SwiftUI, GitHub, Kubernetes, and more.",
  },
  {
    icon: Keyboard,
    title: "Custom Hotkey",
    description: "Set any keyboard shortcut to start and stop recording. Default is Fn (Globe key).",
  },
];

const steps = [
  { title: "Download", description: "Install Stop Typing from a single DMG file. Drag to Applications and launch." },
  { title: "Set Up", description: "Grant microphone access, choose your hotkey, and you're ready in 30 seconds." },
  { title: "Dictate", description: "Press your hotkey anywhere, speak naturally, and watch your words appear instantly." },
];

const freeFeatures = [
  "Local on-device transcription",
  "Multiple AI models (Whisper, Parakeet)",
  "100+ language support",
  "Custom hotkey configuration",
  "Filler word removal",
  "No internet required",
];

const proFeatures = [
  "Everything in Free",
  "Cloud transcription (262x real-time)",
  "Highest accuracy (Whisper Large v3)",
  "Smart technical vocabulary",
  "Priority support",
  "Cancel anytime",
];

const faqs = [
  {
    q: "Is the free tier really free?",
    a: "Yes, completely. The free tier uses local AI models that run on your Mac. No account required, no limits, no ads. You only pay if you want Pro cloud transcription.",
  },
  {
    q: "What's the difference between Free and Pro?",
    a: "Free uses on-device models (good accuracy, works offline). Pro uses Groq's cloud API for faster transcription, higher accuracy, and better handling of technical terms. Pro includes a 14-day free trial.",
  },
  {
    q: "Does my audio get stored?",
    a: "Never. Free tier processes audio entirely on your Mac. Pro tier sends audio to our secure cloud API for transcription only — audio is never stored after processing.",
  },
  {
    q: "Can I cancel my Pro subscription?",
    a: "Yes, cancel anytime from your dashboard. You'll keep Pro access until the end of your billing period, then you'll be downgraded to Free.",
  },
  {
    q: "What macOS version do I need?",
    a: "Stop Typing requires macOS 15 (Sequoia) or later. It runs natively on Apple Silicon and Intel Macs.",
  },
];
