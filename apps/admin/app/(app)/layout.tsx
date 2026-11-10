import type { ReactNode } from "react";
import { cookies } from "next/headers";
import { Flash } from "@/components/Flash";
import { requireStaff } from "@/lib/auth";
import { canView, ROLE_LABELS, type Section } from "@/lib/roles";
import { initials } from "@/lib/format";
import { NavLinks, type NavItem } from "@/components/NavLinks";
import { Icon, type IconName } from "@/components/icons";
import { signOut } from "@/lib/actions/auth";

const NAV: { section: Section; href: string; label: string; icon: IconName }[] = [
  { section: "overview", href: "/", label: "Overview", icon: "overview" },
  {
    section: "verifications",
    href: "/verifications",
    label: "Verifications",
    icon: "verifications",
  },
  { section: "disputes", href: "/disputes", label: "Disputes", icon: "disputes" },
  { section: "reports", href: "/reports", label: "Reports", icon: "reports" },
  { section: "payouts", href: "/payouts", label: "Escrow & payouts", icon: "payouts" },
  { section: "users", href: "/users", label: "Users & partners", icon: "users" },
  { section: "lost", href: "/lost-found", label: "Lost & found", icon: "lost" },
  { section: "support", href: "/support", label: "Support", icon: "support" },
  { section: "settings", href: "/settings", label: "Settings", icon: "settings" },
];

export default async function AppLayout({ children }: { children: ReactNode }) {
  const { supabase, staff } = await requireStaff();
  const raw = (await cookies()).get("flash")?.value;
  const flashMessage = raw ? decodeURIComponent(raw) : null;

  const head = (table: string) => supabase.from(table).select("*", { count: "exact", head: true });
  const [kyc, disputes, reports, tickets] = await Promise.all([
    head("admin_kyc_v").eq("status", "submitted"),
    head("admin_dispute_v").in("status", ["open", "awaiting_partner"]),
    head("admin_report_v").eq("is_open", true),
    head("admin_support_v").eq("status", "open"),
  ]);
  const counts: Partial<Record<Section, number>> = {
    verifications: kyc.count ?? 0,
    disputes: disputes.count ?? 0,
    reports: reports.count ?? 0,
    support: tickets.count ?? 0,
  };

  const items: NavItem[] = NAV.filter((n) => canView(staff.role, n.section)).map((n) => ({
    href: n.href,
    label: n.label,
    icon: <Icon name={n.icon} />,
    count: counts[n.section],
  }));

  return (
    <div className="shell">
      <a className="skip" href="#main">
        Skip to content
      </a>
      <aside className="sidebar">
        <div className="brand">
          <span className="brand-mark" aria-hidden="true">
            <Icon name="paw" size={20} stroke="#fff" />
          </span>
          <span className="brand-name">
            OurPawPass<span className="brand-sub">ADMIN</span>
          </span>
        </div>
        <NavLinks items={items} />
        <div className="me">
          <span className="avatar" aria-hidden="true">
            {initials(staff.name)}
          </span>
          <span className="me-text">
            <span className="me-name">{staff.name}</span>
            <span className="me-role">{ROLE_LABELS[staff.role]}</span>
          </span>
          <form action={signOut}>
            <button type="submit" className="icon-btn" aria-label="Sign out">
              <Icon name="signout" size={18} strokeWidth={2} />
            </button>
          </form>
        </div>
      </aside>
      <main id="main" className="main" tabIndex={-1}>
        {flashMessage ? <Flash key={flashMessage} message={flashMessage} /> : null}
        {children}
      </main>
    </div>
  );
}
