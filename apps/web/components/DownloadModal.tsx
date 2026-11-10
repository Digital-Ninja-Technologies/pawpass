"use client";

import { useEffect, useRef } from "react";
import { STORES_LIVE } from "@/lib/stores";
import { StoreButtons } from "./StoreButtons";

/** "Get the app" pop up. Uses a native dialog, so focus is trapped, Escape closes it and the page behind is inert. */
export function DownloadModal({ open, onClose }: { open: boolean; onClose: () => void }) {
  const ref = useRef<HTMLDialogElement>(null);

  useEffect(() => {
    const d = ref.current;
    if (!d) return;
    if (open && !d.open) d.showModal();
    if (!open && d.open) d.close();
  }, [open]);

  return (
    <dialog
      ref={ref}
      className="dl-modal"
      aria-labelledby="dl-title"
      aria-describedby="dl-desc"
      onClose={onClose}
      onClick={(e) => {
        if (e.target === ref.current) onClose();
      }}
    >
      <div className="dl-card">
        <button type="button" className="dl-x" onClick={onClose} aria-label="Close">
          <svg
            width="20"
            height="20"
            viewBox="0 0 24 24"
            fill="none"
            stroke="currentColor"
            strokeWidth="2"
            strokeLinecap="round"
            aria-hidden="true"
          >
            <path d="M6 6l12 12M18 6L6 18" />
          </svg>
        </button>
        <h2 id="dl-title">Get OurPawPass</h2>
        <p id="dl-desc" className="dl-lead">
          Your pet&apos;s passport, reminders and lost pet alerts, in one free app.
        </p>
        <ul className="dl-facts">
          <li>Free to download</li>
          <li>Works on iPhone and Android</li>
          <li>Set up in 2 minutes</li>
        </ul>
        <div className="stores dl-stores">
          <StoreButtons />
        </div>
        {STORES_LIVE ? null : (
          <p className="dl-note">
            OurPawPass is not in the app stores yet. The download buttons will go live here at launch.
          </p>
        )}
      </div>
    </dialog>
  );
}
