import type { Metadata } from "next";
import { LegalPage } from "@/components/LegalPage";
import { PRIVACY } from "@/lib/legal";

export const metadata: Metadata = {
  title: "Privacy policy · PawPass",
  description: "What PawPass collects, why, and who can see it.",
  alternates: { canonical: "/privacy" },
};

export default function Page() {
  return (
    <LegalPage
      title="Privacy policy"
      intro="We keep this short and plain. Your pet's records and your details are yours."
      sections={PRIVACY}
    />
  );
}
