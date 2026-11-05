"use client";

import { startTransition, useActionState, useId, type FormEvent } from "react";
import { joinWaitlist, type WaitlistState } from "@/lib/waitlist";

export function WaitlistForm({
  source,
  dark = false,
}: {
  source: "download" | "partners";
  dark?: boolean;
}) {
  const id = useId();
  const [state, action, pending] = useActionState<WaitlistState | null, FormData>(
    joinWaitlist,
    null,
  );

  // Submit through onSubmit so React does not wipe the email field after an error.
  const onSubmit = (e: FormEvent<HTMLFormElement>) => {
    e.preventDefault();
    const data = new FormData(e.currentTarget);
    startTransition(() => action(data));
  };

  if (state?.ok) {
    return (
      <p className={`wl-done${dark ? " dark" : ""}`} role="status">
        <span aria-hidden="true">✓</span> {state.message}
      </p>
    );
  }

  return (
    <form onSubmit={onSubmit} className={`wl${dark ? " dark" : ""}`} noValidate>
      <label htmlFor={`${id}-email`} className="sr-only">
        Email address
      </label>
      <input
        id={`${id}-email`}
        name="email"
        type="email"
        inputMode="email"
        autoComplete="email"
        placeholder="Your email address"
        required
        aria-describedby={state && !state.ok ? `${id}-error` : undefined}
        aria-invalid={state && !state.ok ? true : undefined}
      />
      {/* Honeypot: hidden from people and screen readers. */}
      <input name="company" tabIndex={-1} autoComplete="off" aria-hidden="true" className="hp" />
      <input type="hidden" name="source" value={source} />
      <button type="submit" disabled={pending} aria-busy={pending}>
        {pending ? "Sending…" : "Email me the link"}
      </button>
      {state && !state.ok ? (
        <p id={`${id}-error`} className="wl-error" role="alert">
          {state.message}
        </p>
      ) : null}
    </form>
  );
}
