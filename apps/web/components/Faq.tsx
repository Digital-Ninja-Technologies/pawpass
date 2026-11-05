"use client";

import { useState } from "react";
import { FAQS } from "@/lib/content";

export function Faq() {
  const [open, setOpen] = useState(0);
  return (
    <section id="faq" className="faq">
      <h2 className="h2">Questions pet parents ask</h2>
      <div className="faq-list">
        {FAQS.map((f, i) => {
          const isOpen = open === i;
          return (
            <div key={f.q} className="faq-item">
              <h3 style={{ margin: 0 }}>
                <button
                  type="button"
                  className="faq-q"
                  aria-expanded={isOpen}
                  aria-controls={`faq-a-${i}`}
                  id={`faq-q-${i}`}
                  onClick={() => setOpen(isOpen ? -1 : i)}
                >
                  {f.q}
                  <span className="faq-sign" aria-hidden="true">
                    {isOpen ? "−" : "+"}
                  </span>
                </button>
              </h3>
              {isOpen ? (
                <p
                  id={`faq-a-${i}`}
                  role="region"
                  aria-labelledby={`faq-q-${i}`}
                  className="faq-a pp-pop"
                >
                  {f.a}
                </p>
              ) : null}
            </div>
          );
        })}
      </div>
    </section>
  );
}
