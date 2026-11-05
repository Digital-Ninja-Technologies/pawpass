"use client";

import Image from "next/image";
import { useEffect, useRef, useState, type ReactNode } from "react";
import { PawOutline } from "./icons";

/**
 * A self-playing preview of the real onboarding flow (Welcome to Passport ready) inside a phone.
 * It types, taps and moves on by itself, then loops. Nothing is sent or stored, and there is a
 * pause button (and no autoplay at all for people who ask for reduced motion).
 */

const TICK_MS = 100;

type Scene = { name: string; dur: number; press?: number };

// Durations are in ticks (100 ms). `press` is when the main button is tapped, just before the scene ends.
const SCENES: Scene[] = [
  { name: "Welcome", dur: 30, press: 26 },
  { name: "Sign up", dur: 44, press: 40 },
  { name: "Verify", dur: 42, press: 38 },
  { name: "Account type", dur: 26, press: 22 },
  { name: "Profile", dur: 42, press: 38 },
  { name: "Add pet", dur: 31, press: 27 },
  { name: "Health history", dur: 32, press: 28 },
  { name: "Reminders", dur: 28, press: 24 },
  { name: "Passport ready", dur: 45 },
];
const STARTS = SCENES.reduce<number[]>(
  (acc, s, i) => [...acc, i === 0 ? 0 : acc[i - 1] + SCENES[i - 1].dur],
  [],
);
const TOTAL = SCENES.reduce((n, s) => n + s.dur, 0);
const LAST = SCENES.length - 1;

function sceneAt(t: number) {
  let i = SCENES.length - 1;
  while (i > 0 && t < STARTS[i]) i--;
  return { i, lt: t - STARTS[i] };
}

/** The part of `text` typed by local tick `lt`, starting at `start`, at about six characters a second. */
function typed(text: string, lt: number, start: number) {
  return text.slice(0, Math.max(0, Math.floor((lt - start) * 0.6)));
}

const SUMMARY =
  "Animated preview of the PawPass setup: welcome, sign up with your email, confirm the code, choose an account type, add your profile, add your first pet, add health history, turn on reminders, and your pet's passport is ready.";

function Field({ label, value, active }: { label: string; value: string; active: boolean }) {
  return (
    <div>
      <p className="ob-label">{label}</p>
      <div className={`ob-input${active ? " focus" : ""}`}>
        {value}
        {active ? <span className="ob-caret" /> : null}
      </div>
    </div>
  );
}

function Opt({ on, title, sub }: { on: boolean; title: string; sub: string }) {
  return (
    <div className={`ob-opt${on ? " on" : ""}`}>
      <span className={`ob-check${on ? " on" : ""}`}>{on ? "✓" : ""}</span>
      <span>
        <b>{title}</b>
        <small>{sub}</small>
      </span>
    </div>
  );
}

function Screen({ i, lt }: { i: number; lt: number }) {
  const press = SCENES[i].press;
  const pressed = press !== undefined && lt >= press;
  const btn = (label: string) => <div className={`ob-btn${pressed ? " press" : ""}`}>{label}</div>;
  let body: ReactNode;
  let cta: ReactNode = btn("Continue");

  switch (i) {
    case 0:
      body = (
        <div className="ob-welcome">
          <span className="ob-logo">
            <PawOutline size={30} />
          </span>
          <h3 className="ob-h ob-h-lg">
            Every pet&apos;s life,
            <br />
            in one place.
          </h3>
          <p className="ob-p">
            Health records and reminders, trusted vets and groomers, a community nearby, and
            verified breeders.
          </p>
        </div>
      );
      cta = (
        <>
          {btn("Get started")}
          <span className="ob-link">I already have an account</span>
        </>
      );
      break;
    case 1: {
      const v = typed("tolu@example.com", lt, 6);
      body = (
        <>
          <h3 className="ob-h">What&apos;s your email?</h3>
          <p className="ob-p">
            We&apos;ll email you a 6-digit code to sign in. No password needed.
          </p>
          <Field label="Email address" value={v} active={lt >= 4 && lt < 38} />
        </>
      );
      cta = btn("Send code");
      break;
    }
    case 2: {
      const shown = [6, 11, 16, 21, 26, 31].map((s) => lt >= s);
      body = (
        <>
          <h3 className="ob-h">Enter the code</h3>
          <p className="ob-p">Sent to tolu@example.com</p>
          <div className="ob-code">
            {["4", "8", "2", "1", "7", "6"].map((d, k) => (
              <span key={k} className={shown[k] ? "on" : ""}>
                {shown[k] ? d : ""}
              </span>
            ))}
          </div>
          <p className="ob-fine">Check spam if it&apos;s not there.</p>
        </>
      );
      cta = btn("Verify");
      break;
    }
    case 3:
      body = (
        <>
          <h3 className="ob-h">How will you use PawPass?</h3>
          <p className="ob-p">Pick all that apply. You can add more later.</p>
          <div className="ob-list">
            <Opt on={lt >= 8} title="Pet owner" sub="Track health, book care, join the community" />
            <Opt
              on={false}
              title="Vet or service provider"
              sub="Clinics, groomers, trainers, boarding"
            />
            <Opt on={false} title="Breeder" sub="List litters with verified passports" />
            <Opt on={false} title="Shelter or rescue" sub="Rehome pets and screen adopters" />
          </div>
        </>
      );
      break;
    case 4:
      body = (
        <>
          <h3 className="ob-h">Tell us about you</h3>
          <div className="ob-two">
            <Field label="First name" value={typed("Tolu", lt, 4)} active={lt >= 3 && lt < 12} />
            <Field
              label="Last name"
              value={typed("Adeyemi", lt, 12)}
              active={lt >= 12 && lt < 24}
            />
          </div>
          <Field label="Your area" value={typed("Lekki", lt, 25)} active={lt >= 24 && lt < 36} />
          <p className="ob-fine">
            Your area helps us show nearby vets and lost-pet alerts. We never show your exact
            address.
          </p>
        </>
      );
      break;
    case 5:
      body = (
        <>
          <h3 className="ob-h">Add your first pet</h3>
          <p className="ob-p">This creates their Pet Passport.</p>
          <p className="ob-label">Species</p>
          <div className="ob-seg">
            <span className={lt >= 5 ? "on" : ""}>Dog</span>
            <span>Cat</span>
            <span>Other</span>
          </div>
          <Field label="Pet's name" value={typed("Bingo", lt, 8)} active={lt >= 7 && lt < 18} />
          <p className="ob-label">Sex</p>
          <div className="ob-seg">
            <span className={lt >= 20 ? "on" : ""}>Male</span>
            <span>Female</span>
          </div>
        </>
      );
      break;
    case 6:
      body = (
        <>
          <h3 className="ob-h">Bingo&apos;s health so far</h3>
          <p className="ob-p">Add past vaccines so we can schedule what&apos;s next.</p>
          <div className="ob-scan">
            <b>Scan vaccine card</b>
            <small>Snap the paper card, we&apos;ll read the dates</small>
          </div>
          <div className="ob-list">
            <Opt
              on={lt >= 8}
              title="DHPP (5-in-1)"
              sub={lt >= 8 ? "Last given 12 Mar 2026" : "Not added"}
            />
            <Opt
              on={lt >= 14}
              title="Rabies"
              sub={lt >= 14 ? "Last given 12 Nov 2025" : "Not added"}
            />
            <Opt
              on={lt >= 20}
              title="Deworming"
              sub={lt >= 20 ? "Last given 20 Oct 2026" : "Not added"}
            />
            <Opt on={false} title="Tick & flea treatment" sub="Not added" />
          </div>
        </>
      );
      cta = btn("Save health history");
      break;
    case 7:
      body = (
        <>
          <h3 className="ob-h">Never miss a dose</h3>
          <p className="ob-p">
            Here&apos;s Bingo&apos;s suggested schedule. We&apos;ll remind you 7 days and 1 day
            before.
          </p>
          <ul className="ob-sched">
            {[
              ["NOV", "12", "Rabies booster", "Yearly · due in 7 days"],
              ["JAN", "20", "Deworming", "Every 3 months"],
              ["MAR", "12", "DHPP booster", "Yearly"],
            ].map(([m, d, t, s]) => (
              <li key={t}>
                <span className="ob-date">
                  <small>{m}</small>
                  {d}
                </span>
                <span>
                  <b>{t}</b>
                  <small>{s}</small>
                </span>
              </li>
            ))}
          </ul>
          <p className="ob-label">Remind me by</p>
          <div className="ob-chips">
            <span className={lt >= 8 ? "on" : ""}>App notifications</span>
            <span className={lt >= 14 ? "on" : ""}>WhatsApp</span>
            <span>Email</span>
          </div>
        </>
      );
      cta = btn("Turn on reminders");
      break;
    default:
      body = (
        <div className="ob-done">
          <span className="ob-tick">✓</span>
          <h3 className="ob-h">Bingo&apos;s passport is ready</h3>
          <p className="ob-p">3 records saved and reminders are on.</p>
          <div className="ob-pass">
            <Image src="/photos/bingo.jpg" alt="" width={52} height={52} className="ob-pet" />
            <span>
              <b>Bingo</b>
              <small>Dog · Male</small>
              <small>Tag ID PP-4821-LK</small>
            </span>
          </div>
          <div className="ob-qr">
            <b>Get a QR collar tag</b>
            <small>Anyone who finds Bingo can reach you safely</small>
          </div>
        </div>
      );
      cta = (
        <div className="ob-btn alt">
          <span>Go to home</span>
        </div>
      );
  }

  return (
    <div className="ob-screen">
      <div className="ob-top">
        {i > 0 && i < LAST ? <span className="ob-back">‹</span> : <span className="ob-back-gap" />}
        {i > 0 && i < LAST ? (
          <span className="ob-prog">
            {SCENES.slice(1, LAST).map((s, k) => (
              <i key={s.name} className={k < i ? "on" : ""} />
            ))}
          </span>
        ) : null}
        {i === 6 ? <span className="ob-skip">Skip</span> : <span className="ob-back-gap" />}
      </div>
      <div className="ob-body" key={i}>
        {body}
      </div>
      <div className="ob-cta">{cta}</div>
    </div>
  );
}

export function OnboardingDemo() {
  const rootRef = useRef<HTMLElement>(null);
  const [t, setT] = useState(0);
  const [playing, setPlaying] = useState(true);
  const [visible, setVisible] = useState(false);
  const [tabHidden, setTabHidden] = useState(false);

  // Reduced motion: no autoplay. Start paused on a finished first screen; the buttons step through.
  useEffect(() => {
    if (window.matchMedia("(prefers-reduced-motion: reduce)").matches) {
      setPlaying(false);
      setT(SCENES[0].dur - 2);
    }
  }, []);

  // Only run while on screen and the tab is in front.
  useEffect(() => {
    const el = rootRef.current;
    if (!el) return;
    const io = new IntersectionObserver(([e]) => setVisible(e.isIntersecting), { threshold: 0.25 });
    io.observe(el);
    const onVis = () => setTabHidden(document.hidden);
    document.addEventListener("visibilitychange", onVis);
    return () => {
      io.disconnect();
      document.removeEventListener("visibilitychange", onVis);
    };
  }, []);

  const running = playing && visible && !tabHidden;
  useEffect(() => {
    if (!running) return;
    const id = setInterval(() => setT((v) => (v + 1) % TOTAL), TICK_MS);
    return () => clearInterval(id);
  }, [running]);

  const { i, lt } = sceneAt(t);
  const goTo = (n: number) => setT(STARTS[n] + SCENES[n].dur - 2);

  return (
    <section ref={rootRef} className="ob" aria-label="PawPass setup preview" data-scene={i}>
      <p className="sr-only">{SUMMARY}</p>
      <div className="phone ob-phone" aria-hidden="true">
        <Screen i={i} lt={lt} />
      </div>
      <p className="ob-caption" aria-hidden="true">
        {SCENES[i].name} · {i + 1}/{SCENES.length}
      </p>
      <div className="ob-ctrl">
        {!playing ? (
          <button
            type="button"
            onClick={() => goTo((i + LAST) % SCENES.length)}
            aria-label="Previous step"
          >
            ‹
          </button>
        ) : null}
        <button
          type="button"
          className="ob-pp"
          onClick={() => setPlaying((p) => !p)}
          aria-pressed={!playing}
        >
          {playing ? "Pause preview" : "Play preview"}
        </button>
        {!playing ? (
          <button
            type="button"
            onClick={() => goTo((i + 1) % SCENES.length)}
            aria-label="Next step"
          >
            ›
          </button>
        ) : null}
      </div>
    </section>
  );
}
