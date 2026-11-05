import type { Metadata } from "next";
import Link from "next/link";
import { redirect } from "next/navigation";
import { requireSection } from "@/lib/auth";
import { canDo } from "@/lib/roles";
import { PageHeader } from "@/components/ui";
import { InviteForm } from "./InviteForm";

export const metadata: Metadata = { title: "Invite a team member" };

export default async function InvitePage() {
  const { staff } = await requireSection("settings");
  if (!canDo(staff.role, "manage_team")) redirect("/settings");
  return (
    <>
      <PageHeader
        crumbs={
          <>
            <Link href="/settings">Settings</Link> › Team &amp; roles › Invite
          </>
        }
        title="Invite a team member"
        subtitle="They get a link to set up their account. Links expire after 48 hours."
      />
      <InviteForm domain={process.env.STAFF_EMAIL_DOMAIN ?? null} />
    </>
  );
}
