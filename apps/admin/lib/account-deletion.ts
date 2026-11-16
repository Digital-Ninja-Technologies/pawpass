/** True when what the admin typed is the account's email (ignoring case and spaces at the ends). */
export function emailMatches(typed: string, email: string | null | undefined): boolean {
  const a = typed.trim().toLowerCase();
  return a.length > 0 && !!email && a === email.trim().toLowerCase();
}

/** The address of the admin-delete-account function for a Supabase project. */
export function deletionFunctionUrl(supabaseUrl: string): string {
  return `${supabaseUrl.replace(/\/+$/, "")}/functions/v1/admin-delete-account`;
}

/** What to show the admin when the function answered with an error. Its own messages are written for people. */
export function deletionErrorMessage(status: number, body: unknown): string {
  const message =
    body && typeof body === "object" && typeof (body as { error?: unknown }).error === "string"
      ? (body as { error: string }).error
      : "";
  if (status === 401) return "Your session has ended. Sign in again.";
  if (status === 403) return "Only full admins can delete accounts.";
  if (status >= 400 && status < 500 && message) return message;
  if (status === 502 && message) return message;
  return "The account could not be deleted. Try again, and if it keeps failing check the function logs.";
}
