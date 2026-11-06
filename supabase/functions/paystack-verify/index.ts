import { verifyPayment } from "../_shared/payments.ts";
import { callerFrom, context, corsHeaders, errorResponse, json } from "../_shared/runtime.deno.ts";

// The app asks "did my payment arrive?" after coming back from Paystack. We ask Paystack, not the app.
Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (req.method !== "POST") return json({ error: "Use POST" }, 405);
  try {
    const user = await callerFrom(req);
    const input = await req.json().catch(() => ({}));
    return json(await verifyPayment(await context(), user, input));
  } catch (e) {
    return errorResponse(e);
  }
});
