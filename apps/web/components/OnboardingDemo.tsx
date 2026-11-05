"use client";

import Image from "next/image";
import { useId, useState, type ReactNode } from "react";
import { PawOutline } from "./icons";

/**
 * A tappable preview of the real onboarding flow (Welcome to Passport ready) inside a phone.
 * Everything stays in this component's memory: nothing is sent or stored.
 */

type Species = "dog" | "cat" | "other";

const STEPS = [
  "Welcome",
  "Sign up",
  "Verify",
  "Account type",
  "Profile",
  "Add pet",
  "Health history",
  "Reminders",
  "Passport ready",
] as const;
const LAST = STEPS.length - 1;

const ACCOUNT_TYPES = [
  ["owner", "Pet owner", "Track health, book care, join the community"],
  ["vet", "Vet or service provider", "Clinics, groomers, trainers, boarding"],
  ["breeder", "Breeder", "List litters with verified passports"],
  ["shelter", "Shelter or rescue", "Rehome pets and screen adopters"],
] as const;

const VACCINES = [
  ["core", "Last given 12 Mar 2026"],
  ["rabies", "Last given 12 Nov 2025"],
  ["deworm", "Last given 20 Oct 2026"],
  ["tick", "Last given 2 Sep 2026"],
] as const;

function vaccineName(id: string, species: Species) {
  if (id === "core") {
    return species === "cat"
      ? "FVRCP (3-in-1)"
      : species === "dog"
        ? "DHPP (5-in-1)"
        : "Core vaccine";
  }
  return { rabies: "Rabies", deworm: "Deworming", tick: "Tick & flea treatment" }[id] ?? id;
}

const CHANNELS = ["App notifications", "WhatsApp", "Email"] as const;

function Check({ on }: { on: boolean }) {
  return (
    <span className={`ob-check${on ? " on" : ""}`} aria-hidden="true">
      {on ? "✓" : ""}
    </span>
  );
}

export function OnboardingDemo() {
  const uid = useId();
  const [step, setStep] = useState(0);
  const [types, setTypes] = useState<string[]>(["owner"]);
  const [species, setSpecies] = useState<Species>("dog");
  const [petName, setPetName] = useState("Bingo");
  const [sex, setSex] = useState<"Male" | "Female">("Male");
  const [vax, setVax] = useState<string[]>(["core", "rabies", "deworm"]);
  const [channels, setChannels] = useState<string[]>(["App notifications", "WhatsApp"]);

  const name = petName.trim() || "your pet";
  const possessive = name.endsWith("s") ? `${name}'` : `${name}'s`;
  const toggle = (list: string[], set: (v: string[]) => void, v: string) =>
    set(list.includes(v) ? list.filter((x) => x !== v) : [...list, v]);
  const next = () => setStep((s) => Math.min(LAST, s + 1));
  const back = () => setStep((s) => Math.max(0, s - 1));
  const restart = () => setStep(0);

  let body: ReactNode;
  let cta: ReactNode = (
    <button type="button" className="ob-btn" onClick={next}>
      Continue
    </button>
  );

  switch (step) {
    case 0:
      body = (
        <div className="ob-welcome">
          <span className="ob-logo" aria-hidden="true">
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
          <button type="button" className="ob-btn" onClick={next}>
            Get started
          </button>
          <button type="button" className="ob-link" onClick={next}>
            I already have an account
          </button>
        </>
      );
      break;
    case 1:
      body = (
        <>
          <h3 className="ob-h">What&apos;s your email?</h3>
          <p className="ob-p">
            We&apos;ll email you a 6-digit code to sign in. No password needed.
          </p>
          <label className="ob-label" htmlFor={`${uid}-email`}>
            Email address
          </label>
          <input
            id={`${uid}-email`}
            className="ob-input"
            type="text"
            inputMode="email"
            autoComplete="off"
            placeholder="you@example.com"
          />
          <p className="ob-fine">Preview only. Nothing you type here is sent or saved.</p>
        </>
      );
      cta = (
        <button type="button" className="ob-btn" onClick={next}>
          Send code
        </button>
      );
      break;
    case 2:
      body = (
        <>
          <h3 className="ob-h">Enter the code</h3>
          <p className="ob-p">We filled in a sample code for you.</p>
          <div className="ob-code" role="img" aria-label="Sample code 4 8 2 1 7 6">
            {["4", "8", "2", "1", "7", "6"].map((d, i) => (
              <span key={i}>{d}</span>
            ))}
          </div>
          <p className="ob-fine">Check spam if it&apos;s not there.</p>
        </>
      );
      cta = (
        <button type="button" className="ob-btn" onClick={next}>
          Verify
        </button>
      );
      break;
    case 3:
      body = (
        <>
          <h3 className="ob-h">How will you use PawPass?</h3>
          <p className="ob-p">Pick all that apply. You can add more later.</p>
          <div className="ob-list" role="group" aria-label="Account types">
            {ACCOUNT_TYPES.map(([id, title, sub]) => (
              <button
                key={id}
                type="button"
                className="ob-opt"
                aria-pressed={types.includes(id)}
                onClick={() => toggle(types, setTypes, id)}
              >
                <Check on={types.includes(id)} />
                <span>
                  <b>{title}</b>
                  <small>{sub}</small>
                </span>
              </button>
            ))}
          </div>
        </>
      );
      break;
    case 4:
      body = (
        <>
          <h3 className="ob-h">Tell us about you</h3>
          <div className="ob-two">
            <div>
              <label className="ob-label" htmlFor={`${uid}-fn`}>
                First name
              </label>
              <input
                id={`${uid}-fn`}
                className="ob-input"
                type="text"
                autoComplete="off"
                placeholder="Tolu"
              />
            </div>
            <div>
              <label className="ob-label" htmlFor={`${uid}-ln`}>
                Last name
              </label>
              <input
                id={`${uid}-ln`}
                className="ob-input"
                type="text"
                autoComplete="off"
                placeholder="Adeyemi"
              />
            </div>
          </div>
          <label className="ob-label" htmlFor={`${uid}-area`}>
            Your area
          </label>
          <input
            id={`${uid}-area`}
            className="ob-input"
            type="text"
            autoComplete="off"
            placeholder="e.g. Lekki"
          />
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
          <p className="ob-label" id={`${uid}-sp`}>
            Species
          </p>
          <div className="ob-seg" role="group" aria-labelledby={`${uid}-sp`}>
            {(["dog", "cat", "other"] as const).map((s) => (
              <button
                key={s}
                type="button"
                aria-pressed={species === s}
                onClick={() => setSpecies(s)}
              >
                {s === "dog" ? "Dog" : s === "cat" ? "Cat" : "Other"}
              </button>
            ))}
          </div>
          <label className="ob-label" htmlFor={`${uid}-pn`}>
            Pet&apos;s name
          </label>
          <input
            id={`${uid}-pn`}
            className="ob-input"
            type="text"
            autoComplete="off"
            maxLength={20}
            value={petName}
            onChange={(e) => setPetName(e.target.value)}
          />
          <p className="ob-label" id={`${uid}-sx`}>
            Sex
          </p>
          <div className="ob-seg" role="group" aria-labelledby={`${uid}-sx`}>
            {(["Male", "Female"] as const).map((s) => (
              <button key={s} type="button" aria-pressed={sex === s} onClick={() => setSex(s)}>
                {s}
              </button>
            ))}
          </div>
        </>
      );
      break;
    case 6:
      body = (
        <>
          <h3 className="ob-h">{possessive} health so far</h3>
          <p className="ob-p">Add past vaccines so we can schedule what&apos;s next.</p>
          <div className="ob-scan">
            <b>Scan vaccine card</b>
            <small>Snap the paper card, we&apos;ll read the dates</small>
          </div>
          <div className="ob-list" role="group" aria-label="Past vaccines">
            {VACCINES.map(([id, date]) => (
              <button
                key={id}
                type="button"
                className="ob-opt"
                aria-pressed={vax.includes(id)}
                onClick={() => toggle(vax, setVax, id)}
              >
                <Check on={vax.includes(id)} />
                <span>
                  <b>{vaccineName(id, species)}</b>
                  <small>{vax.includes(id) ? date : "Not added"}</small>
                </span>
              </button>
            ))}
          </div>
        </>
      );
      cta = (
        <button type="button" className="ob-btn" onClick={next}>
          Save health history
        </button>
      );
      break;
    case 7:
      body = (
        <>
          <h3 className="ob-h">Never miss a dose</h3>
          <p className="ob-p">
            Here&apos;s {possessive} suggested schedule. We&apos;ll remind you 7 days and 1 day
            before.
          </p>
          <ul className="ob-sched">
            {[
              ["NOV", "12", "Rabies booster", "Yearly · due in 7 days"],
              ["JAN", "20", "Deworming", "Every 3 months"],
              ["MAR", "12", "Booster vaccine", "Yearly"],
            ].map(([m, d, t, s]) => (
              <li key={t}>
                <span className="ob-date" aria-hidden="true">
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
          <p className="ob-label" id={`${uid}-ch`}>
            Remind me by
          </p>
          <div className="ob-chips" role="group" aria-labelledby={`${uid}-ch`}>
            {CHANNELS.map((c) => (
              <button
                key={c}
                type="button"
                aria-pressed={channels.includes(c)}
                onClick={() => toggle(channels, setChannels, c)}
              >
                {c}
              </button>
            ))}
          </div>
        </>
      );
      cta = (
        <button type="button" className="ob-btn" onClick={next}>
          Turn on reminders
        </button>
      );
      break;
    default:
      body = (
        <div className="ob-done">
          <span className="ob-tick" aria-hidden="true">
            ✓
          </span>
          <h3 className="ob-h">{possessive} passport is ready</h3>
          <p className="ob-p">
            {vax.length} {vax.length === 1 ? "record" : "records"} saved and reminders are{" "}
            {channels.length ? "on" : "off"}.
          </p>
          <div className="ob-pass">
            {species === "other" ? (
              <span className="ob-pawbox" aria-hidden="true">
                <PawOutline size={26} />
              </span>
            ) : (
              <Image
                src={species === "cat" ? "/photos/mimi.jpg" : "/photos/bingo.jpg"}
                alt=""
                width={52}
                height={52}
                className="ob-pet"
              />
            )}
            <span>
              <b>{petName.trim() || "Your pet"}</b>
              <small>
                {species === "dog" ? "Dog" : species === "cat" ? "Cat" : "Pet"} · {sex}
              </small>
              <small>Tag ID PP-4821-LK</small>
            </span>
          </div>
          <div className="ob-qr">
            <b>Get a QR collar tag</b>
            <small>Anyone who finds {name} can reach you safely</small>
          </div>
        </div>
      );
      cta = (
        <button type="button" className="ob-btn" onClick={restart}>
          Start over
        </button>
      );
  }

  return (
    <section className="ob" aria-label="Try PawPass onboarding">
      <div className="phone ob-phone">
        <div className="ob-screen">
          <div className="ob-top">
            {step > 0 && step < LAST ? (
              <button type="button" className="ob-back" onClick={back} aria-label="Back">
                ‹
              </button>
            ) : (
              <span className="ob-back-gap" />
            )}
            {step > 0 && step < LAST ? (
              <span className="ob-prog" aria-hidden="true">
                {STEPS.slice(1, LAST).map((s, i) => (
                  <i key={s} className={i < step ? "on" : ""} />
                ))}
              </span>
            ) : null}
            {step === 6 ? (
              <button type="button" className="ob-skip" onClick={next}>
                Skip
              </button>
            ) : (
              <span className="ob-back-gap" />
            )}
          </div>
          <div className="ob-body" key={step}>
            {body}
          </div>
          <div className="ob-cta">{cta}</div>
        </div>
      </div>
      <p className="ob-caption" role="status">
        <span className="sr-only">
          Step {step + 1} of {STEPS.length}:{" "}
        </span>
        {STEPS[step]}
        <span aria-hidden="true">
          {" "}
          · {step + 1}/{STEPS.length}
        </span>
      </p>
      {step > 0 ? (
        <button type="button" className="ob-restart" onClick={restart}>
          Restart
        </button>
      ) : null}
    </section>
  );
}
