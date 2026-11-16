import type { Metadata } from "next";
import { LegalPage } from "@/components/LegalPage";
import { DELETE_ACCOUNT } from "@/lib/legal";

export const metadata: Metadata = {
  title: "Delete your account · OurPawPass",
  description: "How to delete your OurPawPass account and what happens to your data.",
  alternates: { canonical: "/delete-account" },
};

export default function Page() {
  return (
    <LegalPage
      title="Delete your account"
      intro="You can delete your OurPawPass account, and the personal data in it, at any time."
      sections={DELETE_ACCOUNT}
    />
  );
}
