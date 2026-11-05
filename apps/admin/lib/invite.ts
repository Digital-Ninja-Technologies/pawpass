import { createHash } from "node:crypto";

export const INVITE_HOURS = 48;
export const hashToken = (token: string) => createHash("sha256").update(token).digest("hex");

/** Optional: only these email domains can be invited (set STAFF_EMAIL_DOMAIN, e.g. pawpass.ng). */
export function emailAllowed(email: string, domain = process.env.STAFF_EMAIL_DOMAIN): boolean {
  if (!domain) return true;
  return email.toLowerCase().endsWith(`@${domain.replace(/^@/, "").toLowerCase()}`);
}
