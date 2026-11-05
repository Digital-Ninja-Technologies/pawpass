import type { Metadata } from "next";
import Link from "next/link";
import { requireSection } from "@/lib/auth";
import { canDo, ROLE_LABELS } from "@/lib/roles";
import { formatDate, formatDateTime, initials } from "@/lib/format";
import { describeAudit, resolveAuditNames } from "@/lib/audit";
import { Badge, PageHeader } from "@/components/ui";
import type { AuditRow, InviteRow, SettingsRow, StaffRow } from "@/lib/types";
import { SettingsForm } from "./SettingsForm";
import { RevokeInvite, StaffControls } from "./TeamRows";

export const metadata: Metadata = { title: "Settings" };

export default async function SettingsPage() {
  const { supabase, staff, user } = await requireSection("settings");
  const canEdit = canDo(staff.role, "edit_settings");
  const canTeam = canDo(staff.role, "manage_team");

  const [settings, team, invites, audit] = await Promise.all([
    supabase.from("settings").select("*").maybeSingle<SettingsRow>(),
    supabase.from("admin_staff_v").select("*").order("created_at", { ascending: true }),
    canTeam
      ? supabase
          .from("staff_invites")
          .select("*")
          .is("accepted_at", null)
          .is("revoked_at", null)
          .gt("expires_at", new Date().toISOString())
          .order("created_at", { ascending: false })
      : Promise.resolve({ data: [] }),
    canTeam
      ? supabase.from("admin_audit_v").select("*").order("at", { ascending: false }).limit(10)
      : Promise.resolve({ data: [] }),
  ]);
  const staffList = (team.data ?? []) as StaffRow[];
  const inviteList = (invites.data ?? []) as InviteRow[];
  const auditRows = (audit.data ?? []) as AuditRow[];
  const names = canTeam ? await resolveAuditNames(supabase, auditRows) : {};

  return (
    <>
      <PageHeader
        title="Settings"
        subtitle="These rules drive what users see in the app. Changes apply to new bookings and listings only."
      />
      <section className="card stack" aria-labelledby="fees">
        <h2 id="fees">Fees &amp; policies</h2>
        {settings.data ? (
          <SettingsForm s={settings.data} canEdit={canEdit} />
        ) : (
          <p className="muted">Settings could not be loaded.</p>
        )}
      </section>

      <section className="card stack" aria-labelledby="team">
        <div className="card-head">
          <h2 id="team">Team &amp; roles</h2>
          {canTeam ? (
            <Link className="btn secondary small" href="/settings/invite">
              + Invite
            </Link>
          ) : null}
        </div>
        <ul className="list" style={{ listStyle: "none", margin: 0, padding: 0 }}>
          {staffList.map((m) => (
            <li key={m.id} className="item row between">
              <span className="row">
                <span className="avatar" aria-hidden="true">
                  {initials(m.name)}
                </span>
                <span>
                  <b>
                    {m.name || "Team member"}
                    {m.user_id === user.id ? " (you)" : ""}
                  </b>
                  <span className="meta">
                    {ROLE_LABELS[m.role as keyof typeof ROLE_LABELS] ?? m.role} · joined{" "}
                    {formatDate(m.created_at)}
                  </span>
                </span>
              </span>
              <span className="row">
                {m.status !== "active" ? <Badge tone="bad">Suspended</Badge> : null}
                {canTeam && m.user_id !== user.id ? (
                  <StaffControls staffId={m.id} role={m.role} status={m.status} />
                ) : null}
              </span>
            </li>
          ))}
        </ul>
        {inviteList.length ? (
          <div className="stack">
            <div className="overline">Pending invites</div>
            <ul className="list" style={{ listStyle: "none", margin: 0, padding: 0 }}>
              {inviteList.map((i) => (
                <li key={i.id} className="item row between">
                  <span>
                    <b>{i.email}</b>
                    <span className="meta">
                      {ROLE_LABELS[i.role as keyof typeof ROLE_LABELS] ?? i.role} · expires{" "}
                      {formatDateTime(i.expires_at)}
                    </span>
                  </span>
                  <RevokeInvite inviteId={i.id} />
                </li>
              ))}
            </ul>
          </div>
        ) : null}
      </section>

      {canTeam ? (
        <section className="card stack" aria-labelledby="audit">
          <div className="card-head">
            <h2 id="audit">Audit log</h2>
            <Link href="/settings/audit">View full log · export</Link>
          </div>
          {auditRows.length === 0 ? (
            <p className="muted">Nothing recorded yet. Every admin action appears here.</p>
          ) : (
            <ul className="stack" style={{ listStyle: "none", margin: 0, padding: 0, gap: 10 }}>
              {auditRows.map((r) => (
                <li key={r.id} className="row" style={{ alignItems: "baseline", gap: 12 }}>
                  <time className="muted small" style={{ minWidth: 96 }} dateTime={r.at}>
                    {formatDateTime(r.at)}
                  </time>
                  <span>
                    <b>{r.staff_name || "System"}</b> {describeAudit(r, names)}
                  </span>
                </li>
              ))}
            </ul>
          )}
        </section>
      ) : null}
    </>
  );
}
