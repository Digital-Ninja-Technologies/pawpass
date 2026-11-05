"use server";

import { randomBytes } from "node:crypto";
import { headers } from "next/headers";
import { redirect } from "next/navigation";
import { requireAction } from "../auth";
import { createClient } from "../supabase/server";
import { isRole } from "../roles";
import { friendly, text } from "./helpers";
import { emailAllowed, hashToken, INVITE_HOURS } from "../invite";

export interface InviteState {
  ok: boolean;
  message: string;
  link?: string;
}
export interface AcceptState {
  ok: boolean;
  message: string;
}

export async function createInvite(
  _prev: InviteState | null,
  form: FormData,
): Promise<InviteState> {
  const ctx = await requireAction("manage_team");
  if ("error" in ctx) return { ok: false, message: ctx.error };

  const email = text(form, "email").toLowerCase();
  const role = text(form, "role");
  if (!isRole(role)) return { ok: false, message: "Choose a role." };
  if (!emailAllowed(email))
    return {
      ok: false,
      message: `Only @${process.env.STAFF_EMAIL_DOMAIN} addresses can be invited.`,
    };

  const token = randomBytes(32).toString("base64url");
  const expires = new Date(Date.now() + INVITE_HOURS * 3_600_000);
  const { error } = await ctx.supabase.rpc("admin_create_staff_invite", {
    p_email: email,
    p_role: role,
    p_note: text(form, "note"),
    p_token_hash: hashToken(token),
    p_expires_at: expires.toISOString(),
  });
  if (error) return { ok: false, message: friendly(error.message) };

  const h = await headers();
  const host = h.get("x-forwarded-host") ?? h.get("host") ?? "localhost:3000";
  const proto = h.get("x-forwarded-proto") ?? (host.startsWith("localhost") ? "http" : "https");
  return {
    ok: true,
    link: `${proto}://${host}/invite/${token}`,
    message: `Invite created for ${email}. Send them this link. It works once and expires in ${INVITE_HOURS} hours.`,
  };
}

export async function acceptInvite(
  _prev: AcceptState | null,
  form: FormData,
): Promise<AcceptState> {
  const token = text(form, "token");
  const mode = text(form, "mode") === "existing" ? "existing" : "new";
  const password = String(form.get("password") ?? "");
  const name = text(form, "name");

  const supabase = await createClient();
  // The email comes from the invite itself, never from the form.
  const { data: preview } = await supabase.rpc("staff_invite_preview", { p_token: token });
  const invite = Array.isArray(preview) ? preview[0] : null;
  if (!invite)
    return { ok: false, message: "This invite is not valid any more. Ask for a new one." };

  if (form.get("ack") !== "on")
    return { ok: false, message: "Please confirm the confidentiality statement." };

  if (mode === "new") {
    if (name.length < 2) return { ok: false, message: "Enter your name." };
    if (password.length < 12)
      return { ok: false, message: "Use at least 12 characters for your password." };
    const [first, ...rest] = name.split(/\s+/);
    const { data, error } = await supabase.auth.signUp({
      email: invite.email,
      password,
      options: { data: { first_name: first, last_name: rest.join(" ") } },
    });
    if (error) {
      if (/already/i.test(error.message))
        return {
          ok: false,
          message: "An account already exists for this email. Choose “I already have an account”.",
        };
      return { ok: false, message: error.message };
    }
    if (data.user && data.user.identities && data.user.identities.length === 0) {
      return {
        ok: false,
        message: "An account already exists for this email. Choose “I already have an account”.",
      };
    }
    if (!data.session) {
      return {
        ok: true,
        message:
          "Check your email and confirm your address, then open this invite link again and choose “I already have an account”.",
      };
    }
  } else {
    const { error } = await supabase.auth.signInWithPassword({ email: invite.email, password });
    if (error) return { ok: false, message: "That password did not match." };
  }

  const { error } = await supabase.rpc("accept_staff_invite", { p_token: token });
  if (error) {
    await supabase.auth.signOut();
    return { ok: false, message: friendly(error.message) };
  }
  redirect("/");
}
