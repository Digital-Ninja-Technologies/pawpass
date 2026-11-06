import { handleWebhook } from "../_shared/payments.ts";
import { context } from "../_shared/runtime.deno.ts";

// Paystack calls this (deploy with JWT verification off: the signature is the proof).
// Set the webhook URL in the Paystack dashboard to https://<project>.supabase.co/functions/v1/paystack-webhook
Deno.serve(async (req: Request) => {
  if (req.method !== "POST") return new Response("Use POST", { status: 405 });
  const raw = await req.text();
  try {
    const out = await handleWebhook(await context(), raw, req.headers.get("x-paystack-signature"));
    return new Response(out.body, { status: out.status });
  } catch (e) {
    console.error(e);
    return new Response("try again", { status: 500 });
  }
});
