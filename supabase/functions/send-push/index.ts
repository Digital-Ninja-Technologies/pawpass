import { runPush } from "../_shared/push.ts";
import { errorResponse, isServiceCall, json, pushContext } from "../_shared/runtime.deno.ts";

// Run on a schedule (needs the service role key), every minute: sends push notifications that are ready.
// Needs the FCM_SERVICE_ACCOUNT secret. Deploy with JWT verification off: it only accepts the service role key.
Deno.serve(async (req: Request) => {
  if (req.method !== "POST") return json({ error: "Use POST" }, 405);
  if (!isServiceCall(req)) return json({ error: "Not allowed" }, 403);
  try {
    return json(await runPush(pushContext()));
  } catch (e) {
    return errorResponse(e);
  }
});
