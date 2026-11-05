import { revalidatePath } from "next/cache";
import { cookies } from "next/headers";
import { requireAction, type Staff } from "../auth";
import type { Action } from "../roles";

export type ActionState = { ok: boolean; message: string } | null;

type RpcArgs = Record<string, string | number | boolean | object | null>;

/** Runs one audited admin_* database function as the signed in staff member. The database
 * re-checks the role, so this is a convenience for good error messages, not the security boundary. */
export async function runRpc(
  action: Action,
  fn: string,
  args: RpcArgs,
  opts: { paths: string[]; success: string },
): Promise<ActionState> {
  const ctx = await requireAction(action);
  if ("error" in ctx) return { ok: false, message: ctx.error };
  const { error } = await (ctx as Staff).supabase.rpc(fn, args);
  if (error) return { ok: false, message: friendly(error.message) };
  for (const p of opts.paths) revalidatePath(p);
  await flash(opts.success);
  return { ok: true, message: opts.success };
}

/** Database errors raised by our functions are already written for people; hide anything else. */
/** Shows a short message after the next render, even if the form that sent it has gone away. */
export async function flash(message: string): Promise<void> {
  (await cookies()).set("flash", encodeURIComponent(message), {
    maxAge: 30,
    path: "/",
    sameSite: "lax",
  });
}

export function friendly(message: string): string {
  if (/permission denied|row-level security/i.test(message)) return "Your role cannot do this.";
  if (/violates check constraint/i.test(message)) return "That value is outside the allowed range.";
  if (/invalid input syntax/i.test(message)) return "One of the values is not valid.";
  return message;
}

export const text = (form: FormData, key: string): string => String(form.get(key) ?? "").trim();
