"use client";

import { ActionForm, SubmitButton } from "@/components/ActionForm";
import { setOrderStatus, widenAlert } from "@/lib/actions/lost";

export function WidenButton({ alertId, radius }: { alertId: string; radius: number }) {
  return (
    <ActionForm action={widenAlert} className="row">
      <input type="hidden" name="alert" value={alertId} />
      <input type="hidden" name="radius_m" value={radius} />
      <SubmitButton small variant="secondary">
        Widen to {radius / 1000} km
      </SubmitButton>
    </ActionForm>
  );
}

export function OrderButton({ orderId, next }: { orderId: string; next: "shipped" | "delivered" }) {
  return (
    <ActionForm action={setOrderStatus} className="row">
      <input type="hidden" name="order" value={orderId} />
      <input type="hidden" name="status" value={next} />
      <SubmitButton small variant="secondary">
        {next === "shipped" ? "Mark shipped" : "Mark delivered"}
      </SubmitButton>
    </ActionForm>
  );
}
