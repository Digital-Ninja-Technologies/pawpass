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

  it("only full admins manage courses; money staff can see them to refund; read only can look", () => {
    expect(canView("full_admin", "courses")).toBe(true);
    expect(canView("read_only", "courses")).toBe(true);
    expect(canView("payouts_disputes", "courses")).toBe(true);
    for (const r of ["support_reports", "verifications"] as const) {
      expect(canView(r, "courses")).toBe(false);
    }
    for (const r of ROLES.filter((r) => r !== "full_admin")) {
      expect(canDo(r, "manage_courses")).toBe(false);
    }
    expect(roleCapabilities("support_reports").cannot.join(" ")).toMatch(/courses/i);
  });

  it("refunding a course purchase is for payouts and disputes (and full admins), nobody else", () => {
    expect(canDo("full_admin", "refund_course")).toBe(true);
    expect(canDo("payouts_disputes", "refund_course")).toBe(true);
    for (const r of ROLES.filter((r) => r !== "full_admin" && r !== "payouts_disputes")) {
      expect(canDo(r, "refund_course")).toBe(false);
    }
    expect(roleCapabilities("payouts_disputes").can.join(" ")).toMatch(/Refund course purchases/);
    expect(roleCapabilities("support_reports").cannot.join(" ")).toMatch(/Refund course purchases/);
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
