import { describe, expect, it } from "vitest";
import { safeAgencyUrl } from "./site";

describe("safeAgencyUrl", () => {
  it("accepts web addresses", () => {
    expect(safeAgencyUrl("https://example.com")).toBe("https://example.com/");
    expect(safeAgencyUrl("http://example.com/about")).toBe("http://example.com/about");
  });
  it("rejects anything that is not http or https", () => {
    for (const bad of [
      "",
      "example.com",
      "javascript:alert(1)",
      "data:text/html,hi",
      "mailto:a@b.co",
      "ftp://x.com",
    ]) {
      expect(safeAgencyUrl(bad)).toBe("");
    }
  });
});
