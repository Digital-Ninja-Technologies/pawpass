import type { Metadata } from "next";
import Link from "next/link";
import { requireSection } from "@/lib/auth";
import { canDo } from "@/lib/roles";
import { describeTimeLeft, formatDateTime, hoursLeft, hoursSince } from "@/lib/format";
import { DOC_LABELS, documentProgress, PARTNER_TYPE_LABELS, type DocKind } from "@/lib/kyc";
import { Badge, Empty, PageHeader, Tabs, href } from "@/components/ui";
import type { KycRow, PartnerDocRow, SettingsRow } from "@/lib/types";
import { ReviewPanel } from "./ReviewPanel";

export const metadata: Metadata = { title: "Verifications" };

const STATUS_TABS = [
  { key: "pending", label: "Pending", db: "submitted" },
  { key: "needs_info", label: "Needs info", db: "needs_info" },
  { key: "approved", label: "Approved", db: "approved" },
  { key: "rejected", label: "Rejected", db: "rejected" },
] as const;
const TYPES = ["all", "vet", "breeder", "service", "shelter"] as const;
const TYPE_LABELS: Record<string, string> = {
  all: "All types",
  vet: "Vets",
  breeder: "Breeders",
  service: "Services",
  shelter: "Shelters",
};

export default async function VerificationsPage({
  searchParams,
}: {
  searchParams: Promise<{ status?: string; type?: string; id?: string }>;
}) {
  const { supabase, staff } = await requireSection("verifications");
  const sp = await searchParams;
  const tab = STATUS_TABS.find((t) => t.key === sp.status) ?? STATUS_TABS[0];
  const type = (TYPES as readonly string[]).includes(sp.type ?? "") ? sp.type! : "all";

  let query = supabase.from("admin_kyc_v").select("*").eq("status", tab.db);
  if (type !== "all") query = query.eq("type", type);
  query =
    tab.db === "submitted" || tab.db === "needs_info"
      ? query.order("submitted_at", { ascending: true })
      : query.order("decided_at", { ascending: false });

  const counts = await Promise.all(
    STATUS_TABS.map((t) =>
      supabase.from("admin_kyc_v").select("*", { count: "exact", head: true }).eq("status", t.db),
    ),
  );
  const [{ data: rows }, settings] = await Promise.all([
    query.limit(100),
    supabase.from("settings").select("*").maybeSingle<SettingsRow>(),
  ]);
  const list = (rows ?? []) as KycRow[];
  const target = settings.data?.kyc_target_hours ?? 48;

  const selected = list.find((r) => r.id === sp.id) ?? list[0] ?? null;

  const { data: docRows } = list.length
    ? await supabase
        .from("partner_documents")
        .select("*")
        .in(
          "partner_account_id",
          list.map((l) => l.id),
        )
    : { data: [] as PartnerDocRow[] };
  const docs = (docRows ?? []) as PartnerDocRow[];
  const kindsFor = (id: string) =>
    docs.filter((d) => d.partner_account_id === id).map((d) => d.kind);
  const canSeeDocs =
    docs.length > 0 || staff.role === "verifications" || staff.role === "full_admin";

  const selectedDocs = selected ? docs.filter((d) => d.partner_account_id === selected.id) : [];
  const signed = await Promise.all(
    selectedDocs.map(async (d) => {
      const { data } = await supabase.storage
        .from("partner-documents")
        .createSignedUrl(d.storage_path, 300);
      return { doc: d, url: data?.signedUrl ?? null };
    }),
  );

  const canReview =
    canDo(staff.role, "review_partner") &&
    selected &&
    (selected.status === "submitted" || selected.status === "needs_info");
  const baseParams = { status: tab.key, type: type === "all" ? undefined : type };

  return (
    <>
      <PageHeader
        title="Partner verifications"
        subtitle={`Target: decide within ${target} hours of submission`}
      />
      <Tabs
        label="Status"
        items={STATUS_TABS.map((t, i) => ({
          label: t.label,
          count: counts[i]?.count ?? 0,
          active: t.key === tab.key,
          href: href("/verifications", { status: t.key, type: type === "all" ? undefined : type }),
        }))}
      />
      <Tabs
        label="Partner type"
        items={TYPES.map((t) => ({
          label: TYPE_LABELS[t]!,
          active: t === type,
          href: href("/verifications", { status: tab.key, type: t === "all" ? undefined : t }),
        }))}
      />

      {list.length === 0 ? (
        <div className="card">
          <Empty>
            No applications here. Partners appear when they submit their documents in the app.
          </Empty>
        </div>
      ) : (
        <div className="grid split">
          <div className="list" aria-label="Applications">
            {list.map((r) => {
              const p = documentProgress(r.type, kindsFor(r.id));
              const waiting = r.status === "submitted" || r.status === "needs_info";
              const hrs = Math.round(hoursSince(r.submitted_at));
              const late = waiting && hoursLeft(r.submitted_at, target) < 0;
              return (
                <Link
                  key={r.id}
                  href={href("/verifications", { ...baseParams, id: r.id })}
                  className="item"
                  aria-current={r.id === selected?.id ? "true" : undefined}
                >
                  <span className="row between">
                    <b>{r.business_name}</b>
                    {waiting ? (
                      <Badge tone={late ? "bad" : hrs > target * 0.6 ? "warn" : "neutral"}>
                        {hrs} hrs
                      </Badge>
                    ) : null}
                  </span>
                  <span className="meta">
                    {PARTNER_TYPE_LABELS[r.type] ?? r.type}
                    {r.area ? ` · ${r.area}` : ""}
                    {canSeeDocs ? ` · ${p.have} of ${p.need} documents` : ""}
                  </span>
                </Link>
              );
            })}
          </div>

          {selected ? (
            <div className="card stack" style={{ gap: 20 }}>
              <div className="row between">
                <div>
                  <h2>{selected.business_name}</h2>
                  <p className="muted small">
                    {PARTNER_TYPE_LABELS[selected.type] ?? selected.type} ·{" "}
                    {selected.area ?? "Area not given"} · owner {selected.owner_name || "unknown"}
                    {selected.submitted_at
                      ? ` · submitted ${formatDateTime(selected.submitted_at)}`
                      : ""}
                  </p>
                </div>
                {selected.status === "submitted" || selected.status === "needs_info" ? (
                  <Badge tone={hoursLeft(selected.submitted_at, target) < 0 ? "bad" : "warn"}>
                    {describeTimeLeft(hoursLeft(selected.submitted_at, target))}
                  </Badge>
                ) : (
                  <Badge
                    tone={
                      selected.status === "approved"
                        ? "good"
                        : selected.status === "rejected"
                          ? "bad"
                          : "neutral"
                    }
                  >
                    {selected.status === "approved"
                      ? "Approved"
                      : selected.status === "rejected"
                        ? "Rejected"
                        : selected.status}
                  </Badge>
                )}
              </div>

              <section aria-label="Documents">
                <div className="overline" style={{ marginBottom: 8 }}>
                  Documents
                </div>
                {!canSeeDocs ? (
                  <p className="muted small">
                    Document files are visible to the Verifications team only.
                  </p>
                ) : signed.length === 0 ? (
                  <p className="muted small">No documents uploaded yet.</p>
                ) : (
                  <ul className="list" style={{ listStyle: "none", padding: 0, margin: 0 }}>
                    {signed.map(({ doc, url }) => {
                      const meta = DOC_LABELS[doc.kind as DocKind];
                      return (
                        <li key={doc.id} className="item row between">
                          <span>
                            <b>{meta?.label ?? doc.kind}</b>
                            <span className="meta">{meta?.group}</span>
                          </span>
                          <span className="row">
                            <Badge
                              tone={
                                doc.status === "approved"
                                  ? "good"
                                  : doc.status === "rejected"
                                    ? "bad"
                                    : "neutral"
                              }
                            >
                              {doc.status}
                            </Badge>
                            {url ? (
                              <a
                                className="btn secondary small"
                                href={url}
                                target="_blank"
                                rel="noopener noreferrer"
                              >
                                View
                                <span className="sr-only"> {meta?.label}, opens in a new tab</span>
                              </a>
                            ) : (
                              <span className="muted small">Unavailable</span>
                            )}
                          </span>
                        </li>
                      );
                    })}
                  </ul>
                )}
                {selected.status === "submitted" || selected.status === "needs_info"
                  ? (() => {
                      const p = documentProgress(
                        selected.type,
                        selectedDocs.map((d) => d.kind),
                      );
                      return canSeeDocs && p.missing.length ? (
                        <p className="small" style={{ marginTop: 8, color: "var(--warm-text)" }}>
                          Missing: {p.missing.map((k) => DOC_LABELS[k].label).join(", ")}
                        </p>
                      ) : null;
                    })()
                  : null}
                <p className="tiny muted" style={{ marginTop: 8 }}>
                  Links to files expire after 5 minutes.
                </p>
              </section>

              {canReview ? (
                <ReviewPanel
                  key={selected.id + selected.status}
                  partnerId={selected.id}
                  checks={selected.kyc_checks ?? {}}
                  internalNote={selected.internal_note ?? ""}
                  decisionNote={selected.decision_note ?? ""}
                />
              ) : (
                <div className="stack">
                  {selected.decision_note ? (
                    <div className="quote">{selected.decision_note}</div>
                  ) : null}
                  {selected.internal_note ? (
                    <div className="notice info">
                      <b>Internal note:</b> {selected.internal_note}
                    </div>
                  ) : null}
                  {selected.decided_at ? (
                    <p className="muted small">Decided {formatDateTime(selected.decided_at)}</p>
                  ) : null}
                  {!canDo(staff.role, "review_partner") ? (
                    <p className="muted small">
                      Your role can view applications but not decide them.
                    </p>
                  ) : null}
                </div>
              )}
            </div>
          ) : null}
        </div>
      )}
    </>
  );
}
