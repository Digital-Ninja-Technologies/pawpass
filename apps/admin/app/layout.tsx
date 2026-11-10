import type { Metadata } from "next";
import type { ReactNode } from "react";
import localFont from "next/font/local";
import "./globals.css";

const heading = localFont({
  src: [{ path: "./fonts/BricolageGrotesque-Bold.ttf", weight: "700", style: "normal" }],
  variable: "--font-heading",
  display: "swap",
});
const body = localFont({
  src: [
    { path: "./fonts/PlusJakartaSans-Medium.ttf", weight: "500", style: "normal" },
    { path: "./fonts/PlusJakartaSans-SemiBold.ttf", weight: "600", style: "normal" },
    { path: "./fonts/PlusJakartaSans-Bold.ttf", weight: "700", style: "normal" },
  ],
  variable: "--font-body",
  display: "swap",
});

export const metadata: Metadata = {
  title: { default: "OurPawPass Admin", template: "%s · OurPawPass Admin" },
  description: "Operations console for the OurPawPass team.",
  robots: { index: false, follow: false },
};

export default function RootLayout({ children }: { children: ReactNode }) {
  return (
    <html lang="en-NG" className={`${heading.variable} ${body.variable}`}>
      <body>{children}</body>
    </html>
  );
}
