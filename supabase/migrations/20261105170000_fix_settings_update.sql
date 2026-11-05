-- Supabase runs with pg-safeupdate, which rejects an UPDATE that has no WHERE clause.
-- admin_update_settings updated the single settings row without one. Add a WHERE on the
-- singleton column (always true for the one row).
create or replace function public.admin_update_settings(p_values jsonb) returns void
language plpgsql security definer
set search_path = ''
as $$
declare
  v_old jsonb;
  v_new jsonb;
begin
  perform private.require_staff(array['full_admin']);
  select to_jsonb(s) into v_old from public.settings s;

  update public.settings set
    booking_commission_bps = coalesce((p_values ->> 'booking_commission_bps')::int, booking_commission_bps),
    puppy_escrow_fee_bps   = coalesce((p_values ->> 'puppy_escrow_fee_bps')::int, puppy_escrow_fee_bps),
    deposit_fraction       = coalesce((p_values ->> 'deposit_fraction')::numeric, deposit_fraction),
    vet_check_hours        = coalesce((p_values ->> 'vet_check_hours')::int, vet_check_hours),
    free_cancel_hours      = coalesce((p_values ->> 'free_cancel_hours')::int, free_cancel_hours),
    kyc_target_hours       = coalesce((p_values ->> 'kyc_target_hours')::int, kyc_target_hours),
    lost_radius_m          = coalesce((p_values ->> 'lost_radius_m')::int, lost_radius_m),
    lost_autoclose_days    = coalesce((p_values ->> 'lost_autoclose_days')::int, lost_autoclose_days),
    payout_weekday         = coalesce((p_values ->> 'payout_weekday')::smallint, payout_weekday)
  where singleton;

  select to_jsonb(s) into v_new from public.settings s;
  perform private.write_audit('settings.update', 'settings', null, jsonb_build_object('before', v_old - 'id', 'after', v_new - 'id'));
end;
$$;
