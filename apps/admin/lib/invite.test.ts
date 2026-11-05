import { createHash } from "node:crypto";
import { describe, expect, it } from "vitest";
import { emailAllowed, hashToken, INVITE_HOURS } from "./invite";
import { safeNext } from "./safe-next";

describe("invites", () => {
  it("hashes tokens the same way the database does (sha256 hex)", () => {
    expect(hashToken("secret-token")).toBe(
      createHash("sha256").update("secret-token").digest("hex"),
    );
    expect(hashToken("secret-token")).toHaveLength(64);
  });
  it("expires after 48 hours", () => expect(INVITE_HOURS).toBe(48));
  it("restricts email domains only when one is set", () => {
    expect(emailAllowed("anyone@gmail.com", undefined)).toBe(true);
    expect(emailAllowed("bisi@pawpass.ng", "pawpass.ng")).toBe(true);
    expect(emailAllowed("BISI@PawPass.ng", "@pawpass.ng")).toBe(true);
    expect(emailAllowed("bisi@evil-pawpass.ng", "pawpass.ng")).toBe(false);
    expect(emailAllowed("bisi@pawpass.ng.evil.com", "pawpass.ng")).toBe(false);
  });
});

describe("safeNext", () => {
  it("keeps paths inside the app", () => {
    expect(safeNext("/disputes?id=1")).toBe("/disputes?id=1");
    expect(safeNext("")).toBe("/");
    expect(safeNext(null)).toBe("/");
  });
  it("blocks open redirects", () => {
    for (const bad of ["https://evil.com", "//evil.com", "/\\evil.com", "javascript:alert(1)"])
      expect(safeNext(bad)).toBe("/");
  });
});
