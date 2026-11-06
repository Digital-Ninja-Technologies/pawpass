import { initializePayment } from "../_shared/payments.ts";
import { callerFrom, context, corsHeaders, errorResponse, json } from "../_shared/runtime.deno.ts";

// The app sends { reference }. The amount is read from the booking, never from the request.
Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (req.method !== "POST") return json({ error: "Use POST" }, 405);
  try {
    const user = await callerFrom(req);
    const input = await req.json().catch(() => ({}));
    return json(await initializePayment(await context(), user, input));
  } catch (e) {
    return errorResponse(e);
  }
});
