import Link from "next/link";
import type { ReactNode } from "react";

export function PageHeader({
  title,
  subtitle,
  crumbs,
  actions,
}: {
  title: string;
  subtitle?: ReactNode;
  crumbs?: ReactNode;
  actions?: ReactNode;
}) {
  return (
    <header className="page-head">
      <div>
        {crumbs ? <div className="crumbs">{crumbs}</div> : null}
        <h1>{title}</h1>
        {subtitle ? <p>{subtitle}</p> : null}
      </div>
      {actions ? <div className="head-actions">{actions}</div> : null}
    </header>
  );
}

export type Tone = "neutral" | "good" | "warn" | "bad" | "solid";
export function Badge({ children, tone = "neutral" }: { children: ReactNode; tone?: Tone }) {
  return <span className={`badge ${tone === "neutral" ? "" : tone}`}>{children}</span>;
}

export function Stat({
  label,
  value,
  note,
}: {
  label: string;
  value: ReactNode;
  note?: ReactNode;
}) {
  return (
    <div className="card stat">
      <span className="label">{label}</span>
      <span className="value">{value}</span>
      {note ? <span className="note">{note}</span> : null}
    </div>
  );
}

export interface TabItem {
  label: string;
  href: string;
  active: boolean;
  count?: number;
}
export function Tabs({ items, label }: { items: TabItem[]; label: string }) {
  return (
    <nav className="tabs" aria-label={label}>
      {items.map((t) => (
        <Link
          key={t.href}
          href={t.href}
          className="tab"
          aria-current={t.active ? "true" : undefined}
        >
          {t.label}
          {t.count !== undefined ? <span>({t.count})</span> : null}
        </Link>
      ))}
    </nav>
  );
}

export function Empty({ children }: { children: ReactNode }) {
  return <div className="empty">{children}</div>;
}

export function Notice({
  tone = "info",
  children,
}: {
  tone?: "ok" | "err" | "info";
  children: ReactNode;
}) {
  return (
    <div className={`notice ${tone}`} role={tone === "err" ? "alert" : "status"}>
      {children}
    </div>
  );
}

/** Builds a URL that keeps the current filters and changes one or more params. */
export function href(path: string, params: Record<string, string | undefined | null>): string {
  const q = new URLSearchParams();
  for (const [k, v] of Object.entries(params)) if (v) q.set(k, v);
  const s = q.toString();
  return s ? `${path}?${s}` : path;
}

export function DisabledAction({ children, reason }: { children: ReactNode; reason: string }) {
  return (
    <button
      type="button"
      className="btn secondary small"
      disabled
      title={reason}
      aria-label={`${children}: ${reason}`}
    >
      {children}
    </button>
  );
}
