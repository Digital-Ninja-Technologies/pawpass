import type { Metadata } from "next";
import { requireSection } from "@/lib/auth";
import { canDo } from "@/lib/roles";
import { timeAgo } from "@/lib/format";
import { Badge, DisabledAction, Empty, PageHeader, Stat } from "@/components/ui";
import type { LostRow, QrRow, SettingsRow } from "@/lib/types";
import { OrderButton, WidenButton } from "./Buttons";

export const metadata: Metadata = { title: "Lost & found" };

export default async function LostFoundPage() {
  const { supabase, staff } = await requireSection("lost");
  const now = Date.now();
  const day = 86_400_000;
  const since30 = new Date(now - 30 * day).toISOString();
  const today = new Date(now - day).toISOString();
  const threeDays = new Date(now - 3 * day).toISOString();
  const head = (t: string) => supabase.from(t).select("*", { count: "exact", head: true });

  const [alerts, activeCount, openedToday, found30, total30, tags, toShip, late, orders, settings] =
    await Promise.all([
      supabase
        .from("admin_lost_v")
        .select("*")
        .eq("status", "active")
        .order("created_at", { ascending: false })
        .limit(50),
      head("admin_lost_v").eq("status", "active"),
      head("admin_lost_v").eq("status", "active").gte("created_at", today),
      head("admin_lost_v").eq("status", "found").gte("created_at", since30),
      head("admin_lost_v").gte("created_at", since30),
      head("pets").not("tag_code", "is", null),
      head("admin_qr_v").eq("status", "paid"),
      head("admin_qr_v").eq("status", "paid").lt("created_at", threeDays),
      supabase
        .from("admin_qr_v")
        .select("*")
        .in("status", ["paid", "shipped"])
        .order("created_at", { ascending: true })
        .limit(30),
      supabase.from("settings").select("*").maybeSingle<SettingsRow>(),
    ]);
  const rows = (alerts.data ?? []) as LostRow[];
  const qr = (orders.data ?? []) as QrRow[];
  const reunited =
    (total30.count ?? 0) > 0 ? Math.round(((found30.count ?? 0) / (total30.count ?? 1)) * 100) : 0;
  const canAct = canDo(staff.role, "lost_alerts");

  return (
    <>
      <PageHeader title="Lost & found" subtitle="Active alerts, sightings and QR collar tags" />
      <section className="grid stats" aria-label="Summary">
        <Stat
          label="Active alerts"
          value={activeCount.count ?? 0}
          note={`${openedToday.count ?? 0} opened today`}
        />
        <Stat
          label="Found · last 30 days"
          value={`${found30.count ?? 0} of ${total30.count ?? 0}`}
          note={`${reunited}% reunited`}
        />
        <Stat label="QR tags active" value={(tags.count ?? 0).toLocaleString("en-NG")} />
        <Stat
          label="Tag orders to ship"
          value={toShip.count ?? 0}
          note={`${late.count ?? 0} past the 3 day target`}
        />
      </section>

      <section className="card" aria-label="Active alerts">
        <h2 style={{ marginBottom: 8 }}>Active alerts</h2>
        {rows.length === 0 ? (
          <Empty>No active lost pet alerts.</Empty>
        ) : (
          <div className="table-wrap">
            <table>
              <thead>
                <tr>
                  <th>Pet</th>
                  <th>Area</th>
                  <th>Open</th>
                  <th className="num">Sightings</th>
                  <th>Radius</th>
                  <th>Flag</th>
                  <th>
                    <span className="sr-only">Actions</span>
                  </th>
                </tr>
              </thead>
              <tbody>
                {rows.map((r) => {
                  const nextRadius = Math.min(50_000, r.radius_m * 2);
                  return (
                    <tr key={r.id}>
                      <td>
                        <b>{r.pet_name}</b>
                        <span className="muted"> · {r.breed ?? r.species}</span>
                      </td>
                      <td className="muted">{r.owner_area ?? "Unknown"}</td>
                      <td className="muted">{timeAgo(r.created_at)}</td>
                      <td className="num">{r.sightings}</td>
                      <td className="muted">{r.radius_m / 1000} km</td>
                      <td>
                        {r.flag ? (
                          <Badge tone="bad">{r.flag}</Badge>
                        ) : r.days_left !== null && r.days_left < 6 ? (
                          <Badge tone="warn">
                            Auto-close in {Math.max(0, Math.ceil(r.days_left))} days
                          </Badge>
                        ) : (
                          <span className="muted">None</span>
                        )}
                      </td>
                      <td>
                        <span className="row">
                          {canAct && r.radius_m < 50_000 ? (
                            <WidenButton alertId={r.id} radius={nextRadius} />
                          ) : null}
                          <DisabledAction reason="Needs in-app messaging, which comes with the chat milestone">
                            Contact owner
                          </DisabledAction>
                        </span>
                      </td>
                    </tr>
                  );
                })}
              </tbody>
            </table>
          </div>
        )}
        <p className="tiny muted" style={{ marginTop: 8 }}>
          Alerts auto-close after {settings.data?.lost_autoclose_days ?? 14} days. Owner phone
          numbers are never shown here.
        </p>
      </section>

      <section className="card" aria-label="QR tag orders">
        <h2 style={{ marginBottom: 8 }}>QR tag orders</h2>
        {qr.length === 0 ? (
          <Empty>No tag orders waiting.</Empty>
        ) : (
          <div className="table-wrap">
            <table>
              <thead>
                <tr>
                  <th>Order</th>
                  <th>Owner · pet · area</th>
                  <th>Waiting</th>
                  <th>Status</th>
                  <th>
                    <span className="sr-only">Actions</span>
                  </th>
                </tr>
              </thead>
              <tbody>
                {qr.map((o) => (
                  <tr key={o.id}>
                    <td>
                      <b>#{o.ref}</b>
                    </td>
                    <td className="muted">
                      {o.owner_name} · {o.pet_name}
                      {o.area ? ` · ${o.area}` : ""}
                    </td>
                    <td className="muted">{timeAgo(o.created_at)}</td>
                    <td>
                      <Badge
                        tone={
                          o.status === "paid" &&
                          Date.now() - new Date(o.created_at).getTime() > 3 * day
                            ? "bad"
                            : "neutral"
                        }
                      >
                        {o.status === "paid" ? "To ship" : "Shipped"}
                      </Badge>
                    </td>
                    <td>
                      {canAct ? (
                        <OrderButton
                          orderId={o.id}
                          next={o.status === "paid" ? "shipped" : "delivered"}
                        />
                      ) : null}
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
