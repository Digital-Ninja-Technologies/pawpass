import type { Metadata } from "next";
import { LegalPage } from "@/components/LegalPage";
import { TERMS } from "@/lib/legal";

export const metadata: Metadata = {
  title: "Terms of use · PawPass",
  description: "The rules for using PawPass, booking services and buying or adopting a pet.",
  alternates: { canonical: "/terms" },
};

export default function Page() {
  return (
    <LegalPage
      title="Terms of use"
      intro="These are the rules for using PawPass, in plain words."
      sections={TERMS}
    />
  );
}
