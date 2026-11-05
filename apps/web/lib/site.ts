/** The agency's website, for the "a Digital Ninja Technologies product" link in the footer.
 * Set NEXT_PUBLIC_AGENCY_URL (an https address). Until it is set, the name is shown as plain text. */
const raw = process.env.NEXT_PUBLIC_AGENCY_URL ?? "";

export function safeAgencyUrl(value: string): string {
  try {
    const url = new URL(value);
    return url.protocol === "https:" || url.protocol === "http:" ? url.toString() : "";
  } catch {
    return "";
  }
}

export const AGENCY_NAME = "Digital Ninja Technologies";
export const AGENCY_URL = safeAgencyUrl(raw);
