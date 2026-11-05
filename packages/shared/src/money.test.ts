import { describe, expect, it } from "vitest";
import { formatNaira } from "./money";

describe("formatNaira", () => {
  it("formats with thousands separators", () => {
    expect(formatNaira(15000)).toBe("₦15,000");
  });
  it("rounds to whole naira", () => {
    expect(formatNaira(999.6)).toBe("₦1,000");
  });
});
