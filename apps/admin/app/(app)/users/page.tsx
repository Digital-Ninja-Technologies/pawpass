import type { Metadata } from "next";
import Link from "next/link";
import { requireSection } from "@/lib/auth";
import { canDo } from "@/lib/roles";
import { formatDate, formatKobo, initials, sentence } from "@/lib/format";
import { Badge, DisabledAction, Empty, PageHeader, Tabs, href, type Tone } from "@/components/ui";
import type { DirectoryRow } from "@/lib/types";
import { SuspendForm } from "./SuspendForm";

export const metadata: Metadata = { title: "Users & partners" };

const FILTERS = [
  ["everyone", "Everyone"],
  ["owner", "Owners"],
  ["provider", "Providers"],
  ["breeder", "Breeders"],
  ["shelter", "Shelters"],
  ["suspended", "Suspended"],
] as const;

function statusBadge(r: DirectoryRow): { label: string; tone: Tone } {
  if (r.status === "suspended") return { label: "Suspended", tone: "bad" };
  if (r.status === "approved") return { label: "✓ Verified", tone: "good" };
  if (r.status === "submitted" || r.status === "needs_info")
    return { label: "Verification pending", tone: "warn" };
  if (r.status === "rejected") return { label: "Rejected", tone: "bad" };
  if (r.status === "draft") return { label: "Not submitted", tone: "neutral" };
  return { label: "Active", tone: "neutral" };
}

function typeLabel(r: DirectoryRow): string {
  if (r.kind === "owner") return `Owner · ${r.pets} ${r.pets === 1 ? "pet" : "pets"}`;
  if (r.type === "vet") return "Provider · vet";
  if (r.type === "service") return "Provider · services";
  return sentence(r.type);
}

export default async function UsersPage({
  searchParams,
}: {
  searchParams: Promise<{ kind?: string; q?: string; id?: string }>;
}) {
  const { supabase, staff } = await requireSection("users");
  const sp = await searchParams;
  const kind = FILTERS.some(([k]) => k === sp.kind) ? sp.kind! : "everyone";
  const q = (sp.q ?? "")
    .replace(/[%_\\,()]/g, " ")
    .trim()
    .slice(0, 60);

  let query = supabase
    .from("admin_directory_v")
    .select("*")
    .order("joined_at", { ascending: false })
    .limit(50);
  if (kind === "owner") query = query.eq("kind", "owner");
  else if (kind === "provider") query = query.eq("kind", "partner").in("type", ["vet", "service"]);
  else if (kind === "breeder" || kind === "shelter")
    query = query.eq("kind", "partner").eq("type", kind);
  else if (kind === "suspended") query = query.eq("status", "suspended");
  if (q) query = query.ilike("name", `%${q}%`);

  const [{ data }, owners, partners] = await Promise.all([
    query,
    supabase
      .from("admin_directory_v")
      .select("*", { count: "exact", head: true })
      .eq("kind", "owner"),
    supabase
      .from("admin_directory_v")
      .select("*", { count: "exact", head: true })
      .eq("kind", "partner")
      .eq("status", "approved"),
  ]);
  const rows = (data ?? []) as DirectoryRow[];
  const selected = rows.find((r) => r.id === sp.id) ?? null;

  // Reading an email address is personal data access, so the database logs it.
  let email: string | null = null;
  if (selected && ["full_admin", "support_reports", "verifications"].includes(staff.role)) {
    const res = await supabase.rpc("admin_user_email", { p_user: selected.user_id });
    email = (res.data as string | null) ?? null;
  }

  const params = (extra: Record<string, string | undefined>) => ({
    kind: kind === "everyone" ? undefined : kind,
    q: q || undefined,
    ...extra,
  });

  return (
    <>
      <PageHeader
        title="Users & partners"
        subtitle={`${(owners.count ?? 0).toLocaleString("en-NG")} owners · ${(partners.count ?? 0).toLocaleString("en-NG")} verified partners`}
      />
      <form method="get" role="search" className="row" style={{ alignItems: "flex-end" }}>
        {kind !== "everyone" ? <input type="hidden" name="kind" value={kind} /> : null}
        <label className="field" style={{ flex: "1 1 280px" }}>
          Search users
          <input
            className="input"
            type="search"
            name="q"
            defaultValue={q}
            placeholder="Search by name"
          />
        </label>
        <button type="submit" className="btn secondary">
          Search
        </button>
      </form>
      <Tabs
        label="Filter"
        items={FILTERS.map(([k, label]) => ({
          label,
          active: k === kind,
          href: href("/users", { kind: k === "everyone" ? undefined : k, q: q || undefined }),
        }))}
      />

      <div
        className={selected ? "grid split" : "grid"}
        style={
          selected ? { gridTemplateColumns: "minmax(0, 1.5fr) minmax(280px, 1fr)" } : undefined
        }
      >
        <section className="card" aria-label="Results">
          {rows.length === 0 ? (
            <Empty>No one matches. Try a different filter or name.</Empty>
          ) : (
            <div className="table-wrap">
              <table>
                <thead>
                  <tr>
                    <th>Name</th>
                    <th>Type</th>
                    <th>Area</th>
                    <th>Joined</th>
                    <th>Status</th>
                  </tr>
                </thead>
                <tbody>
                  {rows.map((r) => {
                    const b = statusBadge(r);
                    return (
                      <tr key={r.kind + r.id} aria-selected={r.id === selected?.id}>
                        <td>
                          <Link
                            href={href("/users", params({ id: r.id }))}
                            style={{ fontWeight: 700 }}
                          >
                            {r.name || "No name yet"}
                          </Link>
                        </td>
                        <td className="muted">{typeLabel(r)}</td>
                        <td className="muted">{r.area ?? "Unknown"}</td>
                        <td className="muted">{formatDate(r.joined_at)}</td>
                        <td>
                          <Badge tone={b.tone}>{b.label}</Badge>
                        </td>
                      </tr>
                    );
                  })}
                </tbody>
              </table>
            </div>
          )}
        </section>

        {selected ? (
          <aside className="card stack" aria-label="Details">
            <div className="row">
              <span
                className="avatar"
                style={{ width: 52, height: 52, borderRadius: 26, fontSize: 18 }}
                aria-hidden="true"
              >
                {initials(selected.name)}
              </span>
              <div>
                <h2 style={{ fontSize: 20 }}>{selected.name || "No name yet"}</h2>
                <p className="muted small">
                  {email ??
                    (selected.kind === "owner"
                      ? "Email hidden for your role"
                      : typeLabel(selected))}
                </p>
              </div>
            </div>
            {selected.kind === "owner" ? (
              <div
                className="grid"
                style={{ gridTemplateColumns: "repeat(3, 1fr)", gap: 8, textAlign: "center" }}
              >
                <div className="item">
                  <b>{selected.pets}</b>
                  <span className="meta">Pets</span>
                </div>
                <div className="item">
                  <b>{selected.bookings}</b>
                  <span className="meta">Bookings</span>
                </div>
                <div className="item">
                  <b>{formatKobo(selected.in_escrow_kobo)}</b>
                  <span className="meta">In escrow</span>
                </div>
              </div>
            ) : (
              <p className="small">
                {typeLabel(selected)} · {sentence(selected.status.replace(/_/g, " "))}
              </p>
            )}
            <p className="small muted">
              {selected.area ? `Area ${selected.area}. ` : ""}Joined{" "}
              {formatDate(selected.joined_at)}.
            </p>
            {selected.status === "suspended" && selected.suspension_reason ? (
              <div className="notice err">Suspended: {selected.suspension_reason}</div>
            ) : null}
            {selected.kind === "partner" &&
            ["submitted", "needs_info"].includes(selected.status) ? (
              <Link
                className="btn secondary"
                href={href("/verifications", {
                  id: selected.id,
                  status: selected.status === "needs_info" ? "needs_info" : undefined,
                })}
              >
                Open verification
              </Link>
            ) : null}
            {email ? (
              <p className="tiny muted">Viewing an email address is recorded in the audit log.</p>
            ) : null}
            <div className="row">
              <DisabledAction reason="Needs in-app messaging, which comes with the chat milestone">
                Message user
              </DisabledAction>
              <DisabledAction reason="Sign-in codes are sent by the app backend, not built yet">
                Send new sign-in code
              </DisabledAction>
            </div>
            {canDo(staff.role, "suspend_user") ? (
              <SuspendForm
                key={selected.id + selected.status}
                userId={selected.user_id}
                suspended={selected.status === "suspended"}
              />
            ) : null}
          </aside>
        ) : null}
      </div>
    </>
  );
}
