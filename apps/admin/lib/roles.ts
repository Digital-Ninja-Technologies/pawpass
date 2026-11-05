/** Staff roles and what each may see and do. The database enforces the same rules
 * (RLS for reads, role checks inside the admin_* functions for writes); this file
 * only decides what the UI shows. Keep it in step with supabase/migrations. */
export const ROLES = [
  "full_admin",
  "payouts_disputes",
  "support_reports",
  "verifications",
  "read_only",
] as const;
export type Role = (typeof ROLES)[number];

export const ROLE_LABELS: Record<Role, string> = {
  full_admin: "Full admin",
  payouts_disputes: "Payouts & disputes",
  support_reports: "Support & reports",
  verifications: "Verifications",
  read_only: "Read only",
};

export const ROLE_DESCRIPTIONS: Record<Role, string> = {
  full_admin: "Everything, including settings, fees and team",
  payouts_disputes: "Escrow, refunds, payout runs, dispute decisions",
  support_reports: "Support inbox, reported content, lost & found, user look-up",
  verifications: "Review and approve partner documents",
  read_only: "View dashboards and reports, no actions",
};

export function isRole(value: unknown): value is Role {
  return typeof value === "string" && (ROLES as readonly string[]).includes(value);
}

export const SECTIONS = [
  "overview",
  "verifications",
  "disputes",
  "reports",
  "payouts",
  "users",
  "lost",
  "support",
  "settings",
] as const;
export type Section = (typeof SECTIONS)[number];

const everyone: Role[] = [...ROLES];
const SECTION_ACCESS: Record<Section, Role[]> = {
  overview: everyone,
  verifications: ["verifications", "read_only"],
  disputes: ["payouts_disputes", "read_only"],
  reports: ["support_reports", "read_only"],
  payouts: ["payouts_disputes", "read_only"],
  users: ["support_reports", "verifications", "read_only"],
  lost: ["support_reports", "read_only"],
  support: ["support_reports", "read_only"],
  settings: everyone,
};

/** Full admins can open everything. */
export function canView(role: Role, section: Section): boolean {
  return role === "full_admin" || SECTION_ACCESS[section].includes(role);
}

export const ACTIONS = [
  "review_partner",
  "decide_dispute",
  "prepare_payout",
  "resolve_report",
  "suspend_user",
  "lost_alerts",
  "support_reply",
  "edit_settings",
  "manage_team",
] as const;
export type Action = (typeof ACTIONS)[number];

const ACTION_ROLES: Record<Action, Role[]> = {
  review_partner: ["verifications"],
  decide_dispute: ["payouts_disputes"],
  prepare_payout: ["payouts_disputes"],
  resolve_report: ["support_reports"],
  suspend_user: ["support_reports"],
  lost_alerts: ["support_reports"],
  support_reply: ["support_reports"],
  edit_settings: [],
  manage_team: [],
};

/** Full admins can do everything; read only can do nothing. */
export function canDo(role: Role, action: Action): boolean {
  if (role === "full_admin") return true;
  return ACTION_ROLES[action].includes(role);
}

/** The "can / cannot" list shown when inviting someone. */
export function roleCapabilities(role: Role): { can: string[]; cannot: string[] } {
  const all: [Action, string][] = [
    ["review_partner", "Approve, reject or query partner applications"],
    ["decide_dispute", "Decide disputes and refund or release escrow money"],
    ["prepare_payout", "Prepare and approve the weekly payout run"],
    ["resolve_report", "Remove reported posts and listings"],
    ["suspend_user", "Suspend and restore accounts"],
    ["lost_alerts", "Manage lost alerts and QR tag orders"],
    ["support_reply", "Reply to support tickets"],
    ["edit_settings", "Change fees, policies and settings"],
    ["manage_team", "Invite and manage team members"],
  ];
  return {
    can: all.filter(([a]) => canDo(role, a)).map(([, t]) => t),
    cannot: all.filter(([a]) => !canDo(role, a)).map(([, t]) => t),
  };
}

/** The first page a role should land on after sign in. */
export function homeFor(): string {
  return "/";
}
