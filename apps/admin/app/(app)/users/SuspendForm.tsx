"use client";

import { ActionForm, SubmitButton } from "@/components/ActionForm";
import { setSuspended } from "@/lib/actions/users";

export function SuspendForm({ userId, suspended }: { userId: string; suspended: boolean }) {
  return (
    <ActionForm action={setSuspended}>
      <input type="hidden" name="user" value={userId} />
      <input type="hidden" name="suspend" value={suspended ? "false" : "true"} />
      {suspended ? null : (
        <label className="field">
          Reason (kept in the audit log)
          <input
            className="input"
            name="reason"
            required
            placeholder="For example: repeated scam reports"
          />
        </label>
      )}
      <div>
        <SubmitButton
          variant={suspended ? "secondary" : "danger"}
          confirm={
            suspended
              ? undefined
              : "Suspend this account? They are signed out and cannot sign in. Partner listings are taken down."
          }
        >
          {suspended ? "Restore account" : "Suspend account"}
        </SubmitButton>
      </div>
    </ActionForm>
  );
}
