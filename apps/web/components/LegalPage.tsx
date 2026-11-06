import type { ReactNode } from "react";
import type { LegalSection } from "@/lib/legal";
import { LEGAL_UPDATED } from "@/lib/legal";
import { CONTACT_EMAIL } from "@/lib/contact";
import { Footer } from "./Footer";
import { Header } from "./Header";

export function LegalPage({ title, intro, sections }: { title: string; intro: ReactNode; sections: LegalSection[] }) {
  return (
    <>
      <a className="skip" href="#main">
        Skip to content
      </a>
      <div className="pp">
        <Header base="/" />
        <main id="main" className="wrap legal">
          <h1 className="h2">{title}</h1>
          <p className="legal-meta">Last updated {LEGAL_UPDATED}</p>
          <p>{intro}</p>
          {sections.map((s) => (
            <section key={s.title}>
              <h2>{s.title}</h2>
              {s.body.map((p) => (
                <p key={p}>{p}</p>
              ))}
              {s.list ? (
                <ul>
                  {s.list.map((li) => (
                    <li key={li}>{li}</li>
                  ))}
                </ul>
              ) : null}
            </section>
          ))}
          <section>
            <h2>Contact us</h2>
            <p>
              {CONTACT_EMAIL ? (
                <>
                  Email <a href={`mailto:${CONTACT_EMAIL}`}>{CONTACT_EMAIL}</a>, or open Help in the app.
                </>
              ) : (
                "Open Help in the app and send us a message."
              )}
            </p>
          </section>
        </main>
        <Footer />
      </div>
    </>
  );
}
