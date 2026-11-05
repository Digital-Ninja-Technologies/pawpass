"use client";

import { ActionForm, SubmitButton } from "@/components/ActionForm";
import { approveRun, prepareRun } from "@/lib/actions/payouts";

export function PrepareForm({ runOn, hasDraft }: { runOn: string; hasDraft: boolean }) {
  return (
    <ActionForm action={prepareRun}>
      <input type="hidden" name="run_on" value={runOn} />
      <div>
        <SubmitButton variant={hasDraft ? "secondary" : "primary"}>
          {hasDraft ? "Refresh from ready money" : "Prepare this run"}
        </SubmitButton>
      </div>
    </ActionForm>
  );
}

export function ApproveForm({ runId, total }: { runId: string; total: string }) {
  return (
    <ActionForm action={approveRun}>
      <input type="hidden" name="run" value={runId} />
      <div>
        <SubmitButton
          confirm={`Approve this payout run of ${total}? It cannot be edited after approval.`}
        >
          Approve payout run
        </SubmitButton>
      </div>
    </ActionForm>
  );
}
