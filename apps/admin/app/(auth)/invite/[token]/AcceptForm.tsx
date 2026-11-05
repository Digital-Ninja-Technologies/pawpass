"use client";

import { useActionState, useState } from "react";
import { useFormStatus } from "react-dom";
import { acceptInvite, type AcceptState } from "@/lib/actions/invite";

function Submit({ label }: { label: string }) {
  const { pending } = useFormStatus();
  return (
    <button type="submit" className="btn primary block" disabled={pending} aria-busy={pending}>
      {pending ? "Working…" : label}
    </button>
  );
}

export function AcceptForm({ token, email }: { token: string; email: string }) {
  const [state, action] = useActionState<AcceptState | null, FormData>(acceptInvite, null);
  const [mode, setMode] = useState<"new" | "existing">("new");
  return (
    <form action={action} className="stack" style={{ gap: 16 }}>
      <input type="hidden" name="token" value={token} />
      <input type="hidden" name="mode" value={mode} />
      <label className="field">
        Work email
        <input className="input" type="email" value={email} readOnly disabled />
      </label>
      {mode === "new" ? (
        <label className="field">
          Your name
          <input className="input" name="name" autoComplete="name" required />
        </label>
      ) : null}
      <label className="field">
        {mode === "new" ? "Create a password" : "Your password"}
        <input
          className="input"
          type="password"
          name="password"
          autoComplete={mode === "new" ? "new-password" : "current-password"}
          minLength={mode === "new" ? 12 : undefined}
          required
        />
        {mode === "new" ? <span className="hint">At least 12 characters.</span> : null}
      </label>
      <label className="check">
        <input type="checkbox" name="ack" required />
        I&apos;ll keep user data confidential and follow the PawPass staff policy.
      </label>
      {state ? (
        <div className={`notice ${state.ok ? "ok" : "err"}`} role={state.ok ? "status" : "alert"}>
          {state.message}
        </div>
      ) : null}
      <Submit label={mode === "new" ? "Accept & continue" : "Sign in & accept"} />
      <button
        type="button"
        className="btn secondary"
        onClick={() => setMode(mode === "new" ? "existing" : "new")}
      >
        {mode === "new" ? "I already have an account" : "I need to create an account"}
      </button>
    </form>
  );
}
