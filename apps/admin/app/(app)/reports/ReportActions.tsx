"use client";

import { ActionForm, SubmitButton } from "@/components/ActionForm";
import { resolveReport } from "@/lib/actions/reports";

export function ReportActions({
  targetType,
  targetId,
  canSuspend,
}: {
  targetType: string;
  targetId: string;
  canSuspend: boolean;
}) {
  return (
    <ActionForm action={resolveReport}>
      <input type="hidden" name="target_type" value={targetType} />
      <input type="hidden" name="target_id" value={targetId} />
      <label className="field">
        Note (kept in the audit log)
        <textarea className="textarea" name="note" style={{ minHeight: 64 }} />
      </label>
      <div className="row">
        {canSuspend ? (
          <SubmitButton
            name="action"
            value="remove_and_suspend"
            variant="danger"
            confirm="Remove this and suspend the account? The person is signed out and cannot sign in."
          >
            Remove &amp; suspend
          </SubmitButton>
        ) : null}
        <SubmitButton name="action" value="remove" variant="secondary">
          Remove only
        </SubmitButton>
        <SubmitButton name="action" value="keep" variant="secondary">
          Keep · not a violation
        </SubmitButton>
      </div>
    </ActionForm>
  );
}
