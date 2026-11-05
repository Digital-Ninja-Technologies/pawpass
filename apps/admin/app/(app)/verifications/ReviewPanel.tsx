"use client";

import { ActionForm, SubmitButton } from "@/components/ActionForm";
import { reviewPartner } from "@/lib/actions/verifications";
import { KYC_CHECKS } from "@/lib/kyc";

export function ReviewPanel({
  partnerId,
  checks,
  internalNote,
  decisionNote,
}: {
  partnerId: string;
  checks: Record<string, boolean>;
  internalNote: string;
  decisionNote: string;
}) {
  return (
    <ActionForm action={reviewPartner}>
      <input type="hidden" name="partner" value={partnerId} />
      <fieldset className="stack" style={{ border: 0, padding: 0, margin: 0 }}>
        <legend className="overline" style={{ marginBottom: 8 }}>
          Checks
        </legend>
        {KYC_CHECKS.map((c) => (
          <label key={c.key} className="check">
            <input
              type="checkbox"
              name={`check_${c.key}`}
              defaultChecked={Boolean(checks[c.key])}
            />
            {c.label}
          </label>
        ))}
      </fieldset>
      <label className="field">
        Internal note
        <textarea
          className="textarea"
          name="internal_note"
          defaultValue={internalNote}
          placeholder="Only the team can see this"
        />
      </label>
      <label className="field">
        Message to the partner
        <textarea
          className="textarea"
          name="message"
          defaultValue={decisionNote}
          placeholder="Required if you reject or ask for more information"
        />
        <span className="hint">The partner sees this message in the app.</span>
      </label>
      <div className="row between">
        <SubmitButton name="intent" value="save" variant="secondary">
          Save notes
        </SubmitButton>
        <div className="row">
          <SubmitButton
            name="intent"
            value="reject"
            variant="danger"
            confirm="Reject this application?"
          >
            Reject
          </SubmitButton>
          <SubmitButton name="intent" value="needs_info" variant="secondary">
            Ask for more info
          </SubmitButton>
          <SubmitButton name="intent" value="approve">
            Approve &amp; give badge
          </SubmitButton>
        </div>
      </div>
    </ActionForm>
  );
}
