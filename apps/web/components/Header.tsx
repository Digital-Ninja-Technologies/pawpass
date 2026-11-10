"use client";

import { useState } from "react";
import { DownloadModal } from "./DownloadModal";
import { PawOutline } from "./icons";

const LINKS = [
  ["#features", "Features"],
  ["#lost", "Lost & found"],
  ["#partners", "For vets & breeders"],
  ["#faq", "FAQ"],
] as const;

/** `base` is "" on the home page (links scroll in place) and "/" on other pages (links go to the home page sections). */
export function Header({ base = "" }: { base?: "" | "/" }) {
  const [open, setOpen] = useState(false);
  const [dl, setDl] = useState(false);
  return (
    <>
      <div className="sticky-bar">
        <header className="wrap header">
          <a href={`${base}#top`} className="logo" aria-label="OurPawPass home">
            <span className="logo-mark" aria-hidden="true">
              <PawOutline />
            </span>
            <span className="logo-name">OurPawPass</span>
          </a>
          <nav className="navlinks" aria-label="Main">
            {LINKS.map(([href, label]) => (
              <a key={href} href={`${base}${href}`}>
                {label}
              </a>
            ))}
            <button
              type="button"
              className="get"
              onClick={() => setDl(true)}
              aria-haspopup="dialog"
            >
              Get the app
            </button>
          </nav>
          <button
            type="button"
            className="burger"
            onClick={() => setOpen((o) => !o)}
            aria-label={open ? "Close menu" : "Open menu"}
            aria-expanded={open}
            aria-controls="pp-mobile-menu"
          >
            <svg
              width="22"
              height="22"
              viewBox="0 0 24 24"
              fill="none"
              stroke="currentColor"
              strokeWidth="2"
              strokeLinecap="round"
              aria-hidden="true"
            >
              <path d={open ? "M6 6l12 12M18 6L6 18" : "M4 7h16M4 12h16M4 17h16"} />
            </svg>
          </button>
        </header>
        {open ? (
          <nav id="pp-mobile-menu" className="mobilemenu pp-pop" aria-label="Mobile">
            {LINKS.map(([href, label]) => (
              <a key={href} href={`${base}${href}`} onClick={() => setOpen(false)}>
                {label}
              </a>
            ))}
            <button
              type="button"
              className="get"
              aria-haspopup="dialog"
              onClick={() => {
                setOpen(false);
                setDl(true);
              }}
            >
              Get the app
            </button>
          </nav>
        ) : null}
      </div>
      <DownloadModal open={dl} onClose={() => setDl(false)} />
    </>
  );
}
