import { AGENCY_NAME, AGENCY_URL } from "@/lib/site";

export function Footer() {
  return (
    <footer className="wrap footer">
      <span>
        <b>PawPass</b> · a{" "}
        {AGENCY_URL ? (
          <a href={AGENCY_URL} target="_blank" rel="noopener noreferrer">
            {AGENCY_NAME}
            <span className="sr-only"> (opens in a new tab)</span>
          </a>
        ) : (
          AGENCY_NAME
        )}{" "}
        product · Lagos, Nigeria
      </span>
      <span>
        <a href="/privacy">Privacy</a> · <a href="/terms">Terms</a>
      </span>
    </footer>
  );
}
