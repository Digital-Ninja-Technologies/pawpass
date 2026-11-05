"use client";

import { useActionState, type ReactNode } from "react";
import { useFormStatus } from "react-dom";
import type { ActionState } from "@/lib/actions/helpers";

type Action = (prev: ActionState, formData: FormData) => Promise<ActionState>;

/** A form wired to a server action with a pending state and a visible result message. */
export function ActionForm({
  action,
  children,
  className,
  hideSuccess,
}: {
  action: Action;
  children: ReactNode;
  className?: string;
  hideSuccess?: boolean;
}) {
  const [state, formAction] = useActionState(action, null);
  return (
    <form action={formAction} className={className ?? "stack"}>
      {children}
      {state && !(state.ok && hideSuccess) ? (
        <div className={`notice ${state.ok ? "ok" : "err"}`} role={state.ok ? "status" : "alert"}>
          {state.message}
        </div>
      ) : null}
    </form>
  );
}

export function SubmitButton({
  children,
  variant = "primary",
  name,
  value,
  small,
  confirm,
}: {
  children: ReactNode;
  variant?: "primary" | "secondary" | "danger" | "warm";
  name?: string;
  value?: string;
  small?: boolean;
  /** Ask before sending, for actions that are hard to undo. */
  confirm?: string;
}) {
  const { pending } = useFormStatus();
  return (
    <button
      type="submit"
      name={name}
      value={value}
      className={`btn ${variant}${small ? " small" : ""}`}
      disabled={pending}
      aria-busy={pending}
      onClick={(e) => {
        if (confirm && !window.confirm(confirm)) e.preventDefault();
      }}
    >
      {pending ? "Working…" : children}
    </button>
  );
}
