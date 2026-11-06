/** The PRD's twelve month targets, as `admin_launch_metrics()` returns them. */
export interface LaunchMetric {
  value: number;
  target?: number;
  /** For rates: the number out of how many, and the percentage reached against the percentage wanted. */
  of?: number;
  pct?: number;
  target_pct?: number;
}

export type LaunchMetrics = Record<MetricKey, LaunchMetric>;

export type MetricKey =
  | "pets_with_record"
  | "monthly_active_owners"
  | "reminders_acted_7d"
  | "completed_bookings_month"
  | "verified_providers"
  | "verified_breeders_shelters"
  | "lost_found_rate";

export const METRIC_ORDER: { key: MetricKey; label: string; detail: string }[] = [
  {
    key: "pets_with_record",
    label: "Pets with a record",
    detail: "Pets with at least one health record",
  },
  {
    key: "monthly_active_owners",
    label: "Monthly active owners",
    detail: "Opened the app in the last 30 days",
  },
  {
    key: "reminders_acted_7d",
    label: "Reminders acted on",
    detail: "Done within 7 days of the due date",
  },
  { key: "completed_bookings_month", label: "Completed bookings", detail: "This month" },
  {
    key: "verified_providers",
    label: "Verified providers",
    detail: "Approved vets and service providers",
  },
  {
    key: "verified_breeders_shelters",
    label: "Verified breeders and shelters",
    detail: "Approved",
  },
  {
    key: "lost_found_rate",
    label: "Lost pets found",
    detail: "Of finished reports in the last 90 days",
  },
];

/** How far along a metric is, 0 to 100, against its own target. A rate is compared as a percentage. */
export function progress(m: LaunchMetric): number {
  const have = m.target_pct !== undefined ? (m.pct ?? 0) : m.value;
  const want = m.target_pct !== undefined ? m.target_pct : (m.target ?? 0);
  if (!want || want <= 0) return 0;
  return Math.max(0, Math.min(100, Math.round((have / want) * 100)));
}

/** "1,240 of 20,000" for counts, "42.5% of 60%  (17 of 40)" for rates. */
export function describeMetric(m: LaunchMetric): { headline: string; note: string } {
  if (m.target_pct !== undefined) {
    const pct = m.pct ?? 0;
    return {
      headline: `${pct}%`,
      note: `Target ${m.target_pct}%${m.of !== undefined ? ` · ${m.value} of ${m.of}` : ""}`,
    };
  }
  return {
    headline: m.value.toLocaleString("en-NG"),
    note: `Target ${(m.target ?? 0).toLocaleString("en-NG")}`,
  };
}

/** Reads the function's answer, tolerating a missing or partial reply (a new metric, an old database). */
export function parseMetrics(raw: unknown): Partial<LaunchMetrics> {
  if (typeof raw !== "object" || raw === null) return {};
  const out: Partial<LaunchMetrics> = {};
  for (const { key } of METRIC_ORDER) {
    const v = (raw as Record<string, unknown>)[key];
    if (typeof v === "object" && v !== null && typeof (v as LaunchMetric).value === "number") {
      out[key] = v as LaunchMetric;
    }
  }
  return out;
}
