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
