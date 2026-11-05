import type { ReportRow } from "./types";

/** Plain language warning signs for a reported listing. Shown first so reviewers see scams early. */
export function scamSignals(r: ReportRow): string[] {
  const out: string[] = [];
  if (r.target_type !== "listing") return out;
  if (r.price_kobo && r.avg_price_kobo && r.avg_price_kobo > 0) {
    const below = Math.round((1 - r.price_kobo / r.avg_price_kobo) * 100);
    if (below >= 30) out.push(`Price ${below}% below average`);
  }
  if (r.seller_status && r.seller_status !== "approved")
    out.push(`Seller is ${r.seller_status === "suspended" ? "suspended" : "unverified"}`);
  if (r.seller_age_days !== null && r.seller_age_days < 7)
    out.push(
      `Seller account is ${r.seller_age_days === 0 ? "less than a day" : `${r.seller_age_days} days`} old`,
    );
  if (/transfer|outside|cash only|whatsapp|dm me/i.test(`${r.summary ?? ""} ${r.top_reason}`))
    out.push("Mentions payment outside escrow");
  return out;
}
