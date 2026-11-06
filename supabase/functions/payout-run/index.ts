import { runPayouts } from "../_shared/payouts.ts";
import { errorResponse, isServiceCall, json, payoutContext } from "../_shared/runtime.deno.ts";

// Run on a schedule (needs the service role key), at least every hour:
//  - keeps the draft payout run for the next payout day up to date, for staff to review;
//  - sends the items of runs that staff approved, once the run day has come.
// Nothing is paid from a run that has not been approved in the admin console.
Deno.serve(async (req: Request) => {
  if (req.method !== "POST") return json({ error: "Use POST" }, 405);
  if (!isServiceCall(req)) return json({ error: "Not allowed" }, 403);
  try {
    return json(await runPayouts(payoutContext()));
  } catch (e) {
    return errorResponse(e);
  }
});
