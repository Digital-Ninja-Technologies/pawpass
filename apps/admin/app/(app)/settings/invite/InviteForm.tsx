"use client";

import { useState } from "react";
import Link from "next/link";
import { useFormAction } from "@/components/useFormAction";
import { createInvite, type InviteState } from "@/lib/actions/invite";
import { ROLES, ROLE_DESCRIPTIONS, ROLE_LABELS, roleCapabilities, type Role } from "@/lib/roles";

function Submit({ pending }: { pending: boolean }) {
  return (
    <button type="submit" className="btn primary" disabled={pending} aria-busy={pending}>
      {pending ? "Creating…" : "Create invite"}
    </button>
  );
}

export function InviteForm({ domain }: { domain: string | null }) {
  const { state, onSubmit, pending } = useFormAction<InviteState>(createInvite);
  const [role, setRole] = useState<Role>("support_reports");
  const caps = roleCapabilities(role);

  if (state?.ok && state.link) {
    return (
      <div className="card stack">
        <div className="notice ok" role="status">
          {state.message}
        </div>
        <label className="field">
          Invite link
          <input
            className="input"
            readOnly
            value={state.link}
            onFocus={(e) => e.currentTarget.select()}
          />
        </label>
        <div className="row">
          <button
            type="button"
            className="btn primary"
            onClick={() => navigator.clipboard?.writeText(state.link!)}
          >
            Copy link
          </button>
          <Link href="/settings" className="btn secondary">
            Back to settings
          </Link>
        </div>
        <p className="muted small">
          Email sending is not set up yet, so share the link yourself. Treat it like a password:
          anyone with it can join until it is used.
        </p>
      </div>
    );
  }

  return (
    <div
      className="grid"
      style={{ gridTemplateColumns: "minmax(0, 1.4fr) minmax(260px, 1fr)", alignItems: "start" }}
    >
      <form onSubmit={onSubmit} className="card stack">
        <label className="field">
          Work email
          <input className="input" type="email" name="email" required autoComplete="off" />
          {domain ? <span className="hint">Only @{domain} addresses can be invited.</span> : null}
        </label>
        <fieldset className="stack" style={{ border: 0, padding: 0, margin: 0 }}>
          <legend className="overline" style={{ marginBottom: 8 }}>
            Role
          </legend>
          {ROLES.map((r) => (
            <label key={r} className="radio-card">
              <input
                type="radio"
                name="role"
                value={r}
                checked={role === r}
                onChange={() => setRole(r)}
              />
              <span>
                <b>{ROLE_LABELS[r]}</b>
                {ROLE_DESCRIPTIONS[r]}
              </span>
            </label>
          ))}
        </fieldset>
        <label className="field">
          Personal note
          <textarea
            className="textarea"
            name="note"
            placeholder="Optional. Shown to them on the invite page."
          />
        </label>
        {state && !state.ok ? (
          <div className="notice err" role="alert">
            {state.message}
          </div>
        ) : null}
        <div className="row">
          <Link href="/settings" className="btn secondary">
            Cancel
          </Link>
          <Submit pending={pending} />
        </div>
      </form>
      <aside className="card stack" aria-live="polite">
        <h3>{ROLE_LABELS[role]} can</h3>
        <ul className="stack" style={{ listStyle: "none", padding: 0, margin: 0, gap: 6 }}>
          {caps.can.length ? (
            caps.can.map((t) => (
              <li key={t} className="check-row">
                <Badge good />
                {t}
              </li>
            ))
          ) : (
            <li className="muted small">View dashboards and reports only.</li>
          )}
          {caps.cannot.map((t) => (
            <li key={t} className="check-row muted">
              <Badge good={false} />
              {t}
            </li>
          ))}
        </ul>
        <p className="muted small">
          Every action they take is recorded in the audit log. You can change their role or remove
          access any time.
        </p>
      </aside>
    </div>
  );
}

function Badge({ good }: { good: boolean }) {
  return (
    <span
      className={`badge ${good ? "good" : "bad"}`}
      style={{ flex: "none" }}
      aria-label={good ? "Can" : "Cannot"}
    >
      {good ? "✓" : "✕"}
    </span>
  );
}
