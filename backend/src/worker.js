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

const TASK_MODELS = {
  // fast tier — extraction / classification
  storyAnalysis:    ["glm-4.7-flash", "glm-4.5-flash", "nvidia:meta/llama-3.3-70b-instruct"],
  matchExplanation: ["glm-4.7-flash", "glm-4.5-flash", "nvidia:meta/llama-3.3-70b-instruct"],
  // quality tier — user-facing prose. Swap the head to glm-5.3-flash (paid) if
  // free-tier limits bite AND draft polish is shown to matter.
  pitchDraft:       ["glm-4.7-flash", "glm-4.5-flash", "nvidia:meta/llama-3.3-70b-instruct"],
  pitchRewrite:     ["glm-4.7-flash", "glm-4.5-flash", "nvidia:meta/llama-3.3-70b-instruct"],
  subjectLine:      ["glm-4.7-flash", "glm-4.5-flash"],
  followUp:         ["glm-4.7-flash", "glm-4.5-flash"],
};

const SYSTEM = {
  storyAnalysis:    "Extract structured fields from a press story. Reply with JSON only: {theme,vertical,region,angle,urgency,summary,audience,subtopics:[],mediaHooks:[]}.",
  matchExplanation: "Write one plain sentence explaining why a journalist fits a story, using only the facts given.",
  pitchDraft:       "Write concise, respectful media pitches grounded only in the facts given. No hype, no invented details. Return SUBJECT: <line>\\nSHORT: <text>\\nLONG: <text>.",
  pitchRewrite:     "Rewrite the pitch to the requested tone, keeping every fact. Return SUBJECT/SHORT/LONG.",
  subjectLine:      "Write 3 short, specific email subject lines, one per line.",
  followUp:         "Write a brief, polite follow-up email.",
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

    // Cache identical requests (retrieval-before-generation is the backend's job;
    // this is the cheap first layer).
    const cacheKey = await hash(JSON.stringify({ task, tier, input, prompt }));
    const cache = caches.default;
    const cachedURL = new URL(request.url);
    cachedURL.pathname = `/cache/${cacheKey}`;
    const hit = await cache.match(cachedURL);
    if (hit) {
      const data = await hit.json();
      return json({ ...data, cached: true });
    }

    const messages = [
      { role: "system", content: SYSTEM[task] },
      { role: "user", content: buildUserContent(prompt, input) },
    ];
    const temperature = tier === "fast" ? 0.2 : 0.6;

    let lastErr = "no providers";
    for (const model of TASK_MODELS[task]) {
      try {
        const out = await callModel(model, messages, temperature, env);
        const payload = { text: out.text, model: out.model, cached: false, usage: out.usage };
        ctx.waitUntil(cache.put(cachedURL, json(payload, 200, 60 * 60 * 6))); // 6h
        return json(payload);
      } catch (e) {
        lastErr = `${model}: ${e.message || e}`;
        // 4xx that isn't 429 -> don't bother failing over
        if (e.status && e.status >= 400 && e.status < 500 && e.status !== 429) break;
      }
    }
    return json({ error: "all providers failed", detail: lastErr }, 502);
  },
};

async function callModel(model, messages, temperature, env) {
  let baseURL, apiKey, realModel;
  if (model.startsWith("nvidia:")) {
    baseURL = "https://integrate.api.nvidia.com/v1";
    apiKey = env.NVIDIA_API_KEY;
    realModel = model.slice("nvidia:".length);
  } else {
    baseURL = "https://api.z.ai/api/paas/v4";
    apiKey = env.ZAI_API_KEY;
    realModel = model;
  }
  if (!apiKey) { const err = new Error(`no key for ${model}`); err.status = 500; throw err; }

  const res = await fetch(`${baseURL}/chat/completions`, {
    method: "POST",
    headers: { "Authorization": `Bearer ${apiKey}`, "Content-Type": "application/json" },
    body: JSON.stringify({ model: realModel, messages, temperature }),
  });
  if (!res.ok) {
    const err = new Error(`HTTP ${res.status}`);
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
