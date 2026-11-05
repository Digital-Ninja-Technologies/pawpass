import { describe, expect, it } from "vitest";
import { ACTIONS, canDo, canView, isRole, ROLES, roleCapabilities, SECTIONS } from "./roles";

describe("roles", () => {
  it("full admins can open every section and do every action", () => {
    for (const s of SECTIONS) expect(canView("full_admin", s)).toBe(true);
    for (const a of ACTIONS) expect(canDo("full_admin", a)).toBe(true);
  });

  it("read only can view dashboards but never act", () => {
    expect(canView("read_only", "disputes")).toBe(true);
    for (const a of ACTIONS) expect(canDo("read_only", a)).toBe(false);
  });

  it("each working role can only act in its own area", () => {
    expect(canDo("verifications", "review_partner")).toBe(true);
    expect(canDo("verifications", "decide_dispute")).toBe(false);
    expect(canDo("payouts_disputes", "decide_dispute")).toBe(true);
    expect(canDo("payouts_disputes", "resolve_report")).toBe(false);
    expect(canDo("support_reports", "resolve_report")).toBe(true);
    expect(canDo("support_reports", "prepare_payout")).toBe(false);
  });

  it("only full admins change settings and manage the team", () => {
    for (const r of ROLES.filter((r) => r !== "full_admin")) {
      expect(canDo(r, "edit_settings")).toBe(false);
      expect(canDo(r, "manage_team")).toBe(false);
    }
  });

  it("hides money pages from roles that cannot read escrow", () => {
    expect(canView("support_reports", "payouts")).toBe(false);
    expect(canView("verifications", "payouts")).toBe(false);
    expect(canView("verifications", "support")).toBe(false);
  });

  it("everyone can see the overview and settings", () => {
    for (const r of ROLES) {
      expect(canView(r, "overview")).toBe(true);
      expect(canView(r, "settings")).toBe(true);
    }
  });

  it("lists what a role can and cannot do, with no overlap", () => {
    const c = roleCapabilities("support_reports");
    expect(c.can.join(" ")).toMatch(/Reply to support tickets/);
    expect(c.cannot.join(" ")).toMatch(/payout/i);
    expect(c.can.filter((x) => c.cannot.includes(x))).toEqual([]);
    expect(roleCapabilities("read_only").can).toEqual([]);
  });

  it("recognises valid roles only", () => {
    expect(isRole("full_admin")).toBe(true);
    expect(isRole("root")).toBe(false);
    expect(isRole(null)).toBe(false);
  });
});
