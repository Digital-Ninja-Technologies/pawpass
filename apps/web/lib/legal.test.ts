import { describe, expect, it } from "vitest";
import { DELETE_ACCOUNT, PRIVACY, TERMS } from "./legal";
import { CONTACT_EMAIL, safeEmail } from "./contact";

describe("legal copy", () => {
  const text = JSON.stringify({ PRIVACY, TERMS, DELETE_ACCOUNT });
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
  it("tells the truth about location and events", () => {
    const privacy = JSON.stringify(PRIVACY);
    expect(privacy).not.toContain("We do not store it");
    expect(privacy).not.toContain("anonymous");
    expect(privacy).toContain("last known approximate location");
    expect(privacy).toContain("notification token");
    expect(privacy).toContain("linked to your account");
  });
  it("has a deletion page that says how, what goes and what stays", () => {
    const titles = DELETE_ACCOUNT.map((s) => s.title);
    expect(titles).toEqual(
      expect.arrayContaining(["Delete it in the app", "What is deleted", "What we have to keep"]),
    );
    expect(JSON.stringify(DELETE_ACCOUNT)).toContain("Delete my account");
    expect(JSON.stringify(PRIVACY)).toContain("ourpawpass.com/delete-account");
  });
  it("validates the contact email", () => {
    expect(safeEmail("help@pawpass.ng")).toBe("help@pawpass.ng");
    expect(safeEmail("not an email")).toBe("");
  });
  it("shows the same support email as the Google Play listing", () => {
    expect(CONTACT_EMAIL).toBe("thedigitalninjatechnologies@gmail.com");
    expect(safeEmail(CONTACT_EMAIL)).toBe(CONTACT_EMAIL);
  });
});
