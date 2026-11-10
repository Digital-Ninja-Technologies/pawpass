import type { Metadata } from "next";
import { redirect } from "next/navigation";
import { createClient } from "@/lib/supabase/server";
import { Icon } from "@/components/icons";
import { LoginForm } from "./LoginForm";
import type { MeRow } from "@/lib/types";

export const metadata: Metadata = { title: "Sign in" };

export default async function LoginPage({
  searchParams,
}: {
  searchParams: Promise<{ next?: string; error?: string }>;
}) {
  const { next, error } = await searchParams;

  // Already signed in as staff: go straight in.
  const supabase = await createClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();
  if (user) {
    const { data: me } = await supabase.from("admin_me_v").select("*").maybeSingle<MeRow>();
    if (me?.status === "active") redirect("/");
  }

  return (
    <div className="auth">
      <section
        className="auth-hero"
        aria-label="PawPass admin"
        style={{ backgroundImage: "url(/bingo.jpg)" }}
      >
        <div className="row" style={{ gap: 12 }}>
          <span
            className="brand-mark"
            style={{ background: "#fff", width: 44, height: 44, borderRadius: 12 }}
            aria-hidden="true"
          >
            <Icon name="paw" size={24} stroke="#0e6b63" />
          </span>
          <span className="brand-name" style={{ fontSize: 22 }}>
            OurPawPass
            <span className="brand-sub" style={{ color: "#fff", opacity: 0.9 }}>
              ADMIN CONSOLE
            </span>
          </span>
        </div>
        <div className="stack" style={{ gap: 12 }}>
          <h1>Keep every pet, payment and partner safe.</h1>
          <p style={{ fontSize: 16, opacity: 0.95, maxWidth: 460 }}>
            Verifications, disputes, reports and payouts for the PawPass ops team.
          </p>
        </div>
      </section>
      <main className="auth-main">
        <div className="auth-box">
          <h2 style={{ fontSize: 30 }}>Sign in</h2>
          {error === "no-access" ? (
            <div className="notice err" role="alert">
              This account does not have admin access. Ask your team lead for an invite.
            </div>
          ) : null}
          <LoginForm next={next ?? ""} />
          <div className="notice info" style={{ display: "flex", gap: 10 }}>
            <Icon name="lock" size={16} strokeWidth={2} style={{ flex: "none", marginTop: 2 }} />
            <span>Every sign in and action is logged. Lost access? Contact your team lead.</span>
          </div>
        </div>
      </main>
    </div>
  );
}
