import type { Metadata } from "next";
import Link from "next/link";
import { redirect } from "next/navigation";
import { requireSection } from "@/lib/auth";
import { canDo } from "@/lib/roles";
import { describeAudit, resolveAuditNames } from "@/lib/audit";
import { formatDateTime } from "@/lib/format";
import { Empty, PageHeader, href } from "@/components/ui";
import type { AuditRow } from "@/lib/types";

export const metadata: Metadata = { title: "Audit log" };
const PAGE = 50;

export default async function AuditPage({
  searchParams,
}: {
  searchParams: Promise<{ page?: string }>;
}) {
  const { supabase, staff } = await requireSection("settings");
  if (!canDo(staff.role, "manage_team")) redirect("/settings");
  const page = Math.max(1, Number((await searchParams).page) || 1);
  const { data, count } = await supabase
    .from("admin_audit_v")
    .select("*", { count: "exact" })
    .order("at", { ascending: false })
    .range((page - 1) * PAGE, page * PAGE - 1);
  const rows = (data ?? []) as AuditRow[];
  const names = await resolveAuditNames(supabase, rows);
  const pages = Math.max(1, Math.ceil((count ?? 0) / PAGE));

  return (
    <>
      <PageHeader
        crumbs={
          <>
            <Link href="/settings">Settings</Link> › Audit log
          </>
        }
        title="Audit log"
        subtitle={`${(count ?? 0).toLocaleString("en-NG")} recorded actions. Entries cannot be edited or deleted.`}
        actions={
          <a className="btn secondary" href="/settings/audit/export">
            Export CSV
          </a>
        }
      />
      <section className="card">
        {rows.length === 0 ? (
          <Empty>Nothing recorded yet.</Empty>
        ) : (
          <div className="table-wrap">
            <table>
              <thead>
                <tr>
                  <th>When</th>
                  <th>Who</th>
                  <th>Action</th>
                </tr>
              </thead>
              <tbody>
                {rows.map((r) => (
                  <tr key={r.id}>
                    <td className="muted" style={{ whiteSpace: "nowrap" }}>
                      {formatDateTime(r.at)}
                    </td>
                    <td>
                      <b>{r.staff_name || "System"}</b>
                    </td>
                    <td>{describeAudit(r, names)}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}
      </section>
      {pages > 1 ? (
        <nav className="row between" aria-label="Pages">
          {page > 1 ? (
            <Link
              className="btn secondary"
              href={href("/settings/audit", { page: String(page - 1) })}
            >
              Newer
            </Link>
          ) : (
            <span />
          )}
          <span className="muted small">
            Page {page} of {pages}
          </span>
          {page < pages ? (
            <Link
              className="btn secondary"
              href={href("/settings/audit", { page: String(page + 1) })}
            >
              Older
            </Link>
          ) : (
            <span />
          )}
        </nav>
      ) : null}
    </>
  );
}
