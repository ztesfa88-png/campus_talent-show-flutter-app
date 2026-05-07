// Edge Function: delete-user
// Fully deletes a user from auth.users + all cascaded rows.
// Requires admin role. Deploy with:
//   supabase functions deploy delete-user --no-verify-jwt
//
// NOTE: This file uses Deno/ESM syntax. Editor errors about "Cannot find
// module" or "Cannot find name Deno" are false positives from the Node/TS
// LSP — install the Deno VS Code extension to resolve them. The function
// deploys and runs correctly on Supabase Edge Runtime.
//
// @ts-nocheck

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

declare const Deno: {
  serve: (handler: (req: Request) => Promise<Response>) => void;
  env: { get: (key: string) => string | undefined };
};

const cors: Record<string, string> = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), {
    status,
    headers: { ...cors, "Content-Type": "application/json" },
  });

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });

  try {
    // 1. Parse body
    const { user_id } = (await req.json()) as { user_id?: string };
    if (!user_id) return json({ error: "user_id is required" }, 400);

    // 2. Get the Authorization header
    const authHeader = req.headers.get("Authorization") ?? "";
    if (!authHeader) return json({ error: "Missing Authorization header" }, 401);

    const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
    const anonKey = Deno.env.get("SUPABASE_ANON_KEY") ?? "";
    const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";

    // 3. Verify caller identity using their JWT
    const callerClient = createClient(supabaseUrl, anonKey, {
      global: { headers: { Authorization: authHeader } },
    });

    const { data: { user: caller }, error: authErr } =
      await callerClient.auth.getUser();
    if (authErr || !caller) return json({ error: "Unauthorized" }, 401);

    // 4. Verify admin role — use service role client to bypass RLS
    //    (avoids issues where the caller's RLS policy blocks reading their own role)
    const adminClient = createClient(supabaseUrl, serviceKey);

    const { data: callerRow } = await adminClient
      .from("users")
      .select("role")
      .eq("id", caller.id)
      .single();

    if ((callerRow as any)?.role !== "admin") {
      return json({ error: "Forbidden: admin role required" }, 403);
    }

    // 5. Prevent self-deletion
    if (caller.id === user_id) {
      return json({ error: "Cannot delete your own account" }, 400);
    }

    // 6. Delete via service role key — cascades to all tables
    const { error: deleteErr } =
      await adminClient.auth.admin.deleteUser(user_id);
    if (deleteErr) return json({ error: deleteErr.message }, 500);

    return json({ success: true, deleted_user_id: user_id });
  } catch (e) {
    return json({ error: String(e) }, 500);
  }
});
