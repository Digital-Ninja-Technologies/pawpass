"use client";

import { ActionForm, SubmitButton } from "@/components/ActionForm";
import { revokeInvite, setStaffRole, setStaffStatus } from "@/lib/actions/settings";
import { ROLES, ROLE_LABELS } from "@/lib/roles";

export function StaffControls({
  staffId,
  role,
  status,
}: {
  staffId: string;
  role: string;
  status: string;
}) {
  return (
    <div className="row">
      <ActionForm action={setStaffRole} className="row">
        <input type="hidden" name="staff" value={staffId} />
        <select
          className="select"
          name="role"
          defaultValue={role}
          aria-label="Role"
          style={{ minHeight: 36, width: "auto" }}
        >
          {ROLES.map((r) => (
            <option key={r} value={r}>
              {ROLE_LABELS[r]}
            </option>
          ))}
        </select>
        <SubmitButton small variant="secondary">
          Save role
        </SubmitButton>
      </ActionForm>
      <ActionForm action={setStaffStatus} className="row">
        <input type="hidden" name="staff" value={staffId} />
        <input type="hidden" name="status" value={status === "active" ? "suspended" : "active"} />
        <SubmitButton
          small
          variant="secondary"
          confirm={status === "active" ? "Suspend this team member's access?" : undefined}
        >
          {status === "active" ? "Suspend" : "Restore"}
        </SubmitButton>
      </ActionForm>
    </div>
  );
}

export function RevokeInvite({ inviteId }: { inviteId: string }) {
  return (
    <ActionForm action={revokeInvite} className="row">
      <input type="hidden" name="invite" value={inviteId} />
      <SubmitButton small variant="secondary" confirm="Revoke this invite? The link stops working.">
        Revoke
      </SubmitButton>
    </ActionForm>
  );
}
