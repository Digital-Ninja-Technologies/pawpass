import { describe, expect, it } from "vitest";
import { describeMetric, METRIC_ORDER, parseMetrics, progress } from "./metrics";

describe("progress", () => {
  it("compares a count with its target", () => {
    expect(progress({ value: 5000, target: 20000 })).toBe(25);
    expect(progress({ value: 30000, target: 20000 })).toBe(100);
    expect(progress({ value: 0, target: 300 })).toBe(0);
  });
  it("compares a rate with its wanted percentage", () => {
    expect(progress({ value: 17, of: 40, pct: 42.5, target_pct: 60 })).toBe(71);
    expect(progress({ value: 1, of: 2, pct: 50, target_pct: 35 })).toBe(100);
  });
  it("is zero when there is no target", () => {
    expect(progress({ value: 3 })).toBe(0);
    expect(progress({ value: 3, target: 0 })).toBe(0);
  });
});

describe("describeMetric", () => {
  it("writes counts with separators", () => {
    expect(describeMetric({ value: 1240, target: 20000 })).toEqual({
      headline: "1,240",
      note: "Target 20,000",
    });
  });
  it("writes rates with what they are out of", () => {
    expect(describeMetric({ value: 17, of: 40, pct: 42.5, target_pct: 60 })).toEqual({
      headline: "42.5%",
      note: "Target 60% · 17 of 40",
    });
  });
});

describe("parseMetrics", () => {
  it("keeps what is there and ignores the rest", () => {
    const m = parseMetrics({
      pets_with_record: { value: 4, target: 20000 },
      junk: 1,
      lost_found_rate: "no",
    });
    expect(Object.keys(m)).toEqual(["pets_with_record"]);
  });
  it("copes with nothing", () => {
    expect(parseMetrics(null)).toEqual({});
    expect(parseMetrics("x")).toEqual({});
  });
  it("lists every metric the database sends", () => {
    expect(METRIC_ORDER.map((m) => m.key)).toHaveLength(7);
  });
});
