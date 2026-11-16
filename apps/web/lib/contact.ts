/** The public support email, shown on the legal pages. It is the same address as on the Google Play listing. */
export const CONTACT_EMAIL = "thedigitalninjatechnologies@gmail.com";

export function safeEmail(value: string): string {
  return /^[^\s@<>"]+@[^\s@<>"]+\.[^\s@<>"]+$/.test(value) ? value : "";
}
