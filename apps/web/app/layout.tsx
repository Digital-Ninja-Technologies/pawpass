import type { Metadata, Viewport } from "next";
import type { ReactNode } from "react";
import localFont from "next/font/local";
import "./globals.css";

const heading = localFont({
  src: [
    { path: "./fonts/BricolageGrotesque-Bold.ttf", weight: "700", style: "normal" },
    { path: "./fonts/BricolageGrotesque-ExtraBold.ttf", weight: "800", style: "normal" },
  ],
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

const siteUrl = process.env.NEXT_PUBLIC_SITE_URL ?? "https://pawpass.example";
const title = "PawPass · every pet's life, in one place";
const description =
  "Vaccine reminders, trusted vets and groomers, lost pet alerts and verified breeders. One free app for every dog, cat and furry family member. Made in Lagos, for pets everywhere.";

export const metadata: Metadata = {
  metadataBase: new URL(siteUrl),
  title,
  description,
  openGraph: {
    title,
    description,
    type: "website",
    locale: "en_NG",
    siteName: "PawPass",
    images: [
      {
        url: "/photos/bingo.jpg",
        width: 800,
        height: 1067,
        alt: "Bingo, a Boerboel, looking at the camera",
      },
    ],
  },
  twitter: { card: "summary_large_image", title, description },
  alternates: { canonical: "/" },
};

export const viewport: Viewport = { themeColor: "#0e6b63", width: "device-width", initialScale: 1 };

export default function RootLayout({ children }: { children: ReactNode }) {
  return (
    <html lang="en-NG" className={`${heading.variable} ${body.variable}`}>
      <body>{children}</body>
    </html>
  );
}
