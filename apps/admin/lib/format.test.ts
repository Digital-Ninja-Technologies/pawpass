import { describe, expect, it } from "vitest";
import {
  describeTimeLeft,
  formatKobo,
  formatKoboShort,
  hoursLeft,
  initials,
  nextWeekday,
  parseNairaToKobo,
  timeAgo,
  toIsoDate,
} from "./format";

describe("money", () => {
  it("formats kobo as naira", () => {
    expect(formatKobo(1500000)).toBe("₦15,000");
    expect(formatKobo(null)).toBe("₦0");
    expect(formatKobo("38000000")).toBe("₦380,000");
  });
  it("shortens big numbers for tiles", () => {
    expect(formatKoboShort(4_680_000_000)).toBe("₦46.8M");
    expect(formatKoboShort(79_000_000)).toBe("₦790k");
    expect(formatKoboShort(48_750_000)).toBe("₦487.5k");
    expect(formatKoboShort(1_500_000)).toBe("₦15,000");
  });
  it("parses typed naira amounts", () => {
    expect(parseNairaToKobo("380,000")).toBe(38_000_000);
    expect(parseNairaToKobo("₦1,250.50")).toBe(125_050);
    expect(parseNairaToKobo("190000")).toBe(19_000_000);
  });
  it("rejects bad amounts", () => {
    for (const bad of ["", "abc", "-5", "1.234", "1e5"]) expect(parseNairaToKobo(bad)).toBeNull();
  });
});

describe("time", () => {
  const now = new Date("2026-11-05T12:00:00Z");
  it("says how long ago", () => {
    expect(timeAgo("2026-11-05T11:20:00Z", now)).toBe("40 min");
    expect(timeAgo("2026-11-05T07:00:00Z", now)).toBe("5 hrs");
    expect(timeAgo("2026-11-02T12:00:00Z", now)).toBe("3 days");
    expect(timeAgo("2026-11-05T12:00:00Z", now)).toBe("just now");
  });
  it("counts the 48 hour verification clock", () => {
    expect(hoursLeft("2026-11-04T19:00:00Z", 48, now)).toBe(31);
    expect(describeTimeLeft(17)).toBe("17 hrs left on target");
    expect(hoursLeft("2026-11-02T12:00:00Z", 48, now)).toBe(-24);
    expect(describeTimeLeft(-24)).toBe("24 hrs past target");
  });
  it("finds the next payout day, today included", () => {
    // 5 Nov 2026 is a Thursday. Next Monday is 9 Nov.
    expect(toIsoDate(nextWeekday(1, now))).toBe("2026-11-09");
    expect(toIsoDate(nextWeekday(4, now))).toBe("2026-11-05");
    expect(toIsoDate(nextWeekday(3, now))).toBe("2026-11-11");
  });
  it("makes initials", () => {
    expect(initials("Bisi Ajayi")).toBe("BA");
    expect(initials("Tunde")).toBe("T");
    expect(initials("")).toBe("?");
  });
});
