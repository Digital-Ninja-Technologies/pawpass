import { NextResponse } from "next/server";
import { createClient } from "@/lib/supabase/server";
import { canView, isRole } from "@/lib/roles";
import { toCsv } from "@/lib/csv";
import type { EscrowRow, MeRow } from "@/lib/types";

export const dynamic = "force-dynamic";

export async function GET(request: Request) {
  const supabase = await createClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();
  if (!user) return new NextResponse("Sign in first", { status: 401 });
  const { data: me } = await supabase.from("admin_me_v").select("*").maybeSingle<MeRow>();
  if (!me || me.status !== "active" || !isRole(me.role) || !canView(me.role, "payouts")) {
    return new NextResponse("Not allowed", { status: 403 });
  }

  const status = new URL(request.url).searchParams.get("status");
  let q = supabase
    .from("admin_escrow_v")
    .select("*")
    .order("created_at", { ascending: false })
    .limit(10000);
  if (status === "refunded") q = q.in("status", ["refunded", "partially_refunded"]);
  else if (status && ["held", "ready", "paused", "released"].includes(status))
    q = q.eq("status", status);
  const { data } = await q;

  const rows = ((data ?? []) as EscrowRow[]).map((r) => [
    r.ref,
    r.created_at,
    r.subject,
    r.payer_name,
    r.payee_name,
    r.amount_kobo / 100,
    r.fee_kobo / 100,
    r.status,
  ]);
  const csv = toCsv(
    ["ID", "Created", "What", "Owner", "Partner", "Amount (NGN)", "Fee (NGN)", "Status"],
    rows,
  );
  return new NextResponse(csv, {
    headers: {
      "content-type": "text/csv; charset=utf-8",
      "content-disposition": `attachment; filename="pawpass-escrow-${new Date().toISOString().slice(0, 10)}.csv"`,
      "cache-control": "no-store",
    },
  });
}
