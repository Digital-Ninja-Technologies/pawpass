import { deleteAccount } from "../_shared/accounts.ts";
import {
  accountContext,
  callerFrom,
  corsHeaders,
  errorResponse,
  json,
} from "../_shared/runtime.deno.ts";

// The app sends { confirm: "DELETE" } with the person's own access token. Deploy with JWT verification off: the
// function checks the token itself. See supabase/migrations/20261114100000_delete_account.sql.
Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (req.method !== "POST") return json({ error: "Use POST" }, 405);
  try {
    const user = await callerFrom(req);
    const input = await req.json().catch(() => ({}));
    return json(await deleteAccount(accountContext(), user, input));
  } catch (e) {
    return errorResponse(e);
  }
});
