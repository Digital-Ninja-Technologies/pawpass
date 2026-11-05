export type Tone = "neutral" | "good" | "warn" | "bad" | "solid";

/** Badge colour for an escrow status. The word is always shown too, never colour alone. */
export function statusTone(status: string): Tone {
  return status === "ready" || status === "released"
    ? "good"
    : status === "paused"
      ? "warn"
      : status === "refunded" || status === "partially_refunded"
        ? "bad"
        : "neutral";
}
