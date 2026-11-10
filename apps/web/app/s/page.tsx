import type { Metadata } from "next";

// Where a passport share link or QR code points (the part after the # is the secret token; it is never
// sent to this server, and this page does not read it). It only explains what the link is for.
export const metadata: Metadata = {
  title: "Passport share link · OurPawPass",
  description: "An OurPawPass passport share link for a vet.",
  robots: { index: false, follow: false },
};

export default function ShareLinkPage() {
  return (
    <div className="pp">
      <main id="main" className="wrap" style={{ padding: "96px 24px", maxWidth: 640 }}>
        <span className="eyebrow">PAWPASS PASSPORT</span>
        <h1 className="h2" style={{ marginTop: 12 }}>
          This is a passport share link for a vet
        </h1>
        <p style={{ fontSize: 17, lineHeight: 1.6, color: "var(--ink2)", marginTop: 16 }}>
          A pet owner shared their pet&apos;s OurPawPass passport with your clinic. Clinics open these
          links and QR codes in the OurPawPass partner app, which is coming soon, so there is nothing
          to see in a browser.
        </p>
        <p style={{ fontSize: 17, lineHeight: 1.6, color: "var(--ink2)", marginTop: 12 }}>
          The link stops working by itself, and the owner can stop it at any time.
        </p>
        <p style={{ marginTop: 28 }}>
          <a className="btn-green" href="/">
            Go to OurPawPass
          </a>
        </p>
      </main>
    </div>
  );
}
