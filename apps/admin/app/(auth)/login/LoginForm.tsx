"use client";

import { useState } from "react";
import { signIn } from "@/lib/actions/auth";
import { useFormAction } from "@/components/useFormAction";

function Submit({ pending }: { pending: boolean }) {
  return (
    <button type="submit" className="btn primary block" disabled={pending} aria-busy={pending}>
      {pending ? "Signing in…" : "Sign in"}
    </button>
  );
}

export function LoginForm({ next }: { next: string }) {
  const { state, onSubmit, pending } = useFormAction(signIn);
  const [show, setShow] = useState(false);
  return (
    <form onSubmit={onSubmit} className="stack" style={{ gap: 16 }}>
      <input type="hidden" name="next" value={next} />
      <label className="field">
        Work email
        <input
          className="input"
          type="email"
          name="email"
          autoComplete="username"
          required
          autoFocus
        />
      </label>
      <label className="field">
        Password
        <span style={{ display: "flex", gap: 8 }}>
          <input
            className="input"
            type={show ? "text" : "password"}
            name="password"
            autoComplete="current-password"
            required
          />
          <button
            type="button"
            className="btn secondary"
            onClick={() => setShow((s) => !s)}
            aria-pressed={show}
          >
            {show ? "Hide" : "Show"}
          </button>
        </span>
      </label>
      {state && !state.ok ? (
        <div className="notice err" role="alert">
          {state.message}
        </div>
      ) : null}
      <Submit pending={pending} />
    </form>
  );
}
