import type { Metadata } from "next";
import { Geist } from "next/font/google";
import { Providers } from "./providers";
import "./globals.css";

const geist = Geist({
  variable: "--font-geist",
  subsets: ["latin"],
});

export const metadata: Metadata = {
  title: "Stop Typing — Voice Dictation for Mac",
  description:
    "Dictate text anywhere on your Mac. Local AI or Pro cloud transcription. Privacy-first, no subscription required for basic use.",
};

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <html lang="en" className={`${geist.variable} h-full antialiased dark`}>
      <body className="min-h-full flex flex-col bg-[#0B0E11] text-[#F8F9FE]">
        <Providers>{children}</Providers>
      </body>
    </html>
  );
}
