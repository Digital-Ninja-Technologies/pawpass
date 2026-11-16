import { adminDeleteAccount } from "../_shared/accounts.ts";
import {
  adminAccountContext,
  callerFrom,
  corsHeaders,
  errorResponse,
  json,
} from "../_shared/runtime.deno.ts";

// The admin console sends { user, reason } with the signed in staff member's own access token. Deploy with JWT
// verification off: the function checks the token itself, and that the caller is an active full admin.
// See supabase/migrations/20261122100000_admin_delete_account.sql.
Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (req.method !== "POST") return json({ error: "Use POST" }, 405);
  try {
    const admin = await callerFrom(req);
    const input = await req.json().catch(() => ({}));
    return json(await adminDeleteAccount(adminAccountContext(), admin, input));
  } catch (e) {
    return errorResponse(e);
  }
});
