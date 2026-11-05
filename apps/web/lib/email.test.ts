import { describe, expect, it } from "vitest";
import { isValidEmail, normaliseEmail } from "./email";

describe("email", () => {
  it("accepts normal addresses", () => {
    for (const ok of ["tolu@example.com", "a.b+tag@mail.co.ng", " Tolu@Example.COM "])
      expect(isValidEmail(ok)).toBe(true);
  });
  it("rejects bad addresses", () => {
    for (const bad of [
      "",
      "tolu",
      "tolu@",
      "@example.com",
      "tolu@example",
      "to lu@example.com",
      "a@b@c.com",
    ]) {
      expect(isValidEmail(bad)).toBe(false);
    }
  });
  it("rejects addresses longer than 254 characters", () => {
    expect(isValidEmail("a".repeat(250) + "@b.co")).toBe(false);
  });
  it("trims and lowercases", () => {
    expect(normaliseEmail("  Tolu@Example.COM ")).toBe("tolu@example.com");
  });
});
