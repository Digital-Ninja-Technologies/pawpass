import type { Metadata } from "next";
import { LegalPage } from "@/components/LegalPage";
import { TERMS } from "@/lib/legal";

export const metadata: Metadata = {
  title: "Terms of use · OurPawPass",
  description: "The rules for using OurPawPass, booking services and buying or adopting a pet.",
  alternates: { canonical: "/terms" },
};

export default function Page() {
  return (
    <LegalPage
      title="Terms of use"
      intro="These are the rules for using OurPawPass, in plain words."
      sections={TERMS}
    />
  );
}
