import type { Metadata } from "next";
import { requireSection } from "@/lib/auth";
import { canDo } from "@/lib/roles";
import { formatDate, formatKobo, nextWeekday, toIsoDate, WEEKDAYS } from "@/lib/format";
import { Badge, Empty, Notice, PageHeader, Stat } from "@/components/ui";
import type { SettingsRow } from "@/lib/types";
import { ApproveForm, PrepareForm } from "./RunActions";
import Link from "next/link";

export const metadata: Metadata = { title: "Payout run" };

interface Item {
  id: string;
  amount_kobo: number;
  status: string;
  partner: { business_name: string } | null;
}

export default async function PayoutRunPage() {
  const { supabase, staff } = await requireSection("payouts");
  const { data: settings } = await supabase.from("settings").select("*").maybeSingle<SettingsRow>();
  const day = settings?.payout_weekday ?? 1;
  const runOn = toIsoDate(nextWeekday(day));

  const { data: run } = await supabase
    .from("payout_runs")
    .select("*")
    .eq("run_on", runOn)
    .maybeSingle();
  const { data: items } = run
    ? await supabase
        .from("payout_items")
        .select("id, amount_kobo, status, partner:partner_accounts(business_name)")
        .eq("payout_run_id", run.id)
        .order("amount_kobo", { ascending: false })
    : { data: [] };
  const list = (items ?? []) as unknown as Item[];
  const { data: paused } = await supabase
    .from("admin_escrow_v")
    .select("amount_kobo")
    .eq("status", "paused");
  const pausedTotal = (paused ?? []).reduce((s, r) => s + Number(r.amount_kobo), 0);
  const canRun = canDo(staff.role, "prepare_payout");

  return (
    <>
      <PageHeader
        crumbs={
          <>
            <Link href="/payouts">Escrow &amp; payouts</Link> › Payout run
          </>
        }
        title={`${WEEKDAYS[day - 1]}'s payout run`}
        subtitle={`Run date ${formatDate(runOn)}. Review the list, then approve it. Disputed money is never included.`}
        actions={
          run ? (
            <Badge tone={run.status === "draft" ? "warn" : "good"}>{run.status}</Badge>
          ) : (
            <Badge>Not prepared</Badge>
          )
        }
      />
      <section className="grid stats">
        <Stat
          label="Total to pay"
          value={formatKobo(run?.total_kobo ?? 0)}
          note={`${list.length} partners, after fees`}
        />
        <Stat
          label="Left out: paused by disputes"
          value={formatKobo(pausedTotal)}
          note="Paid after the dispute is decided"
        />
      </section>

      {canRun && (!run || run.status === "draft") ? (
        <section className="card stack">
          <h2>{run ? "Draft payout run" : "Prepare the run"}</h2>
          <p className="muted small">
            This collects every transaction that is ready, net of fees, per partner. You can refresh
            it until you approve.
          </p>
          <PrepareForm runOn={runOn} hasDraft={Boolean(run)} />
          {run && list.length ? (
            <ApproveForm runId={run.id} total={formatKobo(run.total_kobo)} />
          ) : null}
        </section>
      ) : null}
      {run && run.status !== "draft" ? (
        <Notice tone="ok">
          This run is {run.status}. Transfers are sent by the scheduled payout function (not built
          yet), so nothing has been paid out.
        </Notice>
      ) : null}

      <section className="card">
        <h2 style={{ marginBottom: 8 }}>Partners in this run</h2>
        {list.length === 0 ? (
          <Empty>
            {run
              ? "Nothing was ready at the time of preparing."
              : "Prepare the run to see who gets paid."}
          </Empty>
        ) : (
          <div className="table-wrap">
            <table>
              <thead>
                <tr>
                  <th>Partner</th>
                  <th className="num">Amount</th>
                  <th>Status</th>
                </tr>
              </thead>
              <tbody>
                {list.map((i) => (
                  <tr key={i.id}>
                    <td>{i.partner?.business_name ?? "Partner"}</td>
                    <td className="num">{formatKobo(i.amount_kobo)}</td>
                    <td>
                      <Badge>{i.status}</Badge>
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
