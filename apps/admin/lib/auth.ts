import { redirect } from "next/navigation";
import type { SupabaseClient, User } from "@supabase/supabase-js";
import { createClient } from "./supabase/server";
import { canDo, canView, isRole, type Action, type Role, type Section } from "./roles";
import type { MeRow } from "./types";

export interface Staff {
  supabase: SupabaseClient;
  user: User;
  staff: { id: string; role: Role; name: string };
}

/** Returns the signed in, active staff member or sends them to /login. */
export async function requireStaff(): Promise<Staff> {
  const supabase = await createClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();
  if (!user) redirect("/login");

  const { data } = await supabase.from("admin_me_v").select("*").maybeSingle<MeRow>();
  if (!data || data.status !== "active" || !isRole(data.role)) redirect("/login?error=no-access");

  return {
    supabase,
    user,
    staff: { id: data.id, role: data.role, name: data.name?.trim() || user.email || "Staff" },
  };
}

/** For pages: staff who may open this section, otherwise back to the overview. */
export async function requireSection(section: Section): Promise<Staff> {
  const ctx = await requireStaff();
  if (!canView(ctx.staff.role, section)) redirect("/?denied=1");
  return ctx;
}

/** For server actions: staff who may perform this action. The database checks again. */
export async function requireAction(action: Action): Promise<Staff | { error: string }> {
  const supabase = await createClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();
  if (!user) return { error: "Your session has ended. Sign in again." };
  const { data } = await supabase.from("admin_me_v").select("*").maybeSingle<MeRow>();
  if (!data || data.status !== "active" || !isRole(data.role))
    return { error: "You do not have admin access." };
  if (!canDo(data.role, action)) return { error: "Your role cannot do this." };
  return { supabase, user, staff: { id: data.id, role: data.role, name: data.name ?? "" } };
}
