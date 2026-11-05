"use client";

import { useEffect, useState } from "react";

/** One time confirmation after an action. The server sets a short lived cookie; this shows it and removes it. */
export function Flash({ message }: { message: string }) {
  const [visible, setVisible] = useState(true);
  useEffect(() => {
    document.cookie = "flash=; Max-Age=0; path=/";
    const t = setTimeout(() => setVisible(false), 7000);
    return () => clearTimeout(t);
  }, [message]);
  if (!visible) return null;
  return (
    <div className="flash notice ok" role="status" data-flash>
      <span>{message}</span>
      <button
        type="button"
        className="icon-btn dismiss"
        aria-label="Dismiss message"
        onClick={() => setVisible(false)}
      >
        ×
      </button>
    </div>
  );
}
