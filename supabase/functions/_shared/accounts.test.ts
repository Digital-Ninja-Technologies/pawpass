import { beforeEach, describe, expect, it } from "vitest";
import {
  BlockedError,
  deleteAccount,
  isConfirmed,
  type AccountAuth,
  type AccountCtx,
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
