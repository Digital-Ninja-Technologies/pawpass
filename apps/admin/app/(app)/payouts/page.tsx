import type { Metadata } from "next";
import Link from "next/link";
import { requireSection } from "@/lib/auth";
import {
  formatDate,
  formatKobo,
  formatKoboShort,
  nextWeekday,
  toIsoDate,
  WEEKDAYS,
} from "@/lib/format";
import { Badge, Empty, PageHeader, Stat, Tabs, href } from "@/components/ui";
import type { EscrowRow, SettingsRow } from "@/lib/types";
import { statusTone } from "@/lib/escrow";

export const metadata: Metadata = { title: "Escrow & payouts" };

const FILTERS = ["all", "held", "ready", "paused", "released", "refunded"] as const;

export default async function PayoutsPage({
  searchParams,
}: {
  searchParams: Promise<{ status?: string }>;
}) {
  const { supabase } = await requireSection("payouts");
  const sp = await searchParams;
  const status = (FILTERS as readonly string[]).includes(sp.status ?? "") ? sp.status! : "all";

  const monthStart = new Date();
  monthStart.setUTCDate(1);
  monthStart.setUTCHours(0, 0, 0, 0);

  let list = supabase
    .from("admin_escrow_v")
    .select("*")
    .order("created_at", { ascending: false })
    .limit(100);
  if (status === "refunded") list = list.in("status", ["refunded", "partially_refunded"]);
  else if (status !== "all") list = list.eq("status", status);

  const [{ data }, overview, settings, fees] = await Promise.all([
    list,
    supabase.rpc("admin_overview", { p_days: 30 }),
    supabase.from("settings").select("*").maybeSingle<SettingsRow>(),
    supabase
      .from("admin_escrow_v")
      .select("fee_kobo,status")
      .gte("created_at", monthStart.toISOString())
      .neq("status", "refunded")
      .limit(5000),
  ]);
  const rows = (data ?? []) as EscrowRow[];
  const o = (overview.data ?? {}) as Record<string, number>;
  const feeTotal = (fees.data ?? []).reduce((sum, r) => sum + Number(r.fee_kobo), 0);
  const nextRun = nextWeekday(settings.data?.payout_weekday ?? 1);
  const runDay = WEEKDAYS[(settings.data?.payout_weekday ?? 1) - 1];
  const monthName = new Intl.DateTimeFormat("en-NG", { month: "short", timeZone: "UTC" }).format(
    monthStart,
  );

  return (
    <>
      <PageHeader
        title="Escrow & payouts"
        subtitle={`Funds are held until the owner confirms the service or the ${settings.data?.vet_check_hours ?? 72} hour check ends`}
        actions={
          <>
            <a
              className="btn secondary"
              href={href("/payouts/export", { status: status === "all" ? undefined : status })}
            >
              Export CSV
            </a>
            <Link className="btn primary" href="/payouts/run">
              Review {runDay}&apos;s payout run
            </Link>
          </>
        }
      />
      <section className="grid stats" aria-label="Money summary">
        <Stat
          label="Held in escrow"
          value={formatKoboShort(o.held_kobo)}
          note={`${o.held_count ?? 0} transactions`}
        />
        <Stat
          label={`Ready for ${runDay}`}
          value={formatKoboShort(o.ready_kobo)}
          note={`${o.ready_partners ?? 0} partners`}
        />
        <Stat
          label="Paused by disputes"
          value={formatKoboShort(o.paused_kobo)}
          note={`${o.paused_count ?? 0} open cases`}
        />
        <Stat
          label={`Platform fees · ${monthName}`}
          value={formatKoboShort(feeTotal)}
          note="Commission + escrow fees"
        />
      </section>
      <Tabs
        label="Status"
        items={FILTERS.map((f) => ({
          label: f[0]!.toUpperCase() + f.slice(1),
          active: f === status,
          href: href("/payouts", { status: f === "all" ? undefined : f }),
        }))}
      />
      <section className="card">
        {rows.length === 0 ? (
          <Empty>No transactions here yet.</Empty>
        ) : (
          <div className="table-wrap">
            <table>
              <thead>
                <tr>
                  <th>ID</th>
                  <th>What</th>
                  <th>Owner → Partner</th>
                  <th className="num">Amount</th>
                  <th>Status</th>
                  <th>Releases</th>
                </tr>
              </thead>
              <tbody>
                {rows.map((r) => (
                  <tr key={r.id}>
                    <td className="muted">{r.ref}</td>
                    <td>{r.subject}</td>
                    <td className="muted">
                      {r.payer_name ?? "Customer"} → {r.payee_name ?? "Partner"}
                    </td>
                    <td className="num">{formatKobo(r.amount_kobo)}</td>
                    <td>
                      <Badge tone={statusTone(r.status)}>{r.status.replace(/_/g, " ")}</Badge>
                      {r.open_dispute_id ? <span className="tiny muted"> · dispute</span> : null}
                    </td>
                    <td className="muted">
                      {r.status === "ready"
                        ? formatDate(toIsoDate(nextRun))
                        : r.status === "paused"
                          ? "On decision"
                          : r.status === "held"
                            ? r.release_after
                              ? formatDate(r.release_after)
                              : "On confirmation"
                            : formatDate(r.created_at)}
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}
      </section>
    </>
  );
}
