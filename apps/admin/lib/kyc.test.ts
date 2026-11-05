import { describe, expect, it } from "vitest";
import { documentProgress } from "./kyc";

describe("documentProgress", () => {
  it("counts required documents by partner type", () => {
    expect(
      documentProgress("breeder", [
        "owner_id",
        "cac",
        "facility_photo",
        "vet_reference",
        "payout_account",
      ]),
    ).toEqual({ have: 5, need: 5, missing: [] });
    expect(
      documentProgress("shelter", ["owner_id", "cac", "facility_photo", "payout_account"]).need,
    ).toBe(4);
  });
  it("lists what is missing", () => {
    const p = documentProgress("vet", ["owner_id", "licence"]);
    expect(p.have).toBe(2);
    expect(p.missing).toEqual(["facility_photo", "vet_reference", "payout_account"]);
  });
  it("ignores documents that are not required", () => {
    expect(documentProgress("shelter", ["licence", "owner_id"]).have).toBe(1);
  });
  it("falls back to the services list for unknown types", () => {
    expect(documentProgress("mystery", []).need).toBe(4);
  });
});
