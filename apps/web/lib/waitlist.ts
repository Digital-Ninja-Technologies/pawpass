"use server";

import { createClient } from "@supabase/supabase-js";
import { isValidEmail, normaliseEmail } from "./email";

export interface WaitlistState {
  ok: boolean;
  message: string;
}

const SOURCES = new Set(["hero", "footer", "partners"]);

/** Adds an email to the waitlist. Duplicates count as success so the form never reveals who has signed up. */
export async function joinWaitlist(
  _prev: WaitlistState | null,
  form: FormData,
): Promise<WaitlistState> {
  // Hidden field that people never see. Bots fill it in; we pretend it worked.
  if (String(form.get("company") ?? "") !== "")
    return { ok: true, message: "Thank you. You are on the list." };

  const email = normaliseEmail(String(form.get("email") ?? ""));
  if (!isValidEmail(email))
    return { ok: false, message: "Please enter a valid email address, like name@example.com." };

  const url = process.env.NEXT_PUBLIC_SUPABASE_URL;
  const key = process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY;
  if (!url || !key)
    return { ok: false, message: "Sign up is not available right now. Please try again soon." };

  const source = String(form.get("source") ?? "");
  const supabase = createClient(url, key, { auth: { persistSession: false } });
  // No .select(): visitors may insert but never read the list.
  const { error } = await supabase
    .from("waitlist_signups")
    .insert({ email, source: SOURCES.has(source) ? source : "hero" });

  if (error && error.code !== "23505") {
    return {
      ok: false,
      message: "Something went wrong on our side. Please try again in a minute.",
    };
  }
  return {
    ok: true,
    message: "Thank you. You are on the list, and we will email you when PawPass opens in Lagos.",
  };
}
