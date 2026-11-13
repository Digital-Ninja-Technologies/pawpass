"use client";

import { ActionForm, SubmitButton } from "@/components/ActionForm";
import { refundPurchase, retryRefund } from "@/lib/actions/courses";

export function RefundButton({
  purchaseId,
  courseId,
  buyer,
  amount,
}: {
  purchaseId: string;
  courseId: string;
  buyer: string;
  /** Already formatted, for example ₦2,500. */
  amount: string;
}) {
  return (
    <ActionForm action={refundPurchase} className="row">
      <input type="hidden" name="purchase" value={purchaseId} />
      <input type="hidden" name="course" value={courseId} />
      <label className="sr-only" htmlFor={`reason-${purchaseId}`}>
        Reason for refunding {buyer}
      </label>
      <input
        id={`reason-${purchaseId}`}
        className="input"
        name="reason"
        placeholder="Reason (kept in the audit log)"
        minLength={3}
        maxLength={300}
        required
        style={{ minWidth: 220, minHeight: 36, height: 36 }}
      />
      <SubmitButton
        small
        variant="danger"
        confirm={`Refund ${amount} to ${buyer}? They lose the course straight away and the money goes back to their card or bank on Paystack. This cannot be undone.`}
      >
        Refund {amount}
      </SubmitButton>
    </ActionForm>
  );
}

export function RetryRefundButton({ purchaseId, courseId }: { purchaseId: string; courseId: string }) {
  return (
    <ActionForm action={retryRefund} className="row">
      <input type="hidden" name="purchase" value={purchaseId} />
      <input type="hidden" name="course" value={courseId} />
      <SubmitButton small variant="secondary">
        Try the refund again
      </SubmitButton>
    </ActionForm>
  );
}
