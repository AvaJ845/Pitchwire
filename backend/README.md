# Pitchwire AI gateway

The thin backend from the AI Infrastructure Direction. A single Cloudflare Worker:
the app calls it, it holds the provider keys and runs the GLM → GLM → NVIDIA
failover. API-first, no servers, no GPU ops.

## What it does

```
app ──POST /v1/generate──▶ Worker ──▶ z.ai GLM-4.7-Flash   (free)
   Bearer <client token>            └▶ z.ai GLM-4.5-Flash   (free, on 429/5xx)
                                    └▶ NVIDIA NIM            (free, last resort)
◀── { text, model, cached, usage } ─┘
```

- Provider keys live in Worker secrets, never in the app.
- Identical requests are cached 6h (Cache API).
- Per-IP rate limit (default 20/min) as light abuse protection.
- Task → model map + system prompts live in `src/worker.js` — change routing
  there, nothing in the app moves.

## Deploy (about 10 minutes)

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

`BeatMatch/Config/Secrets.xcconfig` (add to `.gitignore`):
```
PITCHWIRE_AI_BASE_URL = https:/$()/pitchwire-ai.<sub>.workers.dev
PITCHWIRE_AI_CLIENT_TOKEN = <the token>
```
then in `project.yml` add `configFiles: { debug: Config/Secrets.xcconfig, ... }`
and read them in `BeatMatchApp.init` via `Bundle.main.infoDictionary`
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
