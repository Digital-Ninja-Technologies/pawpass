import { describe, expect, it } from "vitest";
import { describeAudit } from "./audit";

const row = (
  action: string,
  details: Record<string, unknown> = {},
  target_id: string | null = "t1",
) => ({ action, target_id, details });

describe("describeAudit", () => {
  it("names the partner", () => {
    expect(describeAudit(row("partner.approve"), { t1: "Glam Paws Grooming" })).toBe(
      "approved Glam Paws Grooming",
    );
    expect(
      describeAudit(row("partner.needs_info", { note: "Clearer CAC please" }), { t1: "Glam Paws" }),
    ).toBe('asked Glam Paws for more information: "Clearer CAC please"');
  });
  it("describes money decisions with amounts", () => {
    expect(
      describeAudit(row("dispute.refund", { amount_kobo: 38_000_000 }), { t1: "D-1042" }),
    ).toBe("refunded dispute D-1042 (₦380,000)");
    expect(describeAudit(row("dispute.split", { refund_kobo: 19_000_000 }), { t1: "D-1042" })).toBe(
      "split dispute D-1042, refunding ₦190,000",
    );
  });
  it("does not break when a name is missing", () => {
    expect(describeAudit(row("partner.reject", {}, null))).toBe("rejected a partner");
  });
  it("covers invites and role changes", () => {
    expect(describeAudit(row("staff.invite", { email: "a@b.ng", role: "support_reports" }))).toBe(
      "invited a@b.ng as support reports",
    );
    expect(describeAudit(row("staff.role", { from: "read_only", to: "full_admin" }))).toBe(
      "changed a team role from read only to full admin",
    );
  });
  it("falls back to a readable version of unknown actions", () => {
    expect(describeAudit(row("thing.happened"))).toBe("thing happened");
  });
});
