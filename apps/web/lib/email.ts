/** Same rule as the database check on waitlist_signups.email. */
export const EMAIL_PATTERN = /^[^@\s]+@[^@\s]+\.[^@\s]+$/;

export function normaliseEmail(value: string): string {
  return value.trim().toLowerCase();
}

export function isValidEmail(value: string): boolean {
  const v = normaliseEmail(value);
  return v.length <= 254 && EMAIL_PATTERN.test(v);
}
