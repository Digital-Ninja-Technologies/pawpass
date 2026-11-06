import { describe, expect, it } from "vitest";
import { documentProgress, MIN_FACILITY_PHOTOS } from "./kyc";

describe("documentProgress", () => {
  it("counts required documents by partner type", () => {
    expect(documentProgress("breeder", ["owner_id", "cac", "facility_photo"])).toEqual({
      have: 3,
      need: 3,
      missing: [],
    });
    expect(documentProgress("vet", ["owner_id", "cac", "licence", "facility_photo"]).need).toBe(4);
    expect(documentProgress("shelter", []).need).toBe(3);
  });
  it("only vets need a licence", () => {
    expect(documentProgress("vet", ["owner_id", "cac", "facility_photo"]).missing).toEqual([
      "licence",
    ]);
    expect(documentProgress("service", ["owner_id", "cac", "facility_photo"]).missing).toEqual([]);
  });
  it("lists what is missing", () => {
    const p = documentProgress("vet", ["owner_id", "licence"]);
    expect(p.have).toBe(2);
    expect(p.missing).toEqual(["cac", "facility_photo"]);
  });
  it("ignores documents that are not required", () => {
    expect(documentProgress("shelter", ["licence", "owner_id"]).have).toBe(1);
  });
  it("falls back to the services list for unknown types", () => {
    expect(documentProgress("mystery", []).need).toBe(3);
  });
  it("expects three facility photos", () => {
    expect(MIN_FACILITY_PHOTOS).toBe(3);
  });
});
