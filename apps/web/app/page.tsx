import { Faq } from "@/components/Faq";
import { FeatureTabs } from "@/components/FeatureTabs";
import { Header } from "@/components/Header";
import { Hero } from "@/components/Hero";
import { LostDemo } from "@/components/LostDemo";
import { OnboardingDemo } from "@/components/OnboardingDemo";
import { StoreButtons } from "@/components/StoreButtons";
import { PawFilled } from "@/components/icons";
import { CITIES } from "@/lib/content";
import { AGENCY_NAME, AGENCY_URL } from "@/lib/site";
import { STORES_LIVE } from "@/lib/stores";

const PAINS = [
  {
    q: "“Where did I keep that vaccine card?”",
    t: "Every record, in your phone",
    b: "Snap the old paper card once. We set the reminders for boosters, deworming and flea treatment.",
  },
  {
    q: "“Which vet is open at this hour?”",
    t: "Emergency vets, one tap",
    b: "See clinics open near you right now, call them, and send your pet's history before you arrive.",
  },
  {
    q: "“Is this Instagram breeder legit?”",
    t: "Verified breeders, safe payment",
    b: "We check every breeder. Your money stays on hold until you meet your puppy and a vet checks them.",
  },
];

const STEPS = [
  {
    n: "1",
    color: "#0e6b63",
    t: "Download PawPass",
    d: "Free on iPhone and Android. Sign in with your email, no password.",
  },
  {
    n: "2",
    color: "#b4501c",
    t: "Add your pet",
    d: "Photo, name, breed and past vaccines. Their passport is ready.",
  },
  {
    n: "3",
    color: "#23407a",
    t: "Relax",
    d: "Reminders arrive on time, care is a tap away, and help is nearby if they get lost.",
  },
];

const PARTNER_STEPS = [
  "Download PawPass and sign up with your email",
  "Go to Profile and tap “Become a partner”",
  "Add your business details and ID, and we verify you",
];

export default function Home() {
  return (
    <>
      <a className="skip" href="#main">
        Skip to content
      </a>
      <div className="pp">
        <Header />

        <main id="main">
          <Hero />

          <section aria-label="Cities we serve" className="marquee">
            <div className="marquee-track pp-marquee">
              {[0, 1].map((copy) =>
                CITIES.flatMap((city) => [
                  <span key={`${copy}-${city}`} aria-hidden={copy === 1 ? true : undefined}>
                    {city}
                  </span>,
                  <span key={`${copy}-${city}-paw`} className="paw" aria-hidden="true">
                    <PawFilled size={20} />
                  </span>,
                ]),
              )}
            </div>
          </section>

          <section className="wrap pains">
            <h2 className="h2">Pet parenting in Lagos and beyond, minus the stress.</h2>
            <div className="pain-row">
              {PAINS.map((p) => (
                <article key={p.t} className="pain">
                  <p className="q">{p.q}</p>
                  <h3>{p.t}</h3>
                  <p className="b">{p.b}</p>
                </article>
              ))}
            </div>
          </section>

          <FeatureTabs />

          <section id="lost" className="lost">
            <div className="wrap lost-in">
              <div className="lost-copy">
                <span className="eyebrow">LOST &amp; FOUND</span>
                <h2 className="h2">If they ever wander off, the whole neighbourhood helps.</h2>
                <p className="b">
                  Report a lost pet and everyone within 5 km gets an alert with a photo. Anyone who
                  scans the PawPass collar tag can reach you in the app. Your phone number stays
                  private.
                </p>
                <p className="hint">Try it: tap the collar tag.</p>
              </div>
              <LostDemo />
            </div>
          </section>

          <section className="wrap steps">
            <h2 className="h2">Set up in 2 minutes</h2>
            <ol className="step-row">
              {STEPS.map((s) => (
                <li key={s.n} className="step">
                  <span className="n" style={{ color: s.color }} aria-hidden="true">
                    {s.n}
                  </span>
                  <b>{s.t}</b>
                  <span className="d">{s.d}</span>
                </li>
              ))}
            </ol>
          </section>

          <section id="partners" className="wrap partners">
            <div className="partners-in">
              <div className="partners-copy">
                <span className="eyebrow">
                  FOR VETS, GROOMERS, TRAINERS, BREEDERS &amp; SHELTERS
                </span>
                <h2>Become a partner</h2>
                <p className="b">
                  Get bookings and enquiries from pet owners near you, with weekly payouts every
                  Monday and a verified badge owners trust.
                </p>
                <ol>
                  {PARTNER_STEPS.map((t, i) => (
                    <li key={t}>
                      <span className="n" aria-hidden="true">
                        {i + 1}
                      </span>
                      {t}
                    </li>
                  ))}
                </ol>
              </div>
              <div className="partners-cta">
                <a href="#download" className="btn-green">
                  Download the app to join
                </a>
                <small>Free to join · verification takes up to 48 hours</small>
              </div>
            </div>
          </section>

          <Faq />

          <section id="download" className="download">
            <div className="wrap download-in">
              <div className="download-copy">
                <h2>Your pet deserves a passport.</h2>
                <p className="b">
                  Download free for iPhone and Android. Want a peek first? Watch the setup play in
                  the phone.
                </p>
                <div className="stores">
                  <StoreButtons light />
                </div>
                {STORES_LIVE ? null : (
                  <p className="stores-note">
                    PawPass is not in the app stores yet. The buttons will go live at launch.
                  </p>
                )}
              </div>
              <div className="download-demo">
                <OnboardingDemo />
              </div>
            </div>
          </section>
        </main>

        <footer className="wrap footer">
          <span>
            <b>PawPass</b> · a{" "}
            {AGENCY_URL ? (
              <a href={AGENCY_URL} target="_blank" rel="noopener noreferrer">
                {AGENCY_NAME}
                <span className="sr-only"> (opens in a new tab)</span>
              </a>
            ) : (
              AGENCY_NAME
            )}{" "}
            product · Lagos, Nigeria
          </span>
        </footer>
      </div>
    </>
  );
}
