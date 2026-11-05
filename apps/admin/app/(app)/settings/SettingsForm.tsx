"use client";

import { ActionForm, SubmitButton } from "@/components/ActionForm";
import { updateSettings } from "@/lib/actions/settings";
import { WEEKDAYS } from "@/lib/format";
import type { SettingsRow } from "@/lib/types";

const pct = (bps: number) => String(bps / 100);

export function SettingsForm({ s, canEdit }: { s: SettingsRow; canEdit: boolean }) {
  const deposit = String(Math.round(Number(s.deposit_fraction) * 10000) / 100);
  const f = (name: string, label: string, value: string, hint?: string, step = "any") => (
    <label className="field">
      {label}
      <input
        className="input"
        name={name}
        defaultValue={value}
        inputMode="decimal"
        step={step}
        disabled={!canEdit}
        required
      />
      {hint ? <span className="hint">{hint}</span> : null}
    </label>
  );
  return (
    <ActionForm action={updateSettings}>
      <div className="grid two">
        {f("commission", "Booking commission (%)", pct(s.booking_commission_bps))}
        {f("escrow_fee", "Puppy sale escrow fee (%)", pct(s.puppy_escrow_fee_bps))}
        {f(
          "deposit",
          "Puppy deposit share (%)",
          deposit,
          "One third is 33.33. Leave it alone to keep exactly one third.",
        )}
        <input type="hidden" name="deposit_initial" value={deposit} />
        {f("vet_check_hours", "Vet check window (hours)", String(s.vet_check_hours))}
        {f("free_cancel_hours", "Free cancellation (hours before)", String(s.free_cancel_hours))}
        {f("kyc_target_hours", "Verification target (hours)", String(s.kyc_target_hours))}
        {f("lost_radius_km", "Lost alert default radius (km)", String(s.lost_radius_m / 1000))}
        {f("lost_autoclose_days", "Lost alert auto close (days)", String(s.lost_autoclose_days))}
        <label className="field">
          Payout day
          <select
            className="select"
            name="payout_weekday"
            defaultValue={String(s.payout_weekday)}
            disabled={!canEdit}
          >
            {WEEKDAYS.map((d, i) => (
              <option key={d} value={i + 1}>
                {d}
              </option>
            ))}
          </select>
        </label>
      </div>
      {canEdit ? (
        <div>
          <SubmitButton confirm="Save these settings? They apply to new bookings and listings.">
            Save changes
          </SubmitButton>
        </div>
      ) : (
        <p className="muted small">Only full admins can change settings.</p>
      )}
    </ActionForm>
  );
}
