import { runScheduledJobs } from "../_shared/payments.ts";
import { context, errorResponse, isServiceCall, json } from "../_shared/runtime.deno.ts";

// Run every few minutes by a schedule (needs the service role key): sends queued refunds to Paystack
// and makes visits the owner never confirmed ready for payout.
Deno.serve(async (req: Request) => {
  if (req.method !== "POST") return json({ error: "Use POST" }, 405);
  if (!isServiceCall(req)) return json({ error: "Not allowed" }, 403);
  try {
    return json(await runScheduledJobs(await context()));
  } catch (e) {
    return errorResponse(e);
  }
});
