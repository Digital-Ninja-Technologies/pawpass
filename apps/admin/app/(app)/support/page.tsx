import type { Metadata } from "next";
import Link from "next/link";
import { requireSection } from "@/lib/auth";
import { canDo } from "@/lib/roles";
import { formatDateTime, timeAgo } from "@/lib/format";
import { Badge, Empty, PageHeader, Tabs, href } from "@/components/ui";
import type { SupportMessageRow, SupportRow } from "@/lib/types";
import { ReplyBox } from "./ReplyBox";

export const metadata: Metadata = { title: "Support" };

const TABS = [
  ["open", "Open"],
  ["waiting_user", "Waiting on user"],
  ["closed", "Closed"],
] as const;

export default async function SupportPage({
  searchParams,
}: {
  searchParams: Promise<{ status?: string; id?: string }>;
}) {
  const { supabase, staff } = await requireSection("support");
  const sp = await searchParams;
  const status = TABS.some(([k]) => k === sp.status) ? sp.status! : "open";

  const [{ data }, ...counts] = await Promise.all([
    supabase
      .from("admin_support_v")
      .select("*")
      .eq("status", status)
      .order("created_at", { ascending: status === "open" })
      .limit(100),
    ...TABS.map(([k]) =>
      supabase.from("admin_support_v").select("*", { count: "exact", head: true }).eq("status", k),
    ),
  ]);
  const list = (data ?? []) as SupportRow[];
  const selected = list.find((t) => t.id === sp.id) ?? list[0] ?? null;
  const thread = selected
    ? (((
        await supabase
          .from("support_messages")
          .select("*")
          .eq("ticket_id", selected.id)
          .order("created_at", { ascending: true })
      ).data ?? []) as SupportMessageRow[])
    : [];
  const canReply = canDo(staff.role, "support_reply");

  return (
    <>
      <PageHeader
        title="Support inbox"
        subtitle="From Help & support in the app · reply within 1 day"
      />
      <Tabs
        label="Status"
        items={TABS.map(([k, label], i) => ({
          label,
          count: counts[i]?.count ?? 0,
          active: k === status,
          href: href("/support", { status: k === "open" ? undefined : k }),
        }))}
      />
      {list.length === 0 ? (
        <div className="card">
          <Empty>No tickets here.</Empty>
        </div>
      ) : (
        <div className="grid split">
          <div className="list" aria-label="Tickets">
            {list.map((t) => (
              <Link
                key={t.id}
                href={href("/support", {
                  status: status === "open" ? undefined : status,
                  id: t.id,
                })}
                className="item"
                aria-current={t.id === selected?.id ? "true" : undefined}
              >
                <span className="row between">
                  <span className="tiny muted">
                    #{t.ref} · {t.topic}
                  </span>
                  <span className="tiny muted">{timeAgo(t.created_at)}</span>
                </span>
                <b>{t.subject}</b>
                <span className="meta">
                  {t.user_name || "User"}
                  {t.last_reply_is_staff ? " · replied, waiting" : ""}
                </span>
              </Link>
            ))}
          </div>
          {selected ? (
            <div className="card stack" style={{ gap: 20 }}>
              <div className="row between">
                <div>
                  <h2>{selected.subject}</h2>
                  <p className="muted small">
                    {selected.user_name || "User"} · #{selected.ref} · {selected.topic}
                  </p>
                </div>
                {selected.linked_type ? (
                  <Badge tone="warn">Linked: {selected.linked_type.replace(/_/g, " ")}</Badge>
                ) : null}
              </div>
              <ol
                className="stack"
                style={{ listStyle: "none", margin: 0, padding: 0 }}
                aria-label="Conversation"
              >
                {selected.first_message && thread.length === 0 ? (
                  <li className="quote">{selected.first_message}</li>
                ) : null}
                {thread.map((m) => (
                  <li
                    key={m.id}
                    className="quote"
                    style={
                      m.internal
                        ? { background: "var(--warm-soft)", borderColor: "var(--warm)" }
                        : m.author_staff_id
                          ? { background: "var(--primary-soft)", borderColor: "var(--primary)" }
                          : undefined
                    }
                  >
                    <div className="tiny muted" style={{ marginBottom: 4 }}>
                      {m.internal
                        ? "Internal note"
                        : m.author_staff_id
                          ? "PawPass team"
                          : selected.user_name || "User"}{" "}
                      · {formatDateTime(m.created_at)}
                    </div>
                    {m.body}
                  </li>
                ))}
              </ol>
              {canReply ? (
                <ReplyBox
                  key={selected.id + selected.status}
                  ticketId={selected.id}
                  closed={selected.status === "closed"}
                />
              ) : (
                <p className="muted small">Your role can read the inbox but not reply.</p>
              )}
            </div>
          ) : null}
        </div>
      )}
    </>
  );
}
