import { describe, expect, it } from "vitest";
import { applyAuditFilter, auditActionFilter, auditSince, parseAuditFilter } from "./audit-filter";

describe("parseAuditFilter", () => {
  it("defaults to everything on page 1", () => {
    expect(parseAuditFilter({})).toEqual({ area: "all", range: "all", who: "", page: 1 });
  });
  it("accepts known values", () => {
    expect(parseAuditFilter({ area: "disputes", range: "7", who: "Bisi", page: "3" })).toEqual({
      area: "disputes",
      range: "7",
      who: "Bisi",
      page: 3,
    });
  });
  it("ignores unknown areas and ranges, and bad pages", () => {
    const f = parseAuditFilter({ area: "x", range: "999", page: "-4" });
    expect(f).toMatchObject({ area: "all", range: "all", page: 1 });
    expect(parseAuditFilter({ page: "abc" }).page).toBe(1);
  });
  it("strips anything in a name that could change the query", () => {
    expect(parseAuditFilter({ who: "a,b(c)*d%e" }).who).toBe("abcde");
    expect(parseAuditFilter({ who: "x".repeat(200) }).who).toHaveLength(60);
    expect(parseAuditFilter({ who: "Adé O'Neil-Smith" }).who).toBe("Adé O'Neil-Smith");
  });
});

describe("filters", () => {
  const now = new Date("2026-11-06T12:00:00Z");
  it("computes the start of the range", () => {
    expect(auditSince("all", now)).toBeNull();
    expect(auditSince("7", now)).toBe("2026-10-30T12:00:00.000Z");
    expect(auditSince("30", now)).toBe("2026-10-07T12:00:00.000Z");
  });
  it("turns an area into action prefixes", () => {
    expect(auditActionFilter("all")).toBeNull();
    expect(auditActionFilter("disputes")).toBe("action.like.dispute.*");
    expect(auditActionFilter("support")).toBe(
      "action.like.ticket.*,action.like.qr_order.*,action.like.lost_alert.*",
    );
  });
  it("applies every part to a query", () => {
    const calls: string[] = [];
    const q = {
      gte: (c: string, v: string) => (calls.push(`gte ${c} ${v}`), q),
      ilike: (c: string, p: string) => (calls.push(`ilike ${c} ${p}`), q),
      or: (f: string) => (calls.push(`or ${f}`), q),
    };
    applyAuditFilter(q, { area: "payouts", range: "7", who: "Tunde", page: 1 }, now);
    expect(calls).toEqual([
      "gte at 2026-10-30T12:00:00.000Z",
      "or action.like.payout_run.*",
      "ilike staff_name %Tunde%",
    ]);
  });
});
