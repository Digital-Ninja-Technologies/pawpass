/** Support email shown on the legal pages. Set NEXT_PUBLIC_CONTACT_EMAIL; until then the pages point to Help in the app. */
const raw = process.env.NEXT_PUBLIC_CONTACT_EMAIL ?? "";

export function safeEmail(value: string): string {
  return /^[^\s@<>"]+@[^\s@<>"]+\.[^\s@<>"]+$/.test(value) ? value : "";
}

export const CONTACT_EMAIL = safeEmail(raw);
