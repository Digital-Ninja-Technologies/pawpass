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
  note: string | null;
  attempts: number;
  partner: { business_name: string } | null;
}

const ITEM_TONE: Record<string, "good" | "warn" | "bad" | "neutral"> = {
  sent: "good",
  sending: "warn",
  pending: "neutral",
  held: "warn",
  failed: "bad",
};
const ITEM_LABEL: Record<string, string> = {
  sent: "Sent",
  sending: "Sending",
  pending: "Will be sent",
  held: "Held",
  failed: "Failed",
};

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
        .select("id, amount_kobo, status, note, attempts, partner:partner_accounts(business_name)")
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
  const toSend = list
    .filter((i) => i.status !== "held")
    .reduce((s, i) => s + Number(i.amount_kobo), 0);
  const held = list.filter((i) => i.status === "held");
  const failed = list.filter((i) => i.status === "failed");

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
          value={formatKobo(toSend)}
          note={`${list.length - held.length} partner${list.length - held.length === 1 ? "" : "s"}, after fees`}
        />
        <Stat
          label="Held: no payout account"
          value={formatKobo(held.reduce((s, i) => s + Number(i.amount_kobo), 0))}
          note={`${held.length} partner${held.length === 1 ? "" : "s"}. Paid once they add an account`}
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
      {run && run.status === "approved" ? (
        <Notice tone="ok">
          This run is approved. The payout function sends it on {formatDate(run.run_on)}
          {new Date(run.run_on) > new Date() ? "" : " (today or earlier, so it is being sent now)"}.
          The money is released from escrow when each transfer is started, so a late dispute cannot
          touch it.
        </Notice>
      ) : null}
      {run && run.status === "sent" ? (
        <Notice tone="ok">This run was sent. Partners were told their payout is on its way.</Notice>
      ) : null}
      {run && (run.status === "failed" || failed.length > 0) ? (
        <Notice tone="err">
          {failed.length} transfer{failed.length === 1 ? "" : "s"} failed after retries. The money
          has already left escrow, so check the reason below and the Paystack balance, then pay it
          by hand from the Paystack dashboard.
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
                  <th>Note</th>
                </tr>
              </thead>
              <tbody>
                {list.map((i) => (
                  <tr key={i.id}>
                    <td>{i.partner?.business_name ?? "Partner"}</td>
                    <td className="num">{formatKobo(i.amount_kobo)}</td>
                    <td>
                      <Badge tone={ITEM_TONE[i.status] ?? "neutral"}>
                        {ITEM_LABEL[i.status] ?? i.status}
                      </Badge>
                    </td>
                    <td className="small muted">
                      {i.note ?? (i.attempts > 1 ? `Attempt ${i.attempts}` : "")}
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
