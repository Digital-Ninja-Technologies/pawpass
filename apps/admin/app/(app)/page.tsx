import Link from "next/link";
import type { Metadata } from "next";
import { requireStaff } from "@/lib/auth";
import { canView } from "@/lib/roles";
import {
  describeTimeLeft,
  formatDate,
  formatKobo,
  formatKoboShort,
  formatTime,
  hoursLeft,
  nextWeekday,
  toIsoDate,
  WEEKDAYS,
} from "@/lib/format";
import { BarChart } from "@/components/BarChart";
import { Badge, Notice, PageHeader, Stat, Tabs, href, type Tone } from "@/components/ui";
import type { DisputeRow, EscrowRow, KycRow, LostRow, SettingsRow } from "@/lib/types";
import { describeMetric, METRIC_ORDER, parseMetrics, progress } from "@/lib/metrics";

export const metadata: Metadata = { title: "Overview" };

interface Overview {
  active_pets: number;
  bookings_completed: number;
  bookings_completed_prev: number;
  payments_kobo: number;
  payments_prev_kobo: number;
  held_kobo: number;
  held_count: number;
  ready_kobo: number;
  ready_partners: number;
  paused_kobo: number;
  paused_count: number;
  partners: Record<string, number>;
  weekly: { week_start: string; count: number }[] | null;
  kyc_waiting: number;
  kyc_oldest: string | null;
  disputes_open: number;
  disputes_open_kobo: number;
  disputes_due_today: number;
  reports_open: number;
}

const count = (n: number, word: string) => `${n} ${word}${n === 1 ? "" : "s"}`;

function change(now: number, before: number) {
  if (!before) return null;
  const pct = ((now - before) / before) * 100;
  return { pct, up: pct >= 0 };
}

function Delta({ now, before, suffix }: { now: number; before: number; suffix: string }) {
  const c = change(now, before);
  if (!c) return <>{suffix}</>;
  return (
    <>
      <span className={c.up ? "up" : "down"}>
        {c.up ? "▲" : "▼"} {Math.abs(c.pct).toFixed(1)}%
      </span>{" "}
      {suffix}
    </>
  );
}

export default async function OverviewPage({
  searchParams,
}: {
  searchParams: Promise<{ days?: string; denied?: string }>;
}) {
  const { supabase, staff } = await requireStaff();
  const sp = await searchParams;
  const days = [7, 30, 90].includes(Number(sp.days)) ? Number(sp.days) : 30;
  const role = staff.role;

  const [overview, settings, escrow, lost, kyc, disputes, launch] = await Promise.all([
    supabase.rpc("admin_overview", { p_days: days }),
    supabase.from("settings").select("*").maybeSingle<SettingsRow>(),
    supabase.from("admin_escrow_v").select("*").order("created_at", { ascending: false }).limit(4),
    supabase.from("admin_lost_v").select("*").order("created_at", { ascending: false }).limit(3),
    supabase
      .from("admin_kyc_v")
      .select("*")
      .eq("status", "submitted")
      .order("submitted_at", { ascending: false })
      .limit(3),
    supabase.from("admin_dispute_v").select("*").order("created_at", { ascending: false }).limit(3),
    supabase.rpc("admin_launch_metrics"),
  ]);
  const metrics = parseMetrics(launch.data);

  const o = (overview.data ?? {}) as Partial<Overview>;
  const s = settings.data;
  const partners = o.partners ?? {};
  const verifiedTotal = Object.values(partners).reduce((a, b) => a + b, 0);
  const showMoney = canView(role, "payouts");
  const showKyc = canView(role, "verifications");
  const showDisputes = canView(role, "disputes");
  const showReports = canView(role, "reports");

  const bars = (o.weekly ?? []).map((w) => ({
    label: formatDate(w.week_start).replace(/ \d{4}$/, ""),
    value: Number(w.count),
  }));

  const nextRun = nextWeekday(s?.payout_weekday ?? 1);
  const kycLeft = o.kyc_oldest && s ? hoursLeft(o.kyc_oldest, s.kyc_target_hours) : null;

  type Event = { at: string; title: string; who: string; status: string; tone: Tone };
  const events: Event[] = [
    ...((escrow.data ?? []) as EscrowRow[]).map((e) => ({
      at: e.created_at,
      title: `Payment · ${e.subject}`,
      who: `${e.payer_name ?? "Customer"} → ${e.payee_name ?? "Partner"}`,
      status: `${e.status === "held" ? "Held" : e.status.replace(/_/g, " ")} · ${formatKobo(e.amount_kobo)}`,
      tone: "neutral" as Tone,
    })),
    ...((lost.data ?? []) as LostRow[]).map((l) => ({
      at: l.created_at,
      title: `Lost pet alert · ${l.pet_name}`,
      who: l.owner_area ?? "Lagos",
      status: `${l.status === "active" ? "Active" : l.status} · ${l.sightings} ${l.sightings === 1 ? "sighting" : "sightings"}`,
      tone: "warn" as Tone,
    })),
    ...((kyc.data ?? []) as KycRow[]).map((k) => ({
      at: k.submitted_at ?? "",
      title: "Verification submitted",
      who: k.business_name,
      status: "In queue",
      tone: "neutral" as Tone,
    })),
    ...((disputes.data ?? []) as DisputeRow[]).map((d) => ({
      at: d.created_at,
      title: `Dispute opened · ${d.reason}`,
      who: `${d.buyer_name ?? "Buyer"} vs ${d.partner_name ?? "Partner"}`,
      status: d.status === "decided" ? "Decided" : "Needs review",
      tone: d.status === "decided" ? ("good" as Tone) : ("bad" as Tone),
    })),
  ]
    .filter((e) => e.at)
    .sort((a, b) => b.at.localeCompare(a.at))
    .slice(0, 8);

  return (
    <>
      <PageHeader
        title="Overview"
        subtitle={`Lagos · last ${days} days`}
        actions={
          <Tabs
            label="Time range"
            items={[7, 30, 90].map((d) => ({
              label: `${d} days`,
              href: href("/", { days: String(d) }),
              active: d === days,
            }))}
          />
        }
      />
      {sp.denied ? <Notice tone="info">Your role cannot open that page.</Notice> : null}

      <section className="grid stats" aria-label="Key numbers">
        <Stat label="Active pets" value={(o.active_pets ?? 0).toLocaleString("en-NG")} />
        <Stat
          label="Completed bookings"
          value={(o.bookings_completed ?? 0).toLocaleString("en-NG")}
          note={
            <Delta
              now={o.bookings_completed ?? 0}
              before={o.bookings_completed_prev ?? 0}
              suffix={`vs previous ${days} days`}
            />
          }
        />
        {showMoney ? (
          <>
            <Stat
              label="Payments processed"
              value={formatKoboShort(o.payments_kobo)}
              note={
                <Delta
                  now={Number(o.payments_kobo ?? 0)}
                  before={Number(o.payments_prev_kobo ?? 0)}
                  suffix={`vs previous ${days} days`}
                />
              }
            />
            <Stat
              label="Held in escrow now"
              value={formatKoboShort(o.held_kobo)}
              note={`${o.held_count ?? 0} open transactions`}
            />
          </>
        ) : null}
        <Stat
          label="Verified partners"
          value={verifiedTotal}
          note={`${count((partners.vet ?? 0) + (partners.service ?? 0), "provider")} · ${count(partners.breeder ?? 0, "breeder")} · ${count(partners.shelter ?? 0, "shelter")}`}
        />
      </section>

      <section
        className="grid split"
        style={{ gridTemplateColumns: "minmax(0, 1.6fr) minmax(280px, 1fr)" }}
      >
        <div className="card">
          <h2>Completed bookings per week</h2>
          <p className="muted small" style={{ marginBottom: 8 }}>
            Last 12 weeks · hover a bar for the count
          </p>
          <BarChart bars={bars} caption="Completed bookings per week, last 12 weeks" />
        </div>
        <div className="card">
          <div className="card-head">
            <h2>Needs attention</h2>
          </div>
          <ul className="list" style={{ listStyle: "none", margin: 0, padding: 0 }}>
            {showKyc ? (
              <AttentionRow
                href="/verifications"
                value={String(o.kyc_waiting ?? 0)}
                title="Verifications waiting"
                note={
                  kycLeft === null
                    ? "Nothing in the queue"
                    : `Oldest ${Math.max(0, (s?.kyc_target_hours ?? 48) - kycLeft)} hrs · ${describeTimeLeft(kycLeft)}`
                }
              />
            ) : null}
            {showDisputes ? (
              <AttentionRow
                href="/disputes"
                value={String(o.disputes_open ?? 0)}
                title="Open disputes"
                note={`${formatKobo(o.disputes_open_kobo)} held · ${o.disputes_due_today ?? 0} due today`}
              />
            ) : null}
            {showReports ? (
              <AttentionRow
                href="/reports"
                value={String(o.reports_open ?? 0)}
                title="Reported content"
                note="Scam signals come first"
              />
            ) : null}
            {showMoney ? (
              <AttentionRow
                href="/payouts"
                value={WEEKDAYS[(s?.payout_weekday ?? 1) - 1]!.slice(0, 3)}
                title="Next payout run"
                note={`${formatKoboShort(o.ready_kobo)} to ${o.ready_partners ?? 0} partners · ${formatDate(toIsoDate(nextRun))}`}
              />
            ) : null}
          </ul>
        </div>
      </section>

      <section className="card">
        <div className="card-head">
          <h2>Recent activity</h2>
        </div>
        {events.length === 0 ? (
          <p className="muted">Nothing to show yet. Activity appears here as people use the app.</p>
        ) : (
          <div className="table-wrap">
            <table>
              <thead>
                <tr>
                  <th>Time</th>
                  <th>Event</th>
                  <th>Who</th>
                  <th>Status</th>
                </tr>
              </thead>
              <tbody>
                {events.map((e, i) => (
                  <tr key={i}>
                    <td className="muted">{formatTime(e.at)}</td>
                    <td>{e.title}</td>
                    <td className="muted">{e.who}</td>
                    <td>
                      <Badge tone={e.tone}>{e.status}</Badge>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}
      </section>
      <section className="card" aria-labelledby="metrics-heading">
        <h2 id="metrics-heading" style={{ marginBottom: 4 }}>
          Success metrics
        </h2>
        <p className="muted small" style={{ marginBottom: 12 }}>
          Where OurPawPass stands against the twelve month targets in the product plan.
        </p>
        {Object.keys(metrics).length === 0 ? (
          <p className="muted small">The metrics could not be loaded.</p>
        ) : (
          <ul className="list" style={{ listStyle: "none", padding: 0, margin: 0 }}>
            {METRIC_ORDER.map(({ key, label, detail }) => {
              const m = metrics[key];
              if (!m) return null;
              const d = describeMetric(m);
              const pctDone = progress(m);
              return (
                <li key={key} className="item">
                  <div className="row between">
                    <span>
                      <b>{label}</b>
                      <span className="meta">{detail}</span>
                    </span>
                    <span style={{ textAlign: "right" }}>
                      <b style={{ fontFamily: "var(--heading)", fontSize: 20 }}>{d.headline}</b>
                      <span className="meta">{d.note}</span>
                    </span>
                  </div>
                  <div
                    role="progressbar"
                    aria-label={`${label}: ${pctDone}% of target`}
                    aria-valuenow={pctDone}
                    aria-valuemin={0}
                    aria-valuemax={100}
                    style={{
                      height: 6,
                      borderRadius: 3,
                      background: "var(--border)",
                      marginTop: 8,
                    }}
                  >
                    <div
                      style={{
                        width: `${pctDone}%`,
                        height: "100%",
                        borderRadius: 3,
                        background: "var(--primary)",
                      }}
                    />
                  </div>
                </li>
              );
            })}
          </ul>
        )}
      </section>
    </>
  );
}

function AttentionRow({
  href,
  value,
  title,
  note,
}: {
  href: string;
  value: string;
  title: string;
  note: string;
}) {
  return (
    <li>
      <Link href={href} className="item" style={{ display: "flex", gap: 14, alignItems: "center" }}>
        <span
          style={{
            fontFamily: "var(--heading)",
            fontWeight: 700,
            fontSize: 24,
            minWidth: 44,
            color: "var(--warm-text)",
          }}
        >
          {value}
        </span>
        <span style={{ flex: 1 }}>
          <b>{title}</b>
          <span className="meta">{note}</span>
        </span>
        <span aria-hidden="true" className="muted">
          ›
        </span>
      </Link>
    </li>
  );
}
