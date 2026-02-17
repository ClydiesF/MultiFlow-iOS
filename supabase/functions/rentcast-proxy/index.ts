import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

type Endpoint = "markets" | "avm_rent" | "avm_value" | "properties";

const CORS_HEADERS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "GET,POST,OPTIONS",
};

const ENDPOINT_CONFIG: Record<Endpoint, { path: string; cost: number; requiredParam: string }> = {
  markets: { path: "/v1/markets", cost: 1, requiredParam: "zipCode" },
  avm_rent: { path: "/v1/avm/rent/long-term", cost: 1, requiredParam: "address" },
  avm_value: { path: "/v1/avm/value", cost: 1, requiredParam: "address" },
  properties: { path: "/v1/properties", cost: 2, requiredParam: "address" },
};

function monthKey(date = new Date()): string {
  const yyyy = date.getUTCFullYear();
  const mm = String(date.getUTCMonth() + 1).padStart(2, "0");
  return `${yyyy}-${mm}`;
}

function badRequest(message: string): Response {
  return new Response(JSON.stringify({ error: message }), {
    status: 400,
    headers: { "Content-Type": "application/json", ...CORS_HEADERS },
  });
}

function unauthorized(message = "Unauthorized"): Response {
  return new Response(JSON.stringify({ error: message }), {
    status: 401,
    headers: { "Content-Type": "application/json", ...CORS_HEADERS },
  });
}

function forbidden(message: string): Response {
  return new Response(JSON.stringify({ error: message }), {
    status: 403,
    headers: { "Content-Type": "application/json", ...CORS_HEADERS },
  });
}

function serverError(message: string): Response {
  return new Response(JSON.stringify({ error: message }), {
    status: 500,
    headers: { "Content-Type": "application/json", ...CORS_HEADERS },
  });
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: CORS_HEADERS });
  }

  const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
  const SUPABASE_ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY") ?? "";
  const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
  const RENTCAST_API_KEY = Deno.env.get("RENTCAST_API_KEY") ?? "";

  if (!SUPABASE_URL || !SUPABASE_ANON_KEY || !SUPABASE_SERVICE_ROLE_KEY || !RENTCAST_API_KEY) {
    return serverError("Missing required edge function secrets.");
  }

  const authHeader = req.headers.get("Authorization");
  if (!authHeader) {
    return unauthorized("Missing Authorization header.");
  }

  const userClient = createClient(SUPABASE_URL, SUPABASE_ANON_KEY, {
    global: { headers: { Authorization: authHeader } },
  });
  const serviceClient = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);

  const userResult = await userClient.auth.getUser();
  const user = userResult.data.user;
  if (!user) {
    return unauthorized("Invalid auth token.");
  }

  let endpoint: Endpoint | null = null;
  let params: Record<string, string> = {};

  if (req.method === "GET") {
    const url = new URL(req.url);
    endpoint = (url.searchParams.get("endpoint") as Endpoint | null) ?? null;
    for (const [k, v] of url.searchParams.entries()) {
      if (k !== "endpoint") params[k] = v;
    }
  } else if (req.method === "POST") {
    const body = await req.json().catch(() => null);
    endpoint = (body?.endpoint as Endpoint | undefined) ?? null;
    params = (body?.params as Record<string, string> | undefined) ?? {};
  } else {
    return badRequest("Unsupported method.");
  }

  if (!endpoint || !(endpoint in ENDPOINT_CONFIG)) {
    return badRequest("Invalid endpoint.");
  }

  const config = ENDPOINT_CONFIG[endpoint];
  const required = params[config.requiredParam];
  if (!required || !required.trim()) {
    return badRequest(`Missing required param: ${config.requiredParam}`);
  }

  const thisMonth = monthKey();

  const consume = await serviceClient.rpc("consume_api_credits", {
    p_user_id: user.id,
    p_month_key: thisMonth,
    p_cost: config.cost,
    p_default_quota: 25,
  });

  if (consume.error) {
    return serverError(`Credit check failed: ${consume.error.message}`);
  }

  const consumeRow = Array.isArray(consume.data) ? consume.data[0] : consume.data;
  if (!consumeRow?.allowed) {
    const remaining = consumeRow?.remaining_credits ?? 0;
    return forbidden(`Monthly API quota reached. Remaining credits: ${remaining}`);
  }

  try {
    const rentcastUrl = new URL(`https://api.rentcast.io${config.path}`);
    for (const [k, v] of Object.entries(params)) {
      if (v !== undefined && v !== null && `${v}`.trim() !== "") {
        rentcastUrl.searchParams.set(k, `${v}`);
      }
    }

    const upstream = await fetch(rentcastUrl.toString(), {
      method: "GET",
      headers: { "X-Api-Key": RENTCAST_API_KEY },
    });

    const payload = await upstream.text();

    if (!upstream.ok) {
      await serviceClient.rpc("refund_api_credits", {
        p_user_id: user.id,
        p_month_key: thisMonth,
        p_cost: config.cost,
      });

      return new Response(payload, {
        status: upstream.status,
        headers: { "Content-Type": "application/json", ...CORS_HEADERS },
      });
    }

    return new Response(
      JSON.stringify({
        endpoint,
        credits: {
          cost: config.cost,
          used: consumeRow?.used_credits ?? null,
          remaining: consumeRow?.remaining_credits ?? null,
          quota: consumeRow?.quota_credits ?? 25,
        },
        data: JSON.parse(payload),
      }),
      {
        status: 200,
        headers: { "Content-Type": "application/json", ...CORS_HEADERS },
      },
    );
  } catch (error) {
    await serviceClient.rpc("refund_api_credits", {
      p_user_id: user.id,
      p_month_key: thisMonth,
      p_cost: config.cost,
    });
    const message = error instanceof Error ? error.message : "Unknown proxy failure";
    return serverError(message);
  }
});
