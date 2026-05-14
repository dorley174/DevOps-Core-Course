# Lab 17 Edge API

Cloudflare Workers TypeScript API for Lab 17.

## Routes

| Route | Purpose |
|---|---|
| `/` | Application information and route list |
| `/health` | Health check JSON response |
| `/metadata` | Deployment/runtime metadata |
| `/edge` | Cloudflare edge metadata from `request.cf` |
| `/counter` | Workers KV-backed persisted counter |
| `/config` | Plaintext variable and secret status check |
| `/admin` | Secret-protected route using `API_TOKEN` |

## Local development

```bash
cd edge-api
npm install
cp .dev.vars.example .dev.vars
npx wrangler dev --local
```

## Required Cloudflare setup

```bash
npx wrangler login
npx wrangler whoami
npx wrangler kv namespace create SETTINGS
npx wrangler secret put API_TOKEN
npx wrangler secret put ADMIN_EMAIL
npx wrangler deploy
```

Update `wrangler.jsonc` with the real KV namespace ID returned by Wrangler before deploying.
