/**
 * Pitchwire AI gateway — Cloudflare Worker.
 *
 * The app talks ONLY to this. Provider keys (z.ai, NVIDIA) live in Worker
 * secrets, never in the app. Implements the contract HTTPGateway expects:
 *
 *   POST /v1/generate
 *   Authorization: Bearer <PITCHWIRE_CLIENT_TOKEN>
 *   { "task", "tier", "input": {..}, "prompt" }
 *   -> 200 { "text", "model", "cached", "usage": { "inputTokens", "outputTokens" } }
 *
 * Failover chain per tier:  GLM-4.7-Flash -> GLM-4.5-Flash -> NVIDIA NIM (all free).
 * A z.ai rate-limit is invisible to the user.
 */

// Failover chain (all free).
//
// z.ai's API is fronted by Aliyun, which blocks Cloudflare Worker egress IPs
// (405 "zh-cn" WAF page — the API works fine from a normal host). Until the
// gateway moves off Cloudflare or proxies z.ai (e.g. via OpenRouter), NVIDIA NIM
// carries the chain. z.ai stays listed so it lights up the moment it's reachable.
//
// Verify these IDs periodically — z.ai renames its flash tier and NVIDIA retires
// models on a schedule (llama-3.1/3.3 were retired 2026-08-26).
// Providers, all free:
//  - nvidia:  NVIDIA NIM shared endpoint. Only hosts the OpenAI gpt-oss models
//             for a standard account (the rest of /v1/models needs a paid NIM).
//  - openrouter:  many `:free` models incl. GLM; not Cloudflare-blocked, so it
//             also gives us GLM back. `:free` tier is 50/day (1000/day with
//             $10+ credit on the account).
//  - z.ai direct:  Aliyun-blocked from Cloudflare — dormant, kept for a non-CF host.
// Confirmed reachable + free (probed 2026-08-29). GLM-5.2 via OpenRouter 429s
// intermittently but recovers. The OpenRouter NVIDIA-Nemotron / Laguna / Liquid
// models 404 with "no endpoints matching your data policy" until the account
// enables Settings → Privacy → allow prompt-training providers — add them here
// if that gets turned on.
const NV_120     = "nvidia:openai/gpt-oss-120b";
const NV_20      = "nvidia:openai/gpt-oss-20b";
const OR_GLM     = "openrouter:z-ai/glm-5.2:free";
const OR_MINIMAX = "openrouter:minimax/minimax-m2.7:free";
const OR_MINIMAX3 = "openrouter:minimax/minimax-m3:free";
const OR_DOTS    = "openrouter:dots-studio/dots-3-note-preview:free";
const GLM_DIRECT = ["glm-4.7-flash", "glm-4.5-flash"];   // Aliyun-blocked from Cloudflare; kept for a non-CF host
const TASK_MODELS = {
  // fast tier — extraction / classification
  storyAnalysis:    [NV_20, OR_MINIMAX3, OR_GLM, NV_120, ...GLM_DIRECT],
  matchExplanation: [NV_20, OR_MINIMAX3, OR_GLM, NV_120, ...GLM_DIRECT],
  subjectLine:      [NV_20, OR_MINIMAX3, OR_GLM, NV_120, ...GLM_DIRECT],
  // quality tier — user-facing prose. Add glm-5.3-flash (paid) to the head if
  // free capacity ever becomes the bottleneck.
  pitchDraft:       [OR_GLM, NV_120, OR_MINIMAX, OR_DOTS, NV_20, ...GLM_DIRECT],
  pitchRewrite:     [OR_GLM, NV_120, OR_MINIMAX, OR_DOTS, NV_20, ...GLM_DIRECT],
  followUp:         [OR_GLM, NV_120, OR_MINIMAX, NV_20, ...GLM_DIRECT],
};

const SYSTEM = {
  storyAnalysis:
    "Extract structured fields from a press story. Reply with ONLY a JSON object, no prose, no markdown fences. " +
    "Keys and allowed values: " +
    "theme (short noun phrase), " +
    "vertical (one of: ai, developer tools, consumer, fintech, general tech), " +
    "region (one of: US, EU, Global), " +
    "angle (one of: product launch, funding, acquisition, hire, partnership, general news), " +
    "urgency (one of: standard, time-sensitive), " +
    "summary (<=220 chars), " +
    "audience (one of: Developers, Founders & investors, Businesses & teams, Consumers), " +
    "subtopics (array of <=5 short strings), " +
    "mediaHooks (array of <=4 short phrases: why a journalist would care).",
  matchExplanation:
    "Write ONE plain sentence (max 30 words) explaining why a journalist is worth pitching this " +
    "story, using ONLY the beat and bylines given. Refer to them by name or 'they' — never assume " +
    "he/she. No greeting, no markdown.",
  pitchDraft:
    "Write a concise, respectful media pitch grounded ONLY in the facts given — no hype, no invented details. " +
    "Output EXACTLY this format, plain text, no markdown, no asterisks, no headers:\n" +
    "SUBJECT: <one line>\nSHORT: <2-3 sentence pitch>\nLONG: <1-2 short paragraph pitch>",
  pitchRewrite:
    "Rewrite the pitch to the requested tone, keeping every fact. Same plain format: SUBJECT: / SHORT: / LONG:. No markdown.",
  subjectLine:
    "Write 3 short, specific email subject lines, one per line. No numbering, no markdown.",
  followUp:
    "Write a brief, polite follow-up email. Plain text.",
};

export default {
  async fetch(request, env, ctx) {
    if (request.method !== "POST") return json({ error: "POST only" }, 405);
    const url = new URL(request.url);
    if (url.pathname !== "/v1/generate") return json({ error: "not found" }, 404);

    // Auth — a scoped, rotatable client token (NOT a provider key).
    const auth = request.headers.get("Authorization") || "";
    if (auth !== `Bearer ${env.PITCHWIRE_CLIENT_TOKEN}`) {
      return json({ error: "unauthorized" }, 401);
    }

    // Light abuse protection: per-IP rate limit via the Cache API.
    const ip = request.headers.get("CF-Connecting-IP") || "anon";
    if (await rateLimited(ip, env)) return json({ error: "rate limited" }, 429);

    let body;
    try { body = await request.json(); } catch { return json({ error: "bad json" }, 400); }
    const { task, tier, input = {}, prompt = "" } = body;
    if (!TASK_MODELS[task]) return json({ error: `unknown task ${task}` }, 400);

    // ?only=<model> forces a single provider — for verifying a model works.
    // Authed by the same client token; not cached.
    const only = url.searchParams.get("only");
    const chain = only ? [only] : TASK_MODELS[task];

    // Cache identical requests (retrieval-before-generation is the backend's job;
    // this is the cheap first layer). Skipped when forcing a model.
    const cacheKey = await hash(JSON.stringify({ task, tier, input, prompt }));
    const cache = caches.default;
    const cachedURL = new URL(request.url);
    cachedURL.pathname = `/cache/${cacheKey}`;
    if (!only) {
      const hit = await cache.match(cachedURL);
      if (hit) {
        const data = await hit.json();
        return json({ ...data, cached: true });
      }
    }

    const messages = [
      { role: "system", content: SYSTEM[task] },
      { role: "user", content: buildUserContent(prompt, input) },
    ];
    const temperature = tier === "fast" ? 0.2 : 0.6;

    const errs = [];
    for (const model of chain) {
      try {
        const out = await callModel(model, messages, temperature, env);
        const payload = { text: out.text, model: out.model, cached: false, usage: out.usage };
        if (!only) ctx.waitUntil(cache.put(cachedURL, json(payload, 200, 60 * 60 * 6))); // 6h
        return json(payload);
      } catch (e) {
        const line = `${model}: ${e.message || e}`;
        errs.push(line);
        console.log("provider failed:", line);
        if (e.status === 401 || e.status === 403) break;
      }
    }
    return json({ error: "all providers failed", detail: errs }, 502);
  },
};

async function callModel(model, messages, temperature, env) {
  let baseURL, apiKey, realModel;
  const extraHeaders = {};
  if (model.startsWith("nvidia:")) {
    baseURL = "https://integrate.api.nvidia.com/v1";
    apiKey = env.NVIDIA_API_KEY || env.NVIDIA_API_Key;   // tolerate the secret-name casing
    realModel = model.slice("nvidia:".length);
  } else if (model.startsWith("openrouter:")) {
    baseURL = "https://openrouter.ai/api/v1";
    apiKey = env.OPENROUTER_API_KEY;
    realModel = model.slice("openrouter:".length);
    extraHeaders["HTTP-Referer"] = "https://github.com/AvaJ845/Pitchwire";
    extraHeaders["X-Title"] = "Pitchwire";
  } else {
    baseURL = "https://api.z.ai/api/paas/v4";
    apiKey = env.ZAI_API_KEY;
    realModel = model;
  }
  if (!apiKey) { const err = new Error(`no key for ${model}`); err.status = 500; throw err; }

  const res = await fetch(`${baseURL}/chat/completions`, {
    method: "POST",
    headers: {
      "Authorization": `Bearer ${apiKey}`,
      "Content-Type": "application/json",
      "Accept": "application/json",
      // Aliyun-fronted APIs (z.ai) 405 requests without a UA.
      "User-Agent": "Pitchwire/1.0 (+https://github.com/AvaJ845/Pitchwire)",
      ...extraHeaders,
    },
    body: JSON.stringify({ model: realModel, messages, temperature, stream: false, max_tokens: 900 }),
  });
  if (!res.ok) {
    const body = (await res.text().catch(() => "")).slice(0, 300);
    const err = new Error(`HTTP ${res.status} ${body}`);
    err.status = res.status;
    throw err;
  }
  const data = await res.json();
  const text = data?.choices?.[0]?.message?.content;
  if (!text) { const err = new Error("empty completion"); err.status = 502; throw err; }
  return {
    text,
    model: data.model || realModel,
    usage: data.usage
      ? { inputTokens: data.usage.prompt_tokens ?? 0, outputTokens: data.usage.completion_tokens ?? 0 }
      : null,
  };
}

function buildUserContent(prompt, input) {
  const facts = Object.entries(input).map(([k, v]) => `${k}: ${v}`).join("\n");
  return facts ? `${prompt}\n\n${facts}` : prompt;
}

async function rateLimited(ip, env) {
  const limit = Number(env.RATE_LIMIT_PER_MIN || 20);
  const cache = caches.default;
  const key = new URL(`https://rl.pitchwire/${ip}/${Math.floor(Date.now() / 60000)}`);
  const cur = await cache.match(key);
  const count = cur ? Number(await cur.text()) : 0;
  if (count >= limit) return true;
  await cache.put(key, new Response(String(count + 1), { headers: { "Cache-Control": "max-age=70" } }));
  return false;
}

async function hash(s) {
  const buf = await crypto.subtle.digest("SHA-256", new TextEncoder().encode(s));
  return [...new Uint8Array(buf)].map((b) => b.toString(16).padStart(2, "0")).join("");
}

function json(obj, status = 200, maxAge = 0) {
  return new Response(JSON.stringify(obj), {
    status,
    headers: {
      "Content-Type": "application/json",
      ...(maxAge ? { "Cache-Control": `max-age=${maxAge}` } : {}),
    },
  });
}
