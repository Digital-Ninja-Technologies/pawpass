import type { Metadata } from "next";
import Link from "next/link";
import { requireSection } from "@/lib/auth";
import { canDo } from "@/lib/roles";
import { formatKobo, timeAgo } from "@/lib/format";
import { Badge, Empty, PageHeader, Tabs, href } from "@/components/ui";
import type { ReportRow } from "@/lib/types";
import { scamSignals } from "@/lib/reports";
import { ReportActions } from "./ReportActions";

export const metadata: Metadata = { title: "Reports" };

const TYPES = ["all", "listing", "post", "review", "user"] as const;
const TYPE_LABEL: Record<string, string> = {
  all: "All",
  listing: "Listings",
  post: "Posts",
  review: "Reviews",
  user: "Users",
};
const normalise = (t: string) => (t === "profile" ? "user" : t);

export default async function ReportsPage({
  searchParams,
}: {
  searchParams: Promise<{ type?: string; show?: string; id?: string }>;
}) {
  const { supabase, staff } = await requireSection("reports");
  const sp = await searchParams;
  const show = sp.show === "resolved" ? "resolved" : "open";
  const type = (TYPES as readonly string[]).includes(sp.type ?? "") ? sp.type! : "all";

  const { data } = await supabase
    .from("admin_report_v")
    .select("*")
    .eq("is_open", show === "open")
    .order("report_count", { ascending: false })
    .order("first_reported_at", { ascending: true })
    .limit(200);
  const all = (data ?? []) as ReportRow[];
  const count = (t: string) =>
    t === "all" ? all.length : all.filter((r) => normalise(r.target_type) === t).length;
  const filtered = type === "all" ? all : all.filter((r) => normalise(r.target_type) === type);

  // Scam signals first, then most reported.
  const ranked = [...filtered].sort(
    (a, b) => scamSignals(b).length - scamSignals(a).length || b.report_count - a.report_count,
  );
  const selected = ranked.find((r) => r.target_id === sp.id) ?? ranked[0] ?? null;
  const signals = selected ? scamSignals(selected) : [];
  const canAct = canDo(staff.role, "resolve_report") && show === "open";

  return (
    <>
      <PageHeader
        title="Reports & moderation"
        subtitle={
          show === "open"
            ? `${all.length} open · review within 24 hours · scam signals first`
            : "Resolved reports"
        }
      />
      <div className="row between">
        <Tabs
          label="Type"
          items={TYPES.map((t) => ({
            label: TYPE_LABEL[t]!,
            count: count(t),
            active: t === type,
            href: href("/reports", {
              type: t === "all" ? undefined : t,
              show: show === "open" ? undefined : show,
            }),
          }))}
        />
        <Tabs
          label="Show"
          items={[
            {
              label: "Open",
              active: show === "open",
              href: href("/reports", { type: type === "all" ? undefined : type }),
            },
            {
              label: "Resolved",
              active: show === "resolved",
              href: href("/reports", { show: "resolved" }),
            },
          ]}
        />
      </div>

      {!selected ? (
        <div className="card">
          <Empty>{show === "open" ? "No open reports." : "Nothing resolved yet."}</Empty>
        </div>
      ) : (
        <>
          <section
            className="card stack"
            aria-label="Selected report"
            style={signals.length ? { borderColor: "var(--warm)", borderWidth: 2 } : undefined}
          >
            <div className="row between">
              <span className="row">
                {signals.length ? <Badge tone="solid">POSSIBLE SCAM</Badge> : null}
                <Badge>
                  {TYPE_LABEL[
                    normalise(selected.target_type) === "user" ? "user" : selected.target_type
                  ] ?? selected.target_type}
                </Badge>
                <span className="muted small">
                  reported by {selected.report_count}{" "}
                  {selected.report_count === 1 ? "person" : "people"} ·{" "}
                  {timeAgo(selected.first_reported_at)} ago
                </span>
              </span>
              <Badge tone={selected.is_open ? "warn" : "good"}>
                {selected.is_open
                  ? "Open"
                  : (selected.action?.replace(/_/g, " ") ?? selected.last_status)}
              </Badge>
            </div>
            <blockquote className="quote" style={{ margin: 0, fontSize: 16 }}>
              {selected.summary ?? "Content no longer available"}
            </blockquote>
            <p className="small">
              <b>Reason given:</b> {selected.top_reason}
            </p>
            {selected.seller_name ? (
              <p className="small muted">
                Seller: <b>{selected.seller_name}</b>
                {selected.price_kobo ? ` · asking ${formatKobo(selected.price_kobo)}` : ""}
              </p>
            ) : null}
            {signals.length ? (
              <ul className="stack" style={{ listStyle: "none", margin: 0, padding: 0, gap: 6 }}>
                {signals.map((s) => (
                  <li key={s} className="check-row">
                    <Badge tone="bad">Signal</Badge> {s}
                  </li>
                ))}
              </ul>
            ) : null}
            {canAct ? (
              <ReportActions
                key={selected.target_id}
                targetType={selected.target_type}
                targetId={selected.target_id}
                canSuspend
              />
            ) : show === "open" ? (
              <p className="muted small">Your role can view reports but not act on them.</p>
            ) : null}
          </section>

          <section className="card" aria-label="All reports">
            <div className="table-wrap">
              <table>
                <thead>
                  <tr>
                    <th>Content</th>
                    <th>Type</th>
                    <th>Reason</th>
                    <th className="num">Reports</th>
                    <th>Age</th>
                    <th>
                      <span className="sr-only">Actions</span>
                    </th>
                  </tr>
                </thead>
                <tbody>
                  {ranked.map((r) => (
                    <tr key={r.target_type + r.target_id}>
                      <td style={{ maxWidth: 360 }}>
                        {r.summary ?? "Content no longer available"}
                      </td>
                      <td>{TYPE_LABEL[normalise(r.target_type)] ?? r.target_type}</td>
                      <td className="muted">{r.top_reason}</td>
                      <td className="num">{r.report_count}</td>
                      <td className="muted">{timeAgo(r.first_reported_at)}</td>
                      <td>
                        <Link
                          className="btn secondary small"
                          href={href("/reports", {
                            type: type === "all" ? undefined : type,
                            show: show === "open" ? undefined : show,
                            id: r.target_id,
                          })}
                        >
                          Review
                        </Link>
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          </section>
        </>
      )}
    </>
  );
}
