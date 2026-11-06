import { describe, expect, it } from "vitest";
import { PRIVACY, TERMS } from "./legal";
import { safeEmail } from "./contact";

describe("legal copy", () => {
  const text = JSON.stringify({ PRIVACY, TERMS });
  it("follows the copy rules", () => {
    expect(text).not.toContain("—");
    expect(text).not.toMatch(/\b\d+-(hour|digit|km)\b/);
    expect(text).not.toContain("$");
  });
  it("states the key business rules", () => {
    expect(text).toContain("72 hours");
    expect(text).toContain("2 hours");
    expect(text).toContain("14 days");
  });
  it("validates the contact email", () => {
    expect(safeEmail("help@pawpass.ng")).toBe("help@pawpass.ng");
    expect(safeEmail("not an email")).toBe("");
  });
});
