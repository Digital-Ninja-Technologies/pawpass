import { describe, expect, it } from "vitest";
import { PET_INFO, PET_OPTIONS, TABS, FAQS } from "./content";

describe("landing content", () => {
  it("has copy for every pet option", () => {
    for (const p of PET_OPTIONS) expect(PET_INFO[p.id].name).toBeTruthy();
  });
  it("has four feature tabs, each with three points", () => {
    expect(TABS).toHaveLength(4);
    for (const t of TABS) expect(t.points).toHaveLength(3);
  });
  it("follows the copy rules: no em dashes, no hyphenated 72-hour or 6-digit phrases", () => {
    const text = JSON.stringify({ PET_INFO, TABS, FAQS });
    expect(text).not.toContain("—");
    expect(text).not.toMatch(/\b\d+-(hour|digit|km)\b/);
  });
  it("uses naira, never a bare dollar sign", () => {
    expect(JSON.stringify({ TABS, FAQS })).not.toContain("$");
  });
});
