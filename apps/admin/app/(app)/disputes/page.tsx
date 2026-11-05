import type { Metadata } from "next";
import Link from "next/link";
import { requireSection } from "@/lib/auth";
import { canDo } from "@/lib/roles";
import { formatDate, formatKobo, formatDateTime, sentence } from "@/lib/format";
import { Badge, DisabledAction, Empty, PageHeader, Tabs, href, type Tone } from "@/components/ui";
import type { DisputeRow, EscrowRow, SettingsRow } from "@/lib/types";
import { DecisionPanel } from "./DecisionPanel";

export const metadata: Metadata = { title: "Disputes" };

function due(d: DisputeRow): { label: string; tone: Tone } {
  if (d.status === "decided") return { label: "Decided", tone: "good" };
  if (!d.due_at) return { label: "Open", tone: "neutral" };
  const hours = (new Date(d.due_at).getTime() - Date.now()) / 3_600_000;
  if (hours < 0) return { label: "Overdue", tone: "bad" };
  if (hours < 24) return { label: "Due today", tone: "bad" };
  return { label: `${Math.ceil(hours / 24)} days left`, tone: hours < 72 ? "warn" : "neutral" };
}

export default async function DisputesPage({
  searchParams,
}: {
  searchParams: Promise<{ show?: string; id?: string }>;
}) {
  const { supabase, staff } = await requireSection("disputes");
  const sp = await searchParams;
  const show = sp.show === "decided" ? "decided" : "open";

  const base = supabase.from("admin_dispute_v").select("*");
  const [{ data }, open, decided, settings] = await Promise.all([
    (show === "open"
      ? base.neq("status", "decided").order("due_at", { ascending: true })
      : base.eq("status", "decided").order("decided_at", { ascending: false })
    ).limit(100),
    supabase
      .from("admin_dispute_v")
      .select("*", { count: "exact", head: true })
      .neq("status", "decided"),
    supabase
      .from("admin_dispute_v")
      .select("*", { count: "exact", head: true })
      .eq("status", "decided"),
    supabase.from("settings").select("*").maybeSingle<SettingsRow>(),
  ]);
  const list = (data ?? []) as DisputeRow[];
  const selected = list.find((d) => d.id === sp.id) ?? list[0] ?? null;
  const escrow = selected
    ? (
        await supabase
          .from("admin_escrow_v")
          .select("*")
          .eq("id", selected.escrow_id)
          .maybeSingle<EscrowRow>()
      ).data
    : null;

  const heldTotal = list
    .filter((d) => d.status !== "decided")
    .reduce((sum, d) => sum + Number(d.amount_kobo), 0);
  const isPuppy = selected?.escrow_kind.startsWith("puppy");
  const canDecide =
    canDo(staff.role, "decide_dispute") && selected && selected.status !== "decided";

  return (
    <>
      <PageHeader
        title="Escrow disputes"
        subtitle={`${open.count ?? 0} open · ${formatKobo(heldTotal)} held · respond within 72 hours`}
      />
      <Tabs
        label="Show"
        items={[
          {
            label: "Open",
            count: open.count ?? 0,
            active: show === "open",
            href: href("/disputes", {}),
          },
          {
            label: "Decided",
            count: decided.count ?? 0,
            active: show === "decided",
            href: href("/disputes", { show: "decided" }),
          },
        ]}
      />
      {list.length === 0 ? (
        <div className="card">
          <Empty>{show === "open" ? "No open disputes. Nice." : "No decided disputes yet."}</Empty>
        </div>
      ) : (
        <div className="grid split">
          <div className="list" aria-label="Disputes">
            {list.map((d) => {
              const t = due(d);
              return (
                <Link
                  key={d.id}
                  href={href("/disputes", { show: show === "open" ? undefined : show, id: d.id })}
                  className="item"
                  aria-current={d.id === selected?.id ? "true" : undefined}
                >
                  <span className="row between">
                    <span className="tiny muted">
                      {d.ref} · {sentence(d.escrow_kind.replace("puppy_", "puppy sale "))}
                    </span>
                    <Badge tone={t.tone}>{t.label}</Badge>
                  </span>
                  <b>{d.reason}</b>
                  <span className="meta">
                    {d.buyer_name ?? "Buyer"} vs {d.partner_name ?? "Partner"} ·{" "}
                    {formatKobo(d.amount_kobo)}
                  </span>
                </Link>
              );
            })}
          </div>

          {selected ? (
            <div className="card stack" style={{ gap: 20 }}>
              <div className="row between">
                <div>
                  <h2>
                    {selected.ref} · {selected.subject}
                  </h2>
                  <p className="muted small">
                    Buyer {selected.buyer_name ?? "unknown"} · {selected.partner_name ?? "Partner"}
                    {selected.partner_verified ? " (verified)" : ""} ·{" "}
                    {formatKobo(selected.amount_kobo)}{" "}
                    {selected.escrow_status === "paused"
                      ? "held"
                      : selected.escrow_status.replace(/_/g, " ")}
                  </p>
                </div>
                {selected.escrow_status === "paused" ? (
                  <Badge tone="warn">Partner payout paused</Badge>
                ) : null}
              </div>

              <section className="stack" aria-label="Claims">
                <div>
                  <div className="overline">Buyer&apos;s claim</div>
                  <div className="quote">{selected.details || selected.reason}</div>
                </div>
                <div>
                  <div className="overline">Partner&apos;s reply</div>
                  {selected.partner_response ? (
                    <div className="quote">{selected.partner_response}</div>
                  ) : (
                    <p className="muted small">No reply yet.</p>
                  )}
                </div>
              </section>

              <section aria-label="Timeline">
                <div className="overline" style={{ marginBottom: 8 }}>
                  Timeline
                </div>
                <ul className="timeline">
                  {escrow ? (
                    <li>
                      <time>{formatDate(escrow.created_at)}</time>
                      <span>
                        {sentence(escrow.kind.replace(/_/g, " "))} {formatKobo(escrow.amount_kobo)}{" "}
                        paid and held
                      </span>
                    </li>
                  ) : null}
                  <li>
                    <time>{formatDate(selected.created_at)}</time>
                    <span>Buyer opened the dispute</span>
                  </li>
                  {selected.decided_at ? (
                    <li>
                      <time>{formatDate(selected.decided_at)}</time>
                      <span>
                        Decided: {selected.decision?.replace(/_/g, " ")}
                        {selected.decision === "split"
                          ? ` (${formatKobo(selected.decision_refund_kobo)} refunded)`
                          : ""}
                      </span>
                    </li>
                  ) : null}
                </ul>
              </section>

              {isPuppy && settings.data ? (
                <div className="notice ok" style={{ fontWeight: 500 }}>
                  <b>Policy:</b> a vet-verified health problem found within{" "}
                  {settings.data.vet_check_hours} hours of handover qualifies for a full refund.
                </div>
              ) : null}

              {canDecide ? (
                <DecisionPanel
                  key={selected.id}
                  disputeId={selected.id}
                  amountLabel={formatKobo(selected.amount_kobo)}
                  partnerName={selected.partner_name ?? "partner"}
                />
              ) : selected.status === "decided" ? (
                <div className="notice ok">
                  Decided {formatDateTime(selected.decided_at)}:{" "}
                  {selected.decision?.replace(/_/g, " ")}.{" "}
                  {selected.decision_note ? `Note: ${selected.decision_note}` : ""}
                </div>
              ) : (
                <p className="muted small">Your role can view disputes but not decide them.</p>
              )}
              <div className="row">
                <DisabledAction reason="Needs in-app messaging, which comes with the chat milestone">
                  Message both parties
                </DisabledAction>
              </div>
            </div>
          ) : null}
        </div>
      )}
    </>
  );
}
