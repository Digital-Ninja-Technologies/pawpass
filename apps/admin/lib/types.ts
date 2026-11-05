/** Row shapes of the admin_* views (see supabase/migrations/20261105140000_admin_console.sql). */
export interface MeRow {
  id: string;
  user_id: string;
  role: string;
  status: string;
  name: string | null;
}
export interface DirectoryRow {
  kind: "owner" | "partner";
  id: string;
  name: string;
  type: string;
  area: string | null;
  joined_at: string;
  status: string;
  pets: number;
  bookings: number;
  in_escrow_kobo: number;
  suspension_reason: string | null;
  user_id: string;
}
export interface KycRow {
  id: string;
  business_name: string;
  type: string;
  area: string | null;
  status: string;
  submitted_at: string | null;
  decided_at: string | null;
  decision_note: string | null;
  internal_note: string | null;
  kyc_checks: Record<string, boolean>;
  owner_user_id: string;
  owner_name: string | null;
}
export interface EscrowRow {
  id: string;
  ref: string;
  kind: string;
  amount_kobo: number;
  fee_kobo: number;
  status: string;
  release_after: string | null;
  created_at: string;
  payer_name: string | null;
  payee_name: string | null;
  subject: string;
  open_dispute_id: string | null;
}
export interface DisputeRow {
  id: string;
  ref: string;
  status: string;
  decision: string | null;
  decision_refund_kobo: number | null;
  decision_note: string | null;
  decided_at: string | null;
  reason: string;
  details: string | null;
  partner_response: string | null;
  due_at: string | null;
  created_at: string;
  escrow_id: string;
  escrow_kind: string;
  amount_kobo: number;
  escrow_status: string;
  buyer_name: string | null;
  partner_name: string | null;
  partner_verified: boolean;
  subject: string;
}
export interface ReportRow {
  target_type: string;
  target_id: string;
  report_count: number;
  first_reported_at: string;
  top_reason: string;
  is_open: boolean;
  last_status: string;
  action: string | null;
  summary: string | null;
  seller_name: string | null;
  seller_status: string | null;
  seller_age_days: number | null;
  price_kobo: number | null;
  avg_price_kobo: number | null;
}
export interface LostRow {
  id: string;
  pet_name: string;
  breed: string | null;
  species: string;
  status: string;
  radius_m: number;
  created_at: string;
  closes_at: string | null;
  description: string | null;
  owner_area: string | null;
  days_left: number | null;
  sightings: number;
  flag: string | null;
}
export interface QrRow {
  id: string;
  ref: string;
  status: string;
  created_at: string;
  shipped_at: string | null;
  owner_name: string | null;
  area: string | null;
  pet_name: string;
}
export interface SupportRow {
  id: string;
  ref: string;
  topic: string;
  subject: string;
  status: string;
  linked_type: string | null;
  linked_id: string | null;
  created_at: string;
  updated_at: string;
  user_name: string | null;
  first_message: string | null;
  last_reply_is_staff: boolean | null;
}
export interface SupportMessageRow {
  id: string;
  ticket_id: string;
  author_user_id: string | null;
  author_staff_id: string | null;
  body: string;
  internal: boolean;
  created_at: string;
}
export interface StaffRow {
  id: string;
  user_id: string;
  role: string;
  status: string;
  created_at: string;
  name: string | null;
}
export interface InviteRow {
  id: string;
  email: string;
  role: string;
  note: string | null;
  expires_at: string;
  accepted_at: string | null;
  revoked_at: string | null;
  created_at: string;
}
export interface AuditRow {
  id: string;
  at: string;
  action: string;
  target_type: string | null;
  target_id: string | null;
  details: Record<string, unknown>;
  staff_name: string | null;
}
export interface SettingsRow {
  booking_commission_bps: number;
  puppy_escrow_fee_bps: number;
  deposit_fraction: number;
  vet_check_hours: number;
  free_cancel_hours: number;
  kyc_target_hours: number;
  lost_radius_m: number;
  lost_autoclose_days: number;
  payout_weekday: number;
}
export interface PartnerDocRow {
  id: string;
  partner_account_id: string;
  kind: string;
  storage_path: string;
  status: string;
}
