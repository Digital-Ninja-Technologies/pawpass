import Image from "next/image";
import { WaitlistForm } from "@/components/WaitlistForm";

const pillars = [
  {
    title: "A passport that remembers",
    text: "Vaccines, treatments and weight in one private place. Reminders arrive before anything is due, and you can share records with your vet using a link that expires.",
    tag: "Health",
  },
  {
    title: "Trusted care, paid safely",
    text: "Book vets, groomers, trainers and boarding from verified partners. PawPass holds your payment until you confirm the visit.",
    tag: "Services",
  },
  {
    title: "Pets, people and neighbours",
    text: "Share your pet's profile, follow other pets, and chat in the app. Photos and posts stay under your control.",
    tag: "Community",
  },
  {
    title: "Buy and adopt with confidence",
    text: "Verified breeders and shelters, puppy sales held in escrow, and the passport moves to you at handover.",
    tag: "Trust",
  },
];

const steps = [
  {
    n: "1",
    title: "Make your pet's passport",
    text: "Add a name, breed and photo. It takes about two minutes and gives your pet a tag ID.",
  },
  {
    n: "2",
    title: "Add records and reminders",
    text: "Enter past vaccines or let your vet add them. We remind you by push, email or WhatsApp before the next one is due.",
  },
  {
    n: "3",
    title: "Book, share and stay safe",
    text: "Book trusted partners, share the passport at the clinic, and raise a lost pet alert in seconds if you ever need to.",
  },
];

const faqs = [
  {
    q: "What is PawPass?",
    a: "PawPass is an app for pet owners in Lagos. Every pet gets one passport with its identity, health records and history, plus a marketplace for trusted care and a community for lost and found.",
  },
  {
    q: "Is it free?",
    a: "The app is free for pet owners. Partners such as vets and groomers pay a small commission on completed bookings.",
  },
  {
    q: "How is my money kept safe?",
    a: "You pay through PawPass, not the partner. We hold the money until you confirm the visit, and if something goes wrong our team reviews the dispute before any payout is made.",
  },
  {
    q: "Who can see my pet's health records?",
    a: "Only you, by default. When you share with a vet, you choose what they can see and the link or QR code stops working after a short time. Records added by a verified vet carry a Vet verified badge.",
  },
  {
    q: "How are vets, breeders and shelters checked?",
    a: "Partners send ID, registration and facility documents, and our team reviews each application. They cannot go live until they are approved. We aim to answer every application within 48 hours.",
  },
  {
    q: "What happens if my pet goes missing?",
    a: "You raise an alert and people nearby are notified. Your phone number is never shown: anyone who spots your pet messages you through the app.",
  },
  {
    q: "When does PawPass open?",
    a: "We are opening in Lagos first. Join the waitlist and we will email you once, when it is ready.",
  },
];

function Logo() {
  return (
    <a href="#top" className="logo" aria-label="PawPass home">
      <span className="logo-mark" aria-hidden="true">
        <svg
          width="22"
          height="22"
          viewBox="0 0 24 24"
          fill="none"
          stroke="#fff"
          strokeWidth="1.8"
          strokeLinecap="round"
          strokeLinejoin="round"
        >
          <circle cx="7" cy="10" r="2" />
          <circle cx="17" cy="10" r="2" />
          <circle cx="10" cy="6" r="2" />
          <circle cx="14" cy="6" r="2" />
          <path d="M12 12c-3 0-5 3.5-5 5.5S9 20 12 20s5-.5 5-2.5S15 12 12 12z" />
        </svg>
      </span>
      PawPass
    </a>
  );
}

function PassportCard() {
  return (
    <aside className="passport" aria-label="Sample pet passport">
      <div className="passport-head">
        <span className="overline">Sample pet passport</span>
        <span className="chip good">✓ Vet verified</span>
      </div>
      <div className="passport-pet">
        <Image src="/photos/bingo.jpg" alt="" width={72} height={96} className="passport-photo" />
        <div>
          <p className="passport-name">Bingo</p>
          <p className="muted">Boerboel · Male · Born 14 Aug 2024</p>
          <p className="muted">Tag ID PP-4821-LK</p>
        </div>
      </div>
      <ul className="passport-list">
        <li>
          <span>
            <b>Rabies booster</b>
            <span className="muted">Due 12 Nov</span>
          </span>
          <span className="chip warn">Upcoming</span>
        </li>
        <li>
          <span>
            <b>DHPP vaccine</b>
            <span className="muted">12 Mar 2026 · Dr. Amina Bello</span>
          </span>
          <span className="chip good">✓ Vet verified</span>
        </li>
        <li>
          <span>
            <b>Weight</b>
            <span className="muted">41 kg</span>
          </span>
        </li>
      </ul>
    </aside>
  );
}

export default function Home() {
  return (
    <>
      <a className="skip" href="#main">
        Skip to content
      </a>
      <header className="site-header">
        <div className="wrap bar">
          <Logo />
          <nav aria-label="Main" className="nav">
            <a href="#features">Features</a>
            <a href="#how">How it works</a>
            <a href="#safety">Safety</a>
            <a href="#lost">Lost and found</a>
            <a href="#partners">Partners</a>
            <a href="#faq">FAQ</a>
          </nav>
          <a href="#join" className="btn small">
            Join the waitlist
          </a>
        </div>
      </header>

      <main id="main">
        <section id="top" className="hero">
          <div className="wrap hero-grid">
            <div className="hero-copy">
              <p className="overline">Coming soon to Lagos</p>
              <h1>Every pet&apos;s life, in one place.</h1>
              <p className="lead">
                PawPass is a free passport for your pet. Keep health records safe, book trusted vets
                and groomers, and get help from your neighbours if a pet ever goes missing.
              </p>
              <WaitlistForm source="hero" />
              <p className="fine">Free for pet owners. No spam: one email when we open.</p>
            </div>
            <div className="hero-visual">
              <div className="hero-photo">
                <Image
                  src="/photos/bingo.jpg"
                  alt="Bingo, a Boerboel, looking straight at the camera"
                  fill
                  priority
                  sizes="(max-width: 900px) 80vw, 420px"
                />
              </div>
              <PassportCard />
            </div>
          </div>
        </section>

        <section id="features" className="section">
          <div className="wrap">
            <p className="overline">Everything together</p>
            <h2>One app for the whole life of your pet</h2>
            <div className="cards four">
              {pillars.map((p) => (
                <article key={p.tag} className="card">
                  <span className="chip">{p.tag}</span>
                  <h3>{p.title}</h3>
                  <p>{p.text}</p>
                </article>
              ))}
            </div>
          </div>
        </section>

        <section id="how" className="section soft">
          <div className="wrap">
            <p className="overline">How it works</p>
            <h2>From first photo to peace of mind</h2>
            <ol className="steps">
              {steps.map((s) => (
                <li key={s.n}>
                  <span className="step-n" aria-hidden="true">
                    {s.n}
                  </span>
                  <h3>{s.title}</h3>
                  <p>{s.text}</p>
                </li>
              ))}
            </ol>
          </div>
        </section>

        <section id="safety" className="section">
          <div className="wrap split">
            <div>
              <p className="overline">Safety first</p>
              <h2>Your money and your pet&apos;s records stay protected</h2>
              <p className="lead">
                We built PawPass so you never have to trust a stranger with a transfer or a
                screenshot.
              </p>
              <ul className="ticks">
                <li>
                  <b>Money held until you confirm.</b> Pay through PawPass, and the partner is paid
                  after the visit.
                </li>
                <li>
                  <b>People review problems.</b> If something goes wrong, our team looks at both
                  sides before any money moves.
                </li>
                <li>
                  <b>Verified partners only.</b> Vets, breeders and shelters are checked before they
                  can go live.
                </li>
                <li>
                  <b>Private by default.</b> Health records are visible only to you until you share
                  them.
                </li>
              </ul>
            </div>
            <div className="photo-pair">
              <div className="photo tall">
                <Image
                  src="/photos/vet.jpg"
                  alt="A vet gently examining a dog's paw"
                  fill
                  sizes="(max-width: 900px) 45vw, 260px"
                />
              </div>
              <div className="photo tall offset">
                <Image
                  src="/photos/nala.jpg"
                  alt="Nala, a German Shepherd puppy, sitting on a pavement"
                  fill
                  sizes="(max-width: 900px) 45vw, 260px"
                />
              </div>
            </div>
          </div>
        </section>

        <section id="lost" className="section lost">
          <div className="wrap split reverse">
            <div className="photo wide">
              <Image
                src="/photos/bruno.jpg"
                alt="Bruno, a Jack Russell, looking up with his tongue out"
                fill
                sizes="(max-width: 900px) 90vw, 440px"
                style={{ objectPosition: "50% 62%" }}
              />
            </div>
            <div>
              <p className="overline warm">Lost and found</p>
              <h2>If your pet goes missing, your neighbours help</h2>
              <p className="lead">
                Raise an alert in seconds. People nearby are told, and anyone who sees your pet can
                message you in the app.
              </p>
              <ul className="ticks">
                <li>
                  <b>Alerts reach people nearby</b> and close by themselves after two weeks.
                </li>
                <li>
                  <b>A QR collar tag</b> lets anyone who finds your pet scan it and reach you.
                </li>
                <li>
                  <b>Your phone number stays private.</b> Finders use in app chat, never your
                  number.
                </li>
              </ul>
            </div>
          </div>
        </section>

        <section id="partners" className="section soft">
          <div className="wrap">
            <p className="overline">For partners</p>
            <h2>Grow your practice with PawPass</h2>
            <p className="lead narrow">
              Vets, groomers, trainers, boarding, breeders and shelters can reach pet owners who are
              ready to book, with payments handled for you and a Verified badge that builds trust.
            </p>
            <div className="photo-row">
              {[
                ["/photos/groomer.jpg", "A groomer trimming a small white dog"],
                ["/photos/trainer.jpg", "A trainer rewarding a black dog with a treat"],
                ["/photos/duke_kennel.jpg", "A puppy resting in a clean kennel"],
              ].map(([src, alt]) => (
                <div key={src} className="photo wide small">
                  <Image src={src!} alt={alt!} fill sizes="(max-width: 900px) 90vw, 340px" />
                </div>
              ))}
            </div>
            <div className="partner-cta">
              <p>
                <b>Want to be among the first partners?</b> Leave your email and we will contact you
                before launch.
              </p>
              <WaitlistForm source="partners" />
            </div>
          </div>
        </section>

        <section id="faq" className="section">
          <div className="wrap narrow-wrap">
            <p className="overline">Questions</p>
            <h2>Good to know</h2>
            <div className="faq">
              {faqs.map((f) => (
                <details key={f.q}>
                  <summary>{f.q}</summary>
                  <p>{f.a}</p>
                </details>
              ))}
            </div>
          </div>
        </section>

        <section id="join" className="cta">
          <div className="wrap cta-inner">
            <h2>Be first in line</h2>
            <p className="lead">
              Join the waitlist and give your pet their passport the day we open in Lagos.
            </p>
            <WaitlistForm source="footer" dark />
          </div>
        </section>
      </main>

      <footer className="site-footer">
        <div className="wrap foot">
          <Logo />
          <p>Made in Lagos by Digital Ninja Technologies. © 2026 PawPass.</p>
        </div>
      </footer>
    </>
  );
}
