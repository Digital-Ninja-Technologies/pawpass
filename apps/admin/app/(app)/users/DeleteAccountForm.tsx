"use client";

import { ActionForm, SubmitButton } from "@/components/ActionForm";
import { deleteUserAccount } from "@/lib/actions/users";

/** Delete a person's account on request. Shows what is in the way first; otherwise asks for a reason and the email. */
export function DeleteAccountForm({
  userId,
  email,
  blockers,
}: {
  userId: string;
  email: string | null;
  blockers: string[];
}) {
  return (
    <section className="stack" aria-label="Delete account">
      <h3 style={{ fontSize: 16 }}>Delete this account</h3>
      <p className="small muted">
        For people who asked to be deleted and cannot use the app. Their personal data is erased and they can never sign in
        again. Payment and booking records stay, with the name replaced by Deleted user. This cannot be undone.
      </p>
      {blockers.length > 0 ? (
        <div className="notice err" role="alert">
          <b>Not yet. Finish these first:</b>
          <ul style={{ margin: "6px 0 0", paddingLeft: 18 }}>
            {blockers.map((b) => (
              <li key={b}>{b}</li>
            ))}
          </ul>
        </div>
      ) : !email ? (
        <div className="notice err" role="alert">
          This account has no email address on file, so it cannot be confirmed here.
        </div>
      ) : (
        <ActionForm action={deleteUserAccount}>
          <input type="hidden" name="user" value={userId} />
          <label className="field">
            Reason (kept in the audit log)
            <input
              className="input"
              name="reason"
              required
              minLength={3}
              maxLength={300}
              placeholder="For example: asked by email on 16 November"
            />
          </label>
          <label className="field">
            Type the account email to confirm
            <input
              className="input"
              name="confirm_email"
              type="email"
              required
              autoComplete="off"
              placeholder={email}
            />
          </label>
          <div>
            <SubmitButton
              variant="danger"
              confirm="Delete this account for good? Their personal data is erased and this cannot be undone."
            >
              Delete account
            </SubmitButton>
          </div>
        </ActionForm>
      )}
    </section>
  );
}
