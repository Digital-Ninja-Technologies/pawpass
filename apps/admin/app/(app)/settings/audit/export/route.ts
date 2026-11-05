import { NextResponse } from "next/server";
import { createClient } from "@/lib/supabase/server";
import { canDo, isRole } from "@/lib/roles";
import { describeAudit, resolveAuditNames } from "@/lib/audit";
import { toCsv } from "@/lib/csv";
import type { AuditRow, MeRow } from "@/lib/types";

export const dynamic = "force-dynamic";

export async function GET() {
  const supabase = await createClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();
  if (!user) return new NextResponse("Sign in first", { status: 401 });
  const { data: me } = await supabase.from("admin_me_v").select("*").maybeSingle<MeRow>();
  if (!me || me.status !== "active" || !isRole(me.role) || !canDo(me.role, "manage_team")) {
    return new NextResponse("Not allowed", { status: 403 });
  }
  const { data } = await supabase
    .from("admin_audit_v")
    .select("*")
    .order("at", { ascending: false })
    .limit(20000);
  const rows = (data ?? []) as AuditRow[];
  const names = await resolveAuditNames(supabase, rows);
  const csv = toCsv(
    ["When", "Who", "Action", "Target type", "Target id"],
    rows.map((r) => [r.at, r.staff_name, describeAudit(r, names), r.target_type, r.target_id]),
  );
  return new NextResponse(csv, {
    headers: {
      "content-type": "text/csv; charset=utf-8",
      "content-disposition": `attachment; filename="pawpass-audit-${new Date().toISOString().slice(0, 10)}.csv"`,
      "cache-control": "no-store",
    },
  });
}
