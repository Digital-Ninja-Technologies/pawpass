"use client";

import Image from "next/image";
import { useState } from "react";

const CELLS = [1, 1, 0, 1, 1, 1, 0, 1, 0, 1, 0, 1, 1, 1, 0, 1, 0, 1, 0, 1, 1, 1, 0, 1, 1];

export function LostDemo() {
  const [lost, setLost] = useState(false);
  return (
    <div className="lost-demo">
      <button
        type="button"
        className="tag"
        aria-pressed={lost}
        aria-label="Collar tag. Tap to switch lost mode"
        onClick={() => setLost((l) => !l)}
      >
        {CELLS.map((on, i) => (
          <span key={i} className={on ? "on" : undefined} />
        ))}
      </button>
      <div aria-live="polite" style={{ width: "100%", display: "flex", justifyContent: "center" }}>
        {lost ? (
          <div className="tag-card col pp-pop">
            <span className="lost-mode">LOST MODE</span>
            <span style={{ display: "flex", gap: 12, alignItems: "center" }}>
              <Image src="/photos/bingo.jpg" alt="Bingo" width={56} height={56} />
              <span style={{ display: "flex", flexDirection: "column", gap: 2 }}>
                <b>You found Bingo!</b>
                <span className="s">
                  His family is looking for him. Message them, no number needed.
                </span>
              </span>
            </span>
            <span className="msg-btn">Message Bingo&apos;s family</span>
          </div>
        ) : (
          <div className="tag-card pp-pop">
            <Image src="/photos/bingo.jpg" alt="Bingo" width={56} height={56} />
            <span style={{ display: "flex", flexDirection: "column", gap: 2 }}>
              <b>Hi, I&apos;m Bingo!</b>
              <span className="s">I&apos;m safe at home. Thanks for checking my tag.</span>
            </span>
          </div>
        )}
      </div>
    </div>
  );
}
