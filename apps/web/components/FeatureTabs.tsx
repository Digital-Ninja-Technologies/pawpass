"use client";

import Image from "next/image";
import { useCallback, useEffect, useRef, useState } from "react";
import { TABS, type TabId } from "@/lib/content";
import { arrowKeys } from "./arrowKeys";

function Screen({ tab }: { tab: TabId }) {
  if (tab === "health") {
    return (
      <>
        <p className="scr-title">Bingo&apos;s Passport</p>
        <div
          style={{
            background: "var(--primary)",
            color: "#fff",
            borderRadius: 18,
            padding: 12,
            display: "flex",
            gap: 10,
            alignItems: "center",
          }}
        >
          <Image
            src="/photos/bingo.jpg"
            alt="Bingo"
            width={48}
            height={48}
            style={{ borderRadius: 12, objectFit: "cover" }}
          />
          <span style={{ fontSize: 12 }}>
            <b style={{ fontSize: 15 }}>Bingo</b>
            <br />
            Boerboel · Tag PP-4821
          </span>
        </div>
        <div className="row-card">
          <b>Rabies booster</b>
          <span style={{ color: "var(--warm-text)", fontWeight: 700 }}>Due 12 Nov</span>
        </div>
        <div className="row-card">
          <b>DHPP vaccine</b>
          <span style={{ color: "var(--primary-text)", fontWeight: 700 }}>✓ Vet verified</span>
        </div>
        <div className="row-card">
          <b>Deworming</b>
          <span style={{ color: "var(--muted)" }}>Done</span>
        </div>
        <div className="dark-btn">Share with a vet (QR)</div>
      </>
    );
  }
  if (tab === "book") {
    return (
      <>
        <p className="scr-title">Book care</p>
        <Image
          src="/photos/clinic.jpg"
          alt="Vet clinic"
          width={270}
          height={110}
          style={{ width: "100%", height: 110, borderRadius: 14, objectFit: "cover" }}
        />
        <div style={{ fontSize: 13 }}>
          <b>Paws &amp; Claws Vet Clinic</b>
          <br />
          <span style={{ color: "var(--muted)", fontSize: 11 }}>★ 4.8 · 2.1 km · Verified</span>
        </div>
        <div className="slots">
          <span>3:00</span>
          <span className="on">4:30</span>
          <span>5:00</span>
          <span>6:30</span>
        </div>
        <div
          style={{
            fontSize: 11,
            color: "var(--primary-text)",
            background: "var(--primary-soft)",
            padding: "8px 10px",
            borderRadius: 10,
            fontWeight: 600,
          }}
        >
          Payment held until your visit is done
        </div>
        <div className="green-btn">Pay ₦15,000 &amp; book</div>
      </>
    );
  }
  if (tab === "community") {
    return (
      <>
        <p className="scr-title">Community</p>
        <div
          style={{
            background: "var(--warm-soft)",
            borderRadius: 14,
            padding: 10,
            display: "flex",
            gap: 10,
            alignItems: "center",
          }}
        >
          <Image
            src="/photos/bruno.jpg"
            alt="Bruno"
            width={44}
            height={44}
            style={{ borderRadius: 10, objectFit: "cover" }}
          />
          <span style={{ fontSize: 11 }}>
            <b style={{ color: "var(--warm-text)" }}>LOST NEAR YOU</b>
            <br />
            <b>Bruno</b> · Jack Russell
          </span>
        </div>
        <div
          style={{
            background: "#fff",
            border: "1px solid var(--border)",
            borderRadius: 16,
            overflow: "hidden",
          }}
        >
          <Image
            src="/photos/luna.jpg"
            alt="Luna the Persian cat"
            width={270}
            height={170}
            style={{ width: "100%", height: 170, objectFit: "cover" }}
          />
          <p style={{ padding: "8px 10px", fontSize: 11 }}>
            <b>Luna</b> has claimed the new sofa. ♥ 248
          </p>
        </div>
      </>
    );
  }
  return (
    <>
      <p className="scr-title">Find a pet</p>
      <Image
        src="/photos/duke.jpg"
        alt="Duke, a Boerboel puppy"
        width={270}
        height={160}
        style={{ width: "100%", height: 160, borderRadius: 14, objectFit: "cover" }}
      />
      <div style={{ fontSize: 13, display: "flex", justifyContent: "space-between" }}>
        <b>Duke · 9 weeks</b>
        <b>₦450,000</b>
      </div>
      <div style={{ fontSize: 11, color: "var(--primary-text)", fontWeight: 700 }}>
        ✓ Royal Paws Kennels · verified breeder
      </div>
      <div
        style={{
          fontSize: 11,
          color: "var(--ink2)",
          background: "var(--subtle)",
          padding: "8px 10px",
          borderRadius: 10,
        }}
      >
        Deposit → meet → 72 hour vet check → breeder paid
      </div>
      <div className="green-btn">Pay deposit safely</div>
    </>
  );
}

/**
 * Scroll story: on a roomy screen the section pins under the header and walks through the features as
 * you scroll (each one's details appear one by one), then lets go and scrolls away. On small or short
 * screens, and for people who prefer reduced motion, it is the plain tab picker.
 */
const FX_QUERY =
  "(min-width: 960px) and (min-height: 740px) and (prefers-reduced-motion: no-preference)";
const STICK = 96; // matches `top` of .fx-pin in the CSS (the sticky header height plus a little air)
const POINT_AT = [0.2, 0.45, 0.7]; // how far into a feature each point appears

export function FeatureTabs() {
  const [tab, setTab] = useState<TabId>("health");
  const [shown, setShown] = useState(3);
  const [fx, setFx] = useState(false);
  const trackRef = useRef<HTMLElement>(null);
  const pinRef = useRef<HTMLDivElement>(null);
  const railRef = useRef<HTMLSpanElement>(null);
  const current = TABS.find((t) => t.id === tab) ?? TABS[0]!;
  const n = TABS.length;

  useEffect(() => {
    const mq = window.matchMedia(FX_QUERY);
    const on = () => setFx(mq.matches);
    on();
    mq.addEventListener("change", on);
    return () => mq.removeEventListener("change", on);
  }, []);

  useEffect(() => {
    if (!fx) {
      setShown(3);
      return;
    }
    let raf = 0;
    const update = () => {
      raf = 0;
      const track = trackRef.current;
      const pin = pinRef.current;
      if (!track || !pin) return;
      const travel = track.offsetHeight - pin.offsetHeight;
      if (travel <= 0) return;
      const p = Math.min(1, Math.max(0, (STICK - track.getBoundingClientRect().top) / travel));
      const x = p * n;
      const idx = Math.min(n - 1, Math.floor(x));
      const within = x - idx;
      setTab(TABS[idx]!.id);
      setShown(POINT_AT.filter((t) => within >= t).length);
      railRef.current?.querySelectorAll<HTMLElement>("i").forEach((el, j) => {
        el.style.setProperty("--fill", String(Math.min(1, Math.max(0, x - j))));
      });
    };
    const onScroll = () => {
      if (!raf) raf = requestAnimationFrame(update);
    };
    update();
    window.addEventListener("scroll", onScroll, { passive: true });
    window.addEventListener("resize", onScroll);
    return () => {
      window.removeEventListener("scroll", onScroll);
      window.removeEventListener("resize", onScroll);
      if (raf) cancelAnimationFrame(raf);
    };
  }, [fx, n]);

  const choose = useCallback(
    (id: TabId) => {
      setTab(id);
      const track = trackRef.current;
      const pin = pinRef.current;
      if (!fx || !track || !pin) return;
      // Scroll to the point where this feature is fully revealed.
      const idx = TABS.findIndex((t) => t.id === id);
      const travel = track.offsetHeight - pin.offsetHeight;
      const top =
        window.scrollY + track.getBoundingClientRect().top - STICK + ((idx + 0.8) / n) * travel;
      window.scrollTo({ top, behavior: "smooth" });
    },
    [fx, n],
  );

  return (
    <section
      id="features"
      ref={trackRef}
      className={`fx-track${fx ? " fx-on" : ""}`}
      style={{ "--fx-steps": n } as React.CSSProperties}
    >
      <div ref={pinRef} className="wrap features fx-pin">
        <div className="features-copy">
          <span className="eyebrow">TAP TO EXPLORE</span>
          <h2 className="h2">Four things OurPawPass does for you</h2>
          <div
            role="tablist"
            aria-label="Features"
            className="tabs"
            onKeyDown={(e) => arrowKeys(e, '[role="tab"]')}
          >
            {TABS.map((t) => (
              <button
                key={t.id}
                type="button"
                role="tab"
                id={`tab-${t.id}`}
                aria-selected={tab === t.id}
                aria-controls="feature-panel"
                tabIndex={tab === t.id ? 0 : -1}
                className="tab"
                onClick={() => choose(t.id)}
              >
                {t.label}
              </button>
            ))}
          </div>
          <span ref={railRef} className="fx-rail" aria-hidden="true">
            {TABS.map((t) => (
              <i key={t.id} />
            ))}
          </span>
          <div
            id="feature-panel"
            role="tabpanel"
            aria-labelledby={`tab-${tab}`}
            className="tab-body pp-pop"
            key={tab}
          >
            <h3>{current.title}</h3>
            <p>{current.body}</p>
            <ul className="points">
              {current.points.map((pt, i) => (
                <li key={pt} className={i < shown ? "show" : ""}>
                  <span className="ck" aria-hidden="true">
                    ✓
                  </span>
                  {pt}
                </li>
              ))}
            </ul>
          </div>
        </div>
        <div className="features-visual" aria-hidden="true">
          <div className="phone feat-phone">
            <div className="screen pp-pop" key={tab}>
              <Screen tab={tab} />
            </div>
          </div>
        </div>
      </div>
    </section>
  );
}
