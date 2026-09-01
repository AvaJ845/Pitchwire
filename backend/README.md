# Pitchwire AI gateway

The thin backend from the AI Infrastructure Direction. A single Cloudflare Worker:
the app calls it, it holds the provider keys and runs the failover chain.
API-first, no servers, no GPU ops. **Deployed and live** at
`pitchwire-ai.divine-mountain-8173.workers.dev`.

## What it does

```
app ──POST /v1/generate──▶ Worker ──▶ OpenRouter :free  (GLM-5.2, Nemotron-3.5-Lightning, …)
   Bearer <client token>            └▶ NVIDIA NIM       (gpt-oss-120b / -20b)
                                    └▶ z.ai GLM direct  (dormant — Aliyun blocks CF)
◀── { text, model, cached, usage } ─┘
```

Providers are prefixed in the model id: `openrouter:z-ai/glm-5.2:free`,
`nvidia:openai/gpt-oss-120b`, or a bare `glm-4.7-flash` for z.ai direct.

- Provider keys live in Worker secrets, never in the app.
- Identical requests are cached 6h (Cache API).
- Per-IP rate limit (default 20/min) as light abuse protection. **Caveat:** the
  CF Cache API is per-colo, not global, and the check is best-effort — it slows a
  single abuser, it does not hard-cap spend. The real backstops are the provider
  free-tier daily caps and `PAID_FALLBACK_ENABLED=0`. Move to a Durable Object /
  KV counter before opening this up to real volume.
- Bearer-token check is a constant-time digest compare; request bodies are capped
  at 64 KB; the failed-provider response no longer echoes upstream error bodies.
- Task → model map + system prompts live in `src/worker.js` — change routing
  there, nothing in the app moves. `fast` tasks lead with gpt-oss-20b,
  `quality` tasks with gpt-oss-120b.

### Known limitation — z.ai on Cloudflare

z.ai's API is fronted by Aliyun, which **blocks Cloudflare Worker egress IPs**
(returns a 405 `zh-cn` WAF page — the API works fine from a normal host). So on
Cloudflare, **NVIDIA NIM carries the chain** and the z.ai entries are effectively
dead. They light up automatically if the gateway moves off Cloudflare (Deno
Deploy / Fly / a VPS) or proxies z.ai via OpenRouter. NVIDIA's free tier
(~40 rpm) is plenty for now.

Model IDs drift — z.ai renames its flash tier, NVIDIA retired llama-3.1/3.3 on
2026-08-26. If calls start 410ing, check `GET https://integrate.api.nvidia.com/v1/models`
and update the model constants in `src/worker.js`.

**NVIDIA free tier only serves the OpenAI gpt-oss models** for a standard
developer account. The rest of the `/v1/models` catalog (kimi, deepseek,
nemotron, llama-4, qwen, …) returns `404 "Not found for account"` — those need a
dedicated, paid NIM deployment. To widen the free pool without GPUs, add
**OpenRouter** as a provider in `callModel()`: many `:free` models
(`deepseek/deepseek-chat-v3-0324:free`, `meta-llama/llama-3.3-70b-instruct:free`,
`google/gemini-2.0-flash-exp:free`, …), one key, and its infra isn't
Cloudflare-blocked so z.ai's GLM models become reachable through it too.

### Free models — probed 2026-08-29

| Model | Via | Status |
|---|---|---|
| `openai/gpt-oss-120b` | NVIDIA | ✅ in chain (quality) |
| `openai/gpt-oss-20b` | NVIDIA | ✅ in chain (fast) |
| `z-ai/glm-5.2:free` | OpenRouter | ✅ in chain — 429s intermittently, recovers |
| `minimax/minimax-m2.7:free` | OpenRouter | ✅ in chain |
| `minimax/minimax-m3:free` | OpenRouter | ✅ in chain |
| `dots-studio/dots-3-note-preview:free` | OpenRouter | ✅ in chain |
| `inclusionai/ling-3.0-flash-fin:free` | OpenRouter | ✅ works but very verbose |
| `cohere/north-mini-code:free` | OpenRouter | ✅ works (code model) |
| `openrouter/free` | OpenRouter | ✅ works but hugely verbose (rotating meta-model) |
| `google/gemma-4-31b-it:free`, `gemma-4-26b:free` | OpenRouter | ⚠️ 429 (upstream overloaded) |
| `nvidia/nemotron-3.5-lightning:free`, `-3-super`, `-3-ultra`, `-3-nano` | OpenRouter | ❌ 404 — needs Privacy setting (below) |
| `poolside/laguna-*:free`, `liquid/lfm-2.5:free` | OpenRouter | ❌ 404 — needs Privacy setting |
| `thinkingmachines/inkling*:free` | OpenRouter | ❌ 403 — agentic-harness only |

**To unlock the Nemotron / Laguna / Liquid models:** OpenRouter → Settings →
Privacy → allow "providers that may train on your inputs". Then add those model
ids to `TASK_MODELS` in `src/worker.js`.

### Removal / issue reports

`POST /v1/removal-request` (same `Authorization: Bearer` token) —
`{ journalistName, journalistID, reason }`, **editorial context only, no user
data**. Logged (`wrangler tail`) and, if `REMOVAL_WEBHOOK_URL` is set, forwarded
as `{text}` to that Slack/Discord/Zapier webhook. The app also keeps a local
copy in the Research Lab. **A monitored inbox + real 48-hour takedown is on the
operator** — the app already promises that window in its UI.

### Debug

`POST /v1/generate?only=nvidia:openai/gpt-oss-20b` forces one provider and skips
the cache — for checking whether a model is actually reachable. `only` must be a
model that already appears in `TASK_MODELS`; anything else (including the paid
`OR_PAID`) is rejected, so a leaked client token can't force paid spend.

## Deploy A — Cloudflare dashboard (no local install)

1. [dash.cloudflare.com](https://dash.cloudflare.com) → **Workers & Pages** → **Create** →
   **Create Worker** → name `pitchwire-ai` → deploy the default.
2. **Edit code** → replace everything with `src/worker.js` → **Deploy**.
3. **Settings → Variables and Secrets**:
   - Secret `ZAI_API_KEY` = z.ai key
   - Secret `NVIDIA_API_KEY` = NVIDIA key *(optional; skip → chain ends at GLM-4.5)*
   - Secret `PITCHWIRE_CLIENT_TOKEN` = `openssl rand -hex 32`
   - Variable `RATE_LIMIT_PER_MIN` = `20`
4. **Settings → Runtime** → set Compatibility date to a recent date.
5. URL: `https://pitchwire-ai.<subdomain>.workers.dev`

## Deploy B — wrangler CLI (about 10 minutes)

Needs Node (nodejs.org `.pkg`, no Homebrew required).

```bash
npm install -g wrangler
cd backend
wrangler login

# 1. Create the provider keys (both have a free tier):
#    z.ai:    https://z.ai            → API Keys page
#    NVIDIA:  https://build.nvidia.com → free API key (verify commercial-use ToS)

# 2. Make a client token (any long random string):
openssl rand -hex 32          # copy this

# 3. Set the secrets:
wrangler secret put ZAI_API_KEY
wrangler secret put NVIDIA_API_KEY
wrangler secret put PITCHWIRE_CLIENT_TOKEN     # paste the token from step 2

# 4. Ship it:
wrangler deploy
# → https://pitchwire-ai.<your-subdomain>.workers.dev
```

## Point the app at it

The app reads `AIConfiguration.baseURL` / `.clientToken`. For the MVP (no
accounts yet) inject them at build time from a **gitignored** xcconfig so the
token isn't in the repo:

`Pitchwire/Config/Secrets.xcconfig` (add to `.gitignore`):
```
PITCHWIRE_AI_BASE_URL = https:/$()/pitchwire-ai.<sub>.workers.dev
PITCHWIRE_AI_CLIENT_TOKEN = <the token>
```
then in `project.yml` add `configFiles: { debug: Config/Secrets.xcconfig, ... }`
and read them in `PitchwireApp.init` via `Bundle.main.infoDictionary`
(`INFOPLIST_KEY_…` passthrough), building a real `AIConfiguration` instead of
`.offline`.

The client token is **not** a provider key — worst case someone burns the free
z.ai quota, not money. Rotate it with `wrangler secret put` any time. Replace it
with per-user tokens when accounts land.

## Test it

```bash
curl -s https://pitchwire-ai.<sub>.workers.dev/v1/generate \
  -H "Authorization: Bearer <token>" -H "Content-Type: application/json" \
  -d '{"task":"pitchDraft","tier":"quality","input":{"recipient":"Test"},"prompt":"Draft a pitch."}' | jq
```
