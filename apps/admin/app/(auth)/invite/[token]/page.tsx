import type { Metadata } from "next";
import { createClient } from "@/lib/supabase/server";
import { ROLE_LABELS, isRole } from "@/lib/roles";
import { formatDateTime } from "@/lib/format";
import { Icon } from "@/components/icons";
import { AcceptForm } from "./AcceptForm";

export const metadata: Metadata = { title: "Join the team", robots: { index: false } };

export default async function AcceptInvitePage({ params }: { params: Promise<{ token: string }> }) {
  const { token } = await params;
  const supabase = await createClient();
  const { data } = await supabase.rpc("staff_invite_preview", { p_token: token });
  const invite = Array.isArray(data)
    ? (data[0] as
        | {
            email: string;
            role: string;
            note: string | null;
            expires_at: string;
            inviter_name: string | null;
          }
        | undefined)
    : undefined;

  return (
    <div className="auth">
      <main className="auth-main" style={{ flexBasis: "100%" }}>
        <div className="auth-box">
          <div className="row" style={{ gap: 12 }}>
            <span className="brand-mark" aria-hidden="true">
              <Icon name="paw" size={20} stroke="#fff" />
            </span>
            <span className="brand-name" style={{ color: "var(--ink)" }}>
              OurPawPass
              <span className="brand-sub" style={{ color: "var(--primary-text)" }}>
                ADMIN
              </span>
            </span>
          </div>
          {invite ? (
            <>
              <div className="stack" style={{ gap: 8 }}>
                <h1>Join the OurPawPass team</h1>
                <p className="muted">
                  <b style={{ color: "var(--ink)" }}>{invite.inviter_name || "A team lead"}</b>{" "}
                  invited you as{" "}
                  <b style={{ color: "var(--ink)" }}>
                    {isRole(invite.role) ? ROLE_LABELS[invite.role] : invite.role}
                  </b>
                  .
                </p>
                {invite.note ? <div className="quote">“{invite.note}”</div> : null}
              </div>
              <AcceptForm token={token} email={invite.email} />
              <p className="muted small">
                This invite expires {formatDateTime(invite.expires_at)}. Not expecting it? Ignore
                this page; nothing is created until you accept.
              </p>
            </>
          ) : (
            <div className="stack">
              <h1>This invite is not valid</h1>
              <p className="muted">
                It may have expired, been used, or been revoked. Ask your team lead to send a new
                one.
              </p>
            </div>
          )}
        </div>
      </main>
    </div>
  );
}
