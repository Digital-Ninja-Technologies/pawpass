"use client";

import { createContext, useContext, type ReactNode } from "react";
import type { ActionState } from "@/lib/actions/helpers";
import { useFormAction } from "./useFormAction";

type Action = (prev: ActionState, formData: FormData) => Promise<ActionState>;

const PendingContext = createContext(false);

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
  const { state, onSubmit, pending } = useFormAction<ActionState>(action);
  return (
    <PendingContext.Provider value={pending}>
      <form onSubmit={onSubmit} className={className ?? "stack"}>
        {children}
        {state && !(state.ok && hideSuccess) ? (
          <div className={`notice ${state.ok ? "ok" : "err"}`} role={state.ok ? "status" : "alert"}>
            {state.message}
          </div>
        ) : null}
      </form>
    </PendingContext.Provider>
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
  const pending = useContext(PendingContext);
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
