import { describe, expect, it } from "vitest";
import { scamSignals } from "./reports";
import type { ReportRow } from "./types";

const base: ReportRow = {
  target_type: "listing",
  target_id: "l1",
  report_count: 4,
  first_reported_at: "2026-11-05T09:00:00Z",
  top_reason: "Possible scam",
  is_open: true,
  last_status: "open",
  action: null,
  summary: "Rottweiler puppies",
  seller_name: "Prince Kennels",
  seller_status: "draft",
  seller_age_days: 1,
  price_kobo: 12_000_000,
  avg_price_kobo: 34_000_000,
};

describe("scamSignals", () => {
  it("flags a cheap listing from a new, unverified seller", () => {
    const s = scamSignals(base);
    expect(s).toContain("Price 65% below average");
    expect(s).toContain("Seller is unverified");
    expect(s.some((x) => x.includes("1 days old"))).toBe(true);
  });
  it("flags payment outside escrow in the text", () => {
    const s = scamSignals({
      ...base,
      summary: "pay deposit by transfer to reserve",
      price_kobo: null,
    });
    expect(s).toContain("Mentions payment outside escrow");
  });
  it("is quiet for a normal listing from an old verified seller", () => {
    expect(
      scamSignals({
        ...base,
        seller_status: "approved",
        seller_age_days: 400,
        price_kobo: 33_000_000,
        top_reason: "Wrong breed",
      }),
    ).toEqual([]);
  });
  it("only applies to listings", () => {
    expect(scamSignals({ ...base, target_type: "post" })).toEqual([]);
  });
});
