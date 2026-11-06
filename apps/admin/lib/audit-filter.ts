/** Filters for the full audit log page and its CSV export. Everything is validated, so a made up URL cannot widen
 * the query or break it. */

export const AUDIT_AREAS = [
  { key: "all", label: "All", prefixes: [] as string[] },
  { key: "verifications", label: "Verifications", prefixes: ["partner."] },
  { key: "disputes", label: "Disputes", prefixes: ["dispute."] },
  { key: "payouts", label: "Payouts", prefixes: ["payout_run."] },
  { key: "reports", label: "Reports", prefixes: ["report.", "user."] },
  { key: "support", label: "Support and tags", prefixes: ["ticket.", "qr_order.", "lost_alert."] },
  { key: "team", label: "Team and settings", prefixes: ["staff.", "settings."] },
] as const;

export type AuditArea = (typeof AUDIT_AREAS)[number]["key"];

export const AUDIT_RANGES = [
  { key: "7", label: "Last 7 days", days: 7 },
  { key: "30", label: "Last 30 days", days: 30 },
  { key: "all", label: "All time", days: null },
] as const;

export type AuditRange = (typeof AUDIT_RANGES)[number]["key"];

export interface AuditFilter {
  area: AuditArea;
  range: AuditRange;
  /** Part of a team member's name. */
  who: string;
  page: number;
}

type Params = Record<string, string | string[] | undefined>;

const first = (v: string | string[] | undefined) => (Array.isArray(v) ? v[0] : v);

export function parseAuditFilter(sp: Params): AuditFilter {
  const area = AUDIT_AREAS.find((a) => a.key === first(sp.area))?.key ?? "all";
  const range = AUDIT_RANGES.find((r) => r.key === first(sp.range))?.key ?? "all";
  // Letters, spaces, dots, dashes and apostrophes only: enough for any name, nothing that means something to the query.
  const who = (first(sp.who) ?? "")
    .replace(/[^\p{L}\p{N} .'-]/gu, "")
    .trim()
    .slice(0, 60);
  const page = Math.max(1, Math.floor(Number(first(sp.page))) || 1);
  return { area, range, who, page };
}

/** The earliest time to show, or null for no limit. */
export function auditSince(range: AuditRange, now: Date): string | null {
  const days = AUDIT_RANGES.find((r) => r.key === range)?.days ?? null;
  return days === null ? null : new Date(now.getTime() - days * 86_400_000).toISOString();
}

/** A PostgREST `or` filter for the action prefixes of an area, or null for all. */
export function auditActionFilter(area: AuditArea): string | null {
  const prefixes = AUDIT_AREAS.find((a) => a.key === area)?.prefixes ?? [];
  return prefixes.length ? prefixes.map((p) => `action.like.${p}*`).join(",") : null;
}

/** Applies a filter to a query on admin_audit_v. Kept generic so the page and the export share it. */
export function applyAuditFilter<
  Q extends {
    gte(column: string, value: string): Q;
    ilike(column: string, pattern: string): Q;
    or(filters: string): Q;
  },
>(query: Q, f: AuditFilter, now: Date = new Date()): Q {
  let q = query;
  const since = auditSince(f.range, now);
  if (since) q = q.gte("at", since);
  const actions = auditActionFilter(f.area);
  if (actions) q = q.or(actions);
  if (f.who) q = q.ilike("staff_name", `%${f.who}%`);
  return q;
}
