"use client";

import { useState } from "react";
import { ActionForm, SubmitButton } from "@/components/ActionForm";
import { decideDispute } from "@/lib/actions/disputes";

export function DecisionPanel({
  disputeId,
  amountLabel,
  partnerName,
}: {
  disputeId: string;
  amountLabel: string;
  partnerName: string;
}) {
  const [decision, setDecision] = useState<"refund" | "split" | "release">("refund");
  const labels = {
    refund: `Confirm refund ${amountLabel}`,
    split: "Confirm split",
    release: `Release ${amountLabel} to ${partnerName}`,
  } as const;
  return (
    <ActionForm action={decideDispute}>
      <input type="hidden" name="dispute" value={disputeId} />
      <fieldset className="stack" style={{ border: 0, padding: 0, margin: 0 }}>
        <legend className="overline" style={{ marginBottom: 8 }}>
          Decision
        </legend>
        {(
          [
            ["refund", "Full refund to buyer", "The whole amount goes back to the buyer."],
            [
              "split",
              "Split the amount",
              "Refund part to the buyer, release the rest to the partner.",
            ],
            ["release", `Release to partner`, "The partner is paid in the next payout run."],
          ] as const
        ).map(([value, title, hint]) => (
          <label key={value} className="radio-card">
            <input
              type="radio"
              name="decision"
              value={value}
              checked={decision === value}
              onChange={() => setDecision(value)}
            />
            <span>
              <b>{title}</b>
              {hint}
            </span>
          </label>
        ))}
      </fieldset>
      {decision === "split" ? (
        <label className="field">
          Refund to buyer (₦)
          <input
            className="input"
            name="refund"
            inputMode="decimal"
            placeholder="190,000"
            required
          />
          <span className="hint">Must be above zero and below the full amount {amountLabel}.</span>
        </label>
      ) : null}
      <label className="field">
        Note for both parties
        <textarea
          className="textarea"
          name="note"
          placeholder="Why you decided this. Both sides see it."
        />
      </label>
      <div>
        <SubmitButton confirm="This decision is final and cannot be undone. Continue?">
          {labels[decision]}
        </SubmitButton>
      </div>
    </ActionForm>
  );
}
