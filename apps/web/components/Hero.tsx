"use client";

import Image from "next/image";
import { useState } from "react";
import { PET_INFO, PET_OPTIONS, type PetId } from "@/lib/content";
import { STORES_LIVE } from "@/lib/stores";
import { arrowKeys } from "./arrowKeys";
import { PawFilled } from "./icons";
import { StoreButtons } from "./StoreButtons";

export function Hero() {
  const [pet, setPet] = useState<PetId>("dog");
  const info = PET_INFO[pet];

  return (
    <section id="top" className="wrap hero">
      <div className="hero-copy">
        <span className="badge-made">
          <span className="pp-wag" aria-hidden="true" style={{ display: "inline-flex" }}>
            <PawFilled />
          </span>
          Made in Lagos, for pets everywhere
        </span>
        <h1>
          Every pet&apos;s life,
          <br />
          <span>in one place.</span>
        </h1>
        <p className="lead">
          Vaccine reminders, trusted vets and groomers, lost pet alerts and verified breeders. One
          free app for every dog, cat and furry family member.
        </p>

        <div className="picker">
          <span id="pet-pick" className="picker-label">
            Who&apos;s your best friend?
          </span>
          <div
            role="radiogroup"
            aria-labelledby="pet-pick"
            className="picker-row"
            onKeyDown={(e) => arrowKeys(e, '[role="radio"]')}
          >
            {PET_OPTIONS.map((p) => (
              <button
                key={p.id}
                type="button"
                role="radio"
                aria-checked={pet === p.id}
                tabIndex={pet === p.id ? 0 : -1}
                className="pick"
                onClick={() => setPet(p.id)}
              >
                {p.label}
              </button>
            ))}
          </div>
        </div>

        <div className="stores">
          <StoreButtons />
          <span className="stores-note">
            {STORES_LIVE ? "Free · iOS and Android" : "Free · iOS and Android · coming soon"}
          </span>
        </div>
      </div>

      <div className="hero-visual">
        <span className="blob a" aria-hidden="true" />
        <span className="blob b" aria-hidden="true" />

        <div className="phone hero-phone pp-float">
          <div className="screen">
            <p style={{ fontSize: 11, color: "var(--muted)" }}>Good morning, Tolu</p>
            <div className="card-sm">
              {pet === "dog" ? (
                <Image
                  src="/photos/bingo.jpg"
                  alt="Bingo the Boerboel"
                  width={64}
                  height={64}
                  className="pet-photo"
                />
              ) : null}
              {pet === "cat" ? (
                <Image
                  src="/photos/mimi.jpg"
                  alt="Mimi the cat"
                  width={64}
                  height={64}
                  className="pet-photo"
                />
              ) : null}
              {pet === "both" ? (
                <span className="pet-both">
                  <Image
                    src="/photos/bingo.jpg"
                    alt="Bingo"
                    width={44}
                    height={44}
                    style={{ left: 0, top: 0 }}
                  />
                  <Image
                    src="/photos/mimi.jpg"
                    alt="Mimi"
                    width={44}
                    height={44}
                    style={{ right: 0, bottom: 0 }}
                  />
                </span>
              ) : null}
              <span style={{ display: "flex", flexDirection: "column", gap: 4 }}>
                <span className="pet-name">{info.name}</span>
                <span style={{ fontSize: 11, color: "var(--muted)" }}>{info.breed}</span>
                <span className="tag-ok">✓ Passport up to date</span>
              </span>
            </div>
            <div className="reminder pp-pop" key={pet}>
              <span className="when">{info.when}</span>
              <span className="what">{info.text}</span>
              <span className="pill-btn">Book a vet</span>
            </div>
            <div className="quick" aria-hidden="true">
              <span>
                <i style={{ background: "#e3f1ee" }} />
                Vet
              </span>
              <span>
                <i style={{ background: "#f1e8fb" }} />
                Grooming
              </span>
              <span>
                <i style={{ background: "#ffebd9" }} />
                Lost
              </span>
              <span>
                <i style={{ background: "#dce7f7" }} />
                Adopt
              </span>
            </div>
            <div className="emergency">Emergency vet · open now near you</div>
            <Image
              src="/photos/clinic.jpg"
              alt="A vet examining a dog"
              width={270}
              height={120}
              className="clinic-img"
            />
          </div>
        </div>

        <div className="float-chip pp-float2" style={{ left: 0, top: 150 }}>
          <span
            className="ic"
            style={{ background: "var(--primary-soft)", color: "var(--primary-text)" }}
          >
            ✓
          </span>
          Vet verified
        </div>
        <div className="float-chip pp-float" style={{ right: 0, top: 330 }}>
          <span
            className="ic"
            style={{ background: "var(--warm-soft)", color: "var(--warm-text)" }}
          >
            ₦
          </span>
          Payment held safely
        </div>
        <div className="float-chip dark pp-float2" style={{ left: 20, bottom: 60 }}>
          <span style={{ position: "relative", width: 12, height: 12 }}>
            <span
              className="pp-ping"
              style={{ position: "absolute", inset: 0, borderRadius: 6, background: "var(--dot)" }}
            />
            <span
              style={{ position: "absolute", inset: 2, borderRadius: 4, background: "var(--dot)" }}
            />
          </span>
          Lost alert sent within 5 km
        </div>
      </div>
    </section>
  );
}
