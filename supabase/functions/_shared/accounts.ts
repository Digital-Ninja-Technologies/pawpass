// Deleting an account, written against small interfaces so it can be tested without a database or Auth.
// The delete-account function wires these to the real services. See migration 20261114100000_delete_account.sql.
import { HttpError } from "./payments.ts";

/** The database refused to erase the account because money or a handover is still in flight. */
export class BlockedError extends Error {}

export interface AccountDb {
  /** Scrubs everything personal. Throws [BlockedError] with a readable message if the person cannot leave yet. */
  erase(userId: string): Promise<void>;
}

export interface AccountFiles {
  /** Removes every file the person uploaded. Returns how many. */
  removeAll(userId: string): Promise<number>;
}

export interface AccountAuth {
  /** Removes the sign in for good (the email and phone are wiped; the person can never sign in again). */
  softDelete(userId: string): Promise<void>;
}

export interface AccountCtx {
  db: AccountDb;
  files: AccountFiles;
  auth: AccountAuth;
}

/** What the person has to type to confirm. */
export const DELETE_WORD = "DELETE";

export function isConfirmed(value: unknown): boolean {
  return typeof value === "string" && value.trim().toUpperCase() === DELETE_WORD;
}

/**
 * Deletes the signed in person's account.
 *  1. The database erases everything personal (or refuses, with the reason).
 *  2. Their files are removed. A failure here is logged and does not stop the deletion.
 *  3. The sign in is removed. If this fails the person can simply try again: step 1 is safe to repeat.
 */
export async function deleteAccount(
  ctx: AccountCtx,
  user: { id: string },
  input: { confirm?: unknown },
): Promise<{ ok: true }> {
  if (!isConfirmed(input.confirm)) throw new HttpError(400, `Type ${DELETE_WORD} to confirm`);
  try {
    await ctx.db.erase(user.id);
  } catch (e) {
    if (e instanceof BlockedError) throw new HttpError(409, e.message);
    throw e;
  }
  try {
    await ctx.files.removeAll(user.id);
  } catch (e) {
    console.error("file cleanup failed", user.id, e);
  }
  try {
    await ctx.auth.softDelete(user.id);
  } catch (e) {
    console.error("sign in removal failed", user.id, e);
    throw new HttpError(
      502,
      "Your details are erased, but we could not finish closing your account. Please try again.",
    );
  }
  return { ok: true };
}

// ---------------------------------------------------------------------------------------------------------------
// Deleting someone else's account, as a full admin (people who ask by email and cannot use the app)
// ---------------------------------------------------------------------------------------------------------------
export interface AdminAccountCtx extends AccountCtx {
  admins: {
    /** The staff id if this signed in person is an active full admin, otherwise null. */
    fullAdminStaffId(userId: string): Promise<string | null>;
    /** Whether the account is there, already deleted, or never existed. */
    accountState(userId: string): Promise<"active" | "deleted" | "missing">;
    /** Writes the audit row. Called once the account has been erased. */
    audit(staffId: string, userId: string, reason: string): Promise<void>;
  };
}

const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

/**
 * Deletes another person's account. Only an active full admin may, and not their own (they use the app for that).
 *  1. The database erases everything personal, or refuses with the reason (money or a handover is unfinished).
 *  2. The deletion is written to the audit log with the reason. If that fails the deletion still stands, and is logged.
 *  3. Their files are removed (a failure is logged, not fatal).
 *  4. The sign in is removed. If this fails the admin can run it again: step 1 is safe to repeat.
 */
export async function adminDeleteAccount(
  ctx: AdminAccountCtx,
  admin: { id: string },
  input: { user?: unknown; reason?: unknown },
): Promise<{ ok: true }> {
  const staffId = await ctx.admins.fullAdminStaffId(admin.id);
  if (!staffId) throw new HttpError(403, "Only full admins can delete accounts");

  const target = typeof input.user === "string" ? input.user.trim() : "";
  if (!UUID.test(target)) throw new HttpError(400, "That account could not be found");
  const reason = typeof input.reason === "string" ? input.reason.trim() : "";
  if (reason.length < 3 || reason.length > 300) throw new HttpError(400, "Give a reason of 3 to 300 characters");
  if (target.toLowerCase() === admin.id.toLowerCase()) {
    throw new HttpError(400, "This is your own account. Delete it from the app.");
  }

  const state = await ctx.admins.accountState(target);
  if (state === "missing") throw new HttpError(404, "That account could not be found");
  if (state === "deleted") throw new HttpError(409, "That account has already been deleted");

  try {
    await ctx.db.erase(target);
  } catch (e) {
    if (e instanceof BlockedError) throw new HttpError(409, e.message);
    throw e;
  }
  try {
    await ctx.admins.audit(staffId, target, reason);
  } catch (e) {
    console.error("account deletion not logged", target, e);
  }
  try {
    await ctx.files.removeAll(target);
  } catch (e) {
    console.error("file cleanup failed", target, e);
  }
  try {
    await ctx.auth.softDelete(target);
  } catch (e) {
    console.error("sign in removal failed", target, e);
    throw new HttpError(
      502,
      "The details are erased, but the sign in could not be removed. Run the deletion again to finish it.",
    );
  }
  return { ok: true };
}
