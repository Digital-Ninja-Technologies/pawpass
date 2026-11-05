import type { KeyboardEvent } from "react";

/** Arrow key navigation for a group of buttons (tabs, radios): moves focus and selects, wrapping at the ends. */
export function arrowKeys(e: KeyboardEvent<HTMLElement>, selector: string) {
  const forward = e.key === "ArrowRight" || e.key === "ArrowDown";
  const back = e.key === "ArrowLeft" || e.key === "ArrowUp";
  if (!forward && !back) return;
  const items = Array.from(e.currentTarget.querySelectorAll<HTMLButtonElement>(selector));
  const index = items.indexOf(document.activeElement as HTMLButtonElement);
  if (index < 0) return;
  e.preventDefault();
  const next = items[(index + (forward ? 1 : -1) + items.length) % items.length];
  next?.focus();
  next?.click();
}
