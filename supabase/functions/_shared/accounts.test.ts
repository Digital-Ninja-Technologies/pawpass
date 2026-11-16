import { beforeEach, describe, expect, it } from "vitest";
import {
  BlockedError,
  adminDeleteAccount,
  deleteAccount,
  isConfirmed,
  type AccountAuth,
  type AccountCtx,
  type AdminAccountCtx,
  type AccountDb,
  type AccountFiles,
} from "./accounts.ts";
import { HttpError } from "./payments.ts";

const user = { id: "user-1" };

class FakeDb implements AccountDb {
  erased: string[] = [];
  blockedWith: string | null = null;
  fail: Error | null = null;
  async erase(userId: string) {
    if (this.blockedWith) throw new BlockedError(this.blockedWith);
    if (this.fail) throw this.fail;
    this.erased.push(userId);
  }
}
class FakeFiles implements AccountFiles {
  removed: string[] = [];
  fail = false;
  async removeAll(userId: string) {
    if (this.fail) throw new Error("storage down");
    this.removed.push(userId);
    return 3;
  }
}
class FakeAuth implements AccountAuth {
  deleted: string[] = [];
  fail = false;
  async softDelete(userId: string) {
    if (this.fail) throw new Error("auth down");
    this.deleted.push(userId);
  }
}

let db: FakeDb, files: FakeFiles, auth: FakeAuth, ctx: AccountCtx;
beforeEach(() => {
  db = new FakeDb();
  files = new FakeFiles();
  auth = new FakeAuth();
  ctx = { db, files, auth };
});

const status = async (p: Promise<unknown>) => {
  try {
    await p;
    return 200;
  } catch (e) {
    return e instanceof HttpError ? e.status : -1;
  }
};

describe("isConfirmed", () => {
  it("wants the word DELETE, in any case, with spaces around it", () => {
    expect(isConfirmed("DELETE")).toBe(true);
    expect(isConfirmed("  delete ")).toBe(true);
    for (const bad of ["", "del", "yes", "DELETE ME", null, undefined, 1, true]) {
      expect(isConfirmed(bad)).toBe(false);
    }
  });
});

describe("deleteAccount", () => {
  it("erases the data, removes the files, then removes the sign in, in that order", async () => {
    const order: string[] = [];
    db.erase = async () => void order.push("data");
    files.removeAll = async () => (order.push("files"), 0);
    auth.softDelete = async () => void order.push("signin");
    expect(await deleteAccount(ctx, user, { confirm: "DELETE" })).toEqual({ ok: true });
    expect(order).toEqual(["data", "files", "signin"]);
  });

  it("does nothing without the confirmation word", async () => {
    expect(await status(deleteAccount(ctx, user, {}))).toBe(400);
    expect(await status(deleteAccount(ctx, user, { confirm: "yes" }))).toBe(400);
    expect(db.erased).toEqual([]);
    expect(auth.deleted).toEqual([]);
  });

  it("refuses with the reason while money or a handover is in flight, and touches nothing else", async () => {
    db.blockedWith = "You have a booking that is not finished.";
    let message = "";
    try {
      await deleteAccount(ctx, user, { confirm: "DELETE" });
    } catch (e) {
      expect(e).toBeInstanceOf(HttpError);
      expect((e as HttpError).status).toBe(409);
      message = (e as HttpError).message;
    }
    expect(message).toBe("You have a booking that is not finished.");
    expect(files.removed).toEqual([]);
    expect(auth.deleted).toEqual([]);
  });

  it("a database failure is not reported as a refusal, and stops everything", async () => {
    db.fail = new Error("connection reset");
    expect(await status(deleteAccount(ctx, user, { confirm: "DELETE" }))).toBe(-1);
    expect(files.removed).toEqual([]);
    expect(auth.deleted).toEqual([]);
  });

  it("a file clean up failure does not stop the deletion", async () => {
    files.fail = true;
    expect(await status(deleteAccount(ctx, user, { confirm: "DELETE" }))).toBe(200);
    expect(auth.deleted).toEqual(["user-1"]);
  });

  it("if removing the sign in fails it says so, and trying again works", async () => {
    auth.fail = true;
    expect(await status(deleteAccount(ctx, user, { confirm: "DELETE" }))).toBe(502);
    expect(db.erased).toEqual(["user-1"]);
    auth.fail = false;
    expect(await status(deleteAccount(ctx, user, { confirm: "DELETE" }))).toBe(200);
    expect(auth.deleted).toEqual(["user-1"]);
  });
});

// ---------------------------------------------------------------------------------------------------------------
// An admin deleting someone else's account
// ---------------------------------------------------------------------------------------------------------------
describe("adminDeleteAccount", () => {
  const admin = { id: "11111111-1111-4111-8111-111111111111" };
  const target = "22222222-2222-4222-8222-222222222222";
  let staffId: string | null;
  let state: "active" | "deleted" | "missing";
  let audits: { staffId: string; userId: string; reason: string }[];
  let auditFails: boolean;
  let actx: AdminAccountCtx;

  beforeEach(() => {
    staffId = "staff-1";
    state = "active";
    audits = [];
    auditFails = false;
    actx = {
      db,
      files,
      auth,
      admins: {
        fullAdminStaffId: async () => staffId,
        accountState: async () => state,
        audit: async (s, u, r) => {
          if (auditFails) throw new Error("audit down");
          audits.push({ staffId: s, userId: u, reason: r });
        },
      },
    };
  });

  const ok = { user: target, reason: "Asked by email" };

  it("only an active full admin may", async () => {
    staffId = null;
    expect(await status(adminDeleteAccount(actx, admin, ok))).toBe(403);
    expect(db.erased).toEqual([]);
  });

  it("erases, logs the reason, removes files and the sign in, in that order of importance", async () => {
    expect(await status(adminDeleteAccount(actx, admin, ok))).toBe(200);
    expect(db.erased).toEqual([target]);
    expect(audits).toEqual([{ staffId: "staff-1", userId: target, reason: "Asked by email" }]);
    expect(files.removed).toEqual([target]);
    expect(auth.deleted).toEqual([target]);
  });

  it("needs a real account id and a reason", async () => {
    expect(await status(adminDeleteAccount(actx, admin, { user: "nope", reason: "Asked by email" }))).toBe(400);
    expect(await status(adminDeleteAccount(actx, admin, { reason: "Asked by email" }))).toBe(400);
    expect(await status(adminDeleteAccount(actx, admin, { user: target }))).toBe(400);
    expect(await status(adminDeleteAccount(actx, admin, { user: target, reason: "no" }))).toBe(400);
    expect(await status(adminDeleteAccount(actx, admin, { user: target, reason: "x".repeat(301) }))).toBe(400);
    expect(db.erased).toEqual([]);
  });

  it("will not delete the admin's own account", async () => {
    expect(await status(adminDeleteAccount(actx, admin, { user: admin.id.toUpperCase(), reason: "Asked by email" }))).toBe(400);
    expect(db.erased).toEqual([]);
  });

  it("says when the account is missing or already deleted", async () => {
    state = "missing";
    expect(await status(adminDeleteAccount(actx, admin, ok))).toBe(404);
    state = "deleted";
    expect(await status(adminDeleteAccount(actx, admin, ok))).toBe(409);
    expect(db.erased).toEqual([]);
    expect(audits).toEqual([]);
  });

  it("a refusal from the database stops everything and is not logged as a deletion", async () => {
    db.blockedWith = "You have a booking that is not finished.";
    expect(await status(adminDeleteAccount(actx, admin, ok))).toBe(409);
    expect(audits).toEqual([]);
    expect(files.removed).toEqual([]);
    expect(auth.deleted).toEqual([]);
  });

  it("a failed audit write or file cleanup does not undo the deletion", async () => {
    auditFails = true;
    files.fail = true;
    expect(await status(adminDeleteAccount(actx, admin, ok))).toBe(200);
    expect(auth.deleted).toEqual([target]);
  });

  it("a failed sign in removal asks to run it again", async () => {
    auth.fail = true;
    expect(await status(adminDeleteAccount(actx, admin, ok))).toBe(502);
    expect(db.erased).toEqual([target]);
    expect(audits.length).toBe(1);
  });
});
