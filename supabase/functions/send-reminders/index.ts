import { runReminders } from "../_shared/reminders.ts";
import { errorResponse, isServiceCall, json, reminderContext } from "../_shared/runtime.deno.ts";

// Run on a schedule (needs the service role key), every 15 minutes:
//  - tells people in the app about reminders that are due soon or overdue;
//  - emails the people who chose email, between 8am and 8pm Lagos time, once each.
// Needs the RESEND_API_KEY secret. Deploy with JWT verification off: it only accepts the service role key.
Deno.serve(async (req: Request) => {
  if (req.method !== "POST") return json({ error: "Use POST" }, 405);
  if (!isServiceCall(req)) return json({ error: "Not allowed" }, 403);
  try {
    return json(await runReminders(reminderContext()));
  } catch (e) {
    return errorResponse(e);
  }
});
