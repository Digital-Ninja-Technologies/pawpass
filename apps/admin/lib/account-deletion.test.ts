import { describe, expect, it } from "vitest";
import { deletionErrorMessage, deletionFunctionUrl, emailMatches } from "./account-deletion";

describe("emailMatches", () => {
  it("matches the account email without caring about case or spaces at the ends", () => {
    expect(emailMatches("  Kemi@Example.com ", "kemi@example.com")).toBe(true);
  });
  it("rejects anything else, including an empty box or a missing email", () => {
    expect(emailMatches("", "kemi@example.com")).toBe(false);
    expect(emailMatches("kemi@example.co", "kemi@example.com")).toBe(false);
    expect(emailMatches("kemi@example.com", null)).toBe(false);
    expect(emailMatches("", null)).toBe(false);
  });
});

describe("deletionFunctionUrl", () => {
  it("adds the function path once", () => {
    expect(deletionFunctionUrl("https://abc.supabase.co")).toBe("https://abc.supabase.co/functions/v1/admin-delete-account");
    expect(deletionFunctionUrl("https://abc.supabase.co/")).toBe("https://abc.supabase.co/functions/v1/admin-delete-account");
  });
});

describe("deletionErrorMessage", () => {
  it("shows the function's own reason for refusals", () => {
    expect(deletionErrorMessage(409, { error: "You have a booking that is not finished." })).toBe(
      "You have a booking that is not finished.",
    );
    expect(deletionErrorMessage(400, { error: "Give a reason of 3 to 300 characters" })).toMatch(/reason/);
    expect(deletionErrorMessage(502, { error: "The details are erased, but the sign in could not be removed. Run the deletion again to finish it." })).toMatch(/Run the deletion again/);
  });
  it("has plain messages for sign in and role problems", () => {
    expect(deletionErrorMessage(401, {})).toMatch(/Sign in again/);
    expect(deletionErrorMessage(403, { error: "x" })).toBe("Only full admins can delete accounts.");
  });
  it("hides server faults", () => {
    expect(deletionErrorMessage(500, { error: "stack trace" })).not.toMatch(/stack/);
    expect(deletionErrorMessage(500, null)).toMatch(/could not be deleted/);
  });
});
