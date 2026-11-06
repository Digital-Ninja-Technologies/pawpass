import type { Metadata } from "next";
import Link from "next/link";
import { redirect } from "next/navigation";
import { requireSection } from "@/lib/auth";
import { canDo } from "@/lib/roles";
import { describeAudit, resolveAuditNames } from "@/lib/audit";
import {
  AUDIT_AREAS,
  AUDIT_RANGES,
  applyAuditFilter,
  parseAuditFilter,
} from "@/lib/audit-filter";
import { formatDateTime } from "@/lib/format";
import { Empty, PageHeader, Tabs, href } from "@/components/ui";
import type { AuditRow } from "@/lib/types";

export const metadata: Metadata = { title: "Audit log" };
const PAGE = 50;

export default async function AuditPage({
  searchParams,
}: {
  searchParams: Promise<Record<string, string | string[] | undefined>>;
}) {
  const { supabase, staff } = await requireSection("settings");
  if (!canDo(staff.role, "manage_team")) redirect("/settings");
  const filter = parseAuditFilter(await searchParams);
  const { page } = filter;
  const keep = {
    area: filter.area === "all" ? undefined : filter.area,
    range: filter.range === "all" ? undefined : filter.range,
    who: filter.who || undefined,
  };
  const { data, count } = await applyAuditFilter(
    supabase.from("admin_audit_v").select("*", { count: "exact" }),
    filter,
  )
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
          <a className="btn secondary" href={href("/settings/audit/export", keep)}>
            Export CSV
          </a>
        }
      />
      <Tabs
        label="Area"
        items={AUDIT_AREAS.map((a) => ({
          label: a.label,
          href: href("/settings/audit", { ...keep, area: a.key === "all" ? undefined : a.key, page: undefined }),
          active: filter.area === a.key,
        }))}
      />
      <form method="get" className="card row" style={{ gap: 12, flexWrap: "wrap", alignItems: "flex-end" }}>
        {filter.area !== "all" ? <input type="hidden" name="area" value={filter.area} /> : null}
        <label className="field" style={{ flex: "1 1 220px" }}>
          Team member
          <input className="select" type="search" name="who" defaultValue={filter.who} placeholder="Part of a name" />
        </label>
        <label className="field">
          Date
          <select className="select" name="range" defaultValue={filter.range}>
            {AUDIT_RANGES.map((r) => (
              <option key={r.key} value={r.key}>
                {r.label}
              </option>
            ))}
          </select>
        </label>
        <button className="btn" type="submit">
          Apply
        </button>
        <Link className="btn secondary" href="/settings/audit">
          Clear
        </Link>
      </form>
      <section className="card">
        {rows.length === 0 ? (
          <Empty>
            {filter.area !== "all" || filter.range !== "all" || filter.who
              ? "No actions match those filters."
              : "Nothing recorded yet."}
          </Empty>
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
              href={href("/settings/audit", { ...keep, page: String(page - 1) })}
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
              href={href("/settings/audit", { ...keep, page: String(page + 1) })}
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
