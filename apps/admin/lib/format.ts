import { formatNaira } from "@pawpass/shared";

/** Money is stored as integer kobo. Shown as ₦15,000 (whole naira). */
export function formatKobo(kobo: number | string | null | undefined): string {
  if (kobo === null || kobo === undefined) return "₦0";
  return formatNaira(Number(kobo) / 100);
}

/** Compact form for dashboard tiles: ₦46.8M, ₦487.5k, ₦15,000. */
export function formatKoboShort(kobo: number | string | null | undefined): string {
  const naira = Number(kobo ?? 0) / 100;
  const abs = Math.abs(naira);
  if (abs >= 1_000_000) return `₦${trim(naira / 1_000_000)}M`;
  if (abs >= 100_000) return `₦${trim(naira / 1_000)}k`;
  return formatNaira(naira);
}

function trim(n: number): string {
  return n.toFixed(1).replace(/\.0$/, "");
}

/** Parses an amount typed in naira ("380,000" or "₦380000") into kobo. Returns null if invalid. */
export function parseNairaToKobo(input: string): number | null {
  const cleaned = input.replace(/[₦,\s]/g, "");
  if (!/^\d+(\.\d{1,2})?$/.test(cleaned)) return null;
  return Math.round(Number(cleaned) * 100);
}

export function hoursSince(iso: string | null | undefined, now: Date = new Date()): number {
  if (!iso) return 0;
  return Math.max(0, (now.getTime() - new Date(iso).getTime()) / 3_600_000);
}

/** "40 min", "5 hrs", "3 days". */
export function timeAgo(iso: string | null | undefined, now: Date = new Date()): string {
  if (!iso) return "";
  const minutes = Math.max(0, Math.round((now.getTime() - new Date(iso).getTime()) / 60_000));
  if (minutes < 1) return "just now";
  if (minutes < 60) return `${minutes} min`;
  const hours = Math.round(minutes / 60);
  if (hours < 48) return `${hours} ${hours === 1 ? "hr" : "hrs"}`;
  const days = Math.round(hours / 24);
  return `${days} days`;
}

const dateFmt = new Intl.DateTimeFormat("en-NG", {
  day: "numeric",
  month: "short",
  year: "numeric",
  timeZone: "Africa/Lagos",
});
const dateTimeFmt = new Intl.DateTimeFormat("en-NG", {
  day: "numeric",
  month: "short",
  hour: "2-digit",
  minute: "2-digit",
  hour12: false,
  timeZone: "Africa/Lagos",
});
const timeFmt = new Intl.DateTimeFormat("en-NG", {
  hour: "2-digit",
  minute: "2-digit",
  hour12: false,
  timeZone: "Africa/Lagos",
});

export const formatDate = (iso: string | null | undefined) =>
  iso ? dateFmt.format(new Date(iso)) : "";
export const formatDateTime = (iso: string | null | undefined) =>
  iso ? dateTimeFmt.format(new Date(iso)) : "";
export const formatTime = (iso: string | null | undefined) =>
  iso ? timeFmt.format(new Date(iso)) : "";

/** Time left against a target in hours. Negative means overdue. */
export function hoursLeft(
  submittedAt: string | null | undefined,
  targetHours: number,
  now: Date = new Date(),
): number {
  return Math.round(targetHours - hoursSince(submittedAt, now));
}

export function describeTimeLeft(hours: number): string {
  return hours >= 0 ? `${hours} hrs left on target` : `${Math.abs(hours)} hrs past target`;
}

/** Next date (Africa/Lagos not needed: run dates are plain dates) falling on ISO weekday 1-7, today included. */
export function nextWeekday(isoWeekday: number, from: Date = new Date()): Date {
  const d = new Date(Date.UTC(from.getUTCFullYear(), from.getUTCMonth(), from.getUTCDate()));
  const current = d.getUTCDay() === 0 ? 7 : d.getUTCDay();
  const add = (isoWeekday - current + 7) % 7;
  d.setUTCDate(d.getUTCDate() + add);
  return d;
}

export const toIsoDate = (d: Date) => d.toISOString().slice(0, 10);

export const WEEKDAYS = [
  "Monday",
  "Tuesday",
  "Wednesday",
  "Thursday",
  "Friday",
  "Saturday",
  "Sunday",
];

export function initials(name: string | null | undefined): string {
  const parts = (name ?? "").trim().split(/\s+/).filter(Boolean);
  if (parts.length === 0) return "?";
  return (
    (parts[0]?.[0] ?? "") + (parts.length > 1 ? (parts[parts.length - 1]?.[0] ?? "") : "")
  ).toUpperCase();
}

/** "Rottweiler puppies" style: lower-case words, first letter upper. */
export function sentence(value: string | null | undefined): string {
  const s = (value ?? "").replace(/_/g, " ").trim();
  return s ? s[0]!.toUpperCase() + s.slice(1) : "";
}
