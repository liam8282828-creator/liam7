import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

const supabaseURL = Deno.env.get("SUPABASE_URL")!;
const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const anonKey = Deno.env.get("SUPABASE_ANON_KEY")!;
const admin = createClient(supabaseURL, serviceRoleKey);
const authClient = createClient(supabaseURL, anonKey);

type RequestBody = {
  action: "login" | "register";
  username: string;
  password: string;
  key: string;
  phone?: string;
};

function response(body: Record<string, unknown>, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

function normalizeUsername(value: string) {
  return value.trim().toLowerCase();
}

Deno.serve(async (request) => {
  if (request.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (request.method !== "POST") return response({ message: "Method not allowed" }, 405);

  try {
    const body = await request.json() as RequestBody;
    const username = normalizeUsername(body.username ?? "");
    const password = body.password ?? "";
    const key = body.key?.trim() ?? "";
    const phone = body.phone?.trim() ?? "";

    if (!/^[a-z0-9_.-]{3,32}$/.test(username) || password.length < 6 || key.length < 4) {
      return response({ message: "Invalid username, password or license key" }, 400);
    }

    const { data: license, error: licenseError } = await admin
      .from("licenses")
      .select("id, expires_at, is_active, user_id")
      .eq("license_key", key)
      .maybeSingle();

    if (licenseError) return response({ message: "License lookup failed" }, 500);
    if (!license || !license.is_active || new Date(license.expires_at) <= new Date()) {
      return response({ message: "License is invalid, inactive or expired" }, 403);
    }

    const email = `${username}@moonplace.invalid`;
    let userId = license.user_id;

    if (body.action === "register") {
      if (userId) return response({ message: "License has already been used" }, 409);

      const { data: existing } = await admin
        .from("profiles")
        .select("id")
        .eq("username", username)
        .maybeSingle();
      if (existing) return response({ message: "Username already exists" }, 409);

      const { data: created, error: createError } = await admin.auth.admin.createUser({
        email,
        password,
        email_confirm: true,
        user_metadata: { username },
      });
      if (createError || !created.user) return response({ message: createError?.message ?? "User creation failed" }, 400);
      userId = created.user.id;

      const { error: profileError } = await admin.from("profiles").insert({
        id: userId,
        username,
        phone,
        expires_at: license.expires_at,
        is_active: true,
      });
      if (profileError) {
        await admin.auth.admin.deleteUser(userId);
        return response({ message: "Profile creation failed" }, 500);
      }

      const { error: claimError } = await admin
        .from("licenses")
        .update({ user_id: userId })
        .eq("id", license.id)
        .is("user_id", null);
      if (claimError) return response({ message: "License claim failed" }, 500);
    }

    if (body.action === "login" && !userId) {
      return response({ message: "Account is not registered" }, 401);
    }

    const { data: signedIn, error: signInError } = await authClient.auth.signInWithPassword({ email, password });
    if (signInError || !signedIn.session || !userId) {
      return response({ message: signInError?.message ?? "Login failed" }, 401);
    }

    return response({
      access_token: signedIn.session.access_token,
      refresh_token: signedIn.session.refresh_token,
      username,
      phone,
      expires_at: license.expires_at,
    });
  } catch {
    return response({ message: "Malformed request" }, 400);
  }
});
