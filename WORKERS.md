# Lab 17 — Cloudflare Workers Edge Deployment Report

## Deployment Summary

This lab implements and deploys a serverless HTTP API using Cloudflare Workers and Wrangler. The Worker is deployed to the public `workers.dev` domain and uses Cloudflare Workers KV for persistence, plaintext environment variables for non-sensitive configuration, and Wrangler secrets for sensitive values.

| Item | Value |
|---|---|
| Worker name | `devops-lab17-edge-api` |
| Public URL | `https://devops-lab17-edge-api.dan4ikv74.workers.dev` |
| Runtime | Cloudflare Workers |
| Language | TypeScript |
| Deployment URL type | `workers.dev` |
| KV namespace binding | `SETTINGS` |
| KV namespace ID | `6dbf1d05620a4e4399ef78b278df34bd` |
| Current app version | `v1.0.0` |
| Latest observed version ID | `724815f9-624e-4545-bcb4-f8f8fda252e2` |
| Account email shown in deployments | `dan4ikv74@gmail.com` |

Screenshot evidence: [Cloudflare Worker dashboard](edge-api/screenshots/01-cloudflare-worker-dashboard.png)

---

## Task 1 — Cloudflare Setup

### Cloudflare Account and Workers Access

A Cloudflare account was used to access the Workers & Pages dashboard. The Worker `devops-lab17-edge-api` is visible in the Cloudflare dashboard, and the dashboard shows the deployed `workers.dev` URL, bindings, metrics, and version history.

Evidence:

- [Cloudflare Worker dashboard](edge-api/screenshots/01-cloudflare-worker-dashboard.png)
- [Wrangler whoami](edge-api/screenshots/02-wrangler-whoami.png)

### Wrangler Authentication

Wrangler was used to authenticate and interact with the Cloudflare account.

```powershell
npx wrangler login
npx wrangler whoami
```

### Workers Project

The Worker project is located in:

```text
edge-api/
```

Main project files:

```text
edge-api/src/index.ts
edge-api/package.json
edge-api/tsconfig.json
edge-api/wrangler.jsonc
```

The Worker configuration file is `edge-api/wrangler.jsonc`.

### `wrangler.jsonc` Configuration

```jsonc
{
  "$schema": "node_modules/wrangler/config-schema.json",
  "name": "devops-lab17-edge-api",
  "main": "src/index.ts",
  "compatibility_date": "2025-09-01",
  "workers_dev": true,
  "observability": {
    "enabled": true
  },
  "vars": {
    "APP_NAME": "devops-lab17-edge-api",
    "COURSE_NAME": "devops-core-course",
    "APP_VERSION": "v1.0.0",
    "ENVIRONMENT": "lab17"
  },
  "kv_namespaces": [
    {
      "binding": "SETTINGS",
      "id": "6dbf1d05620a4e4399ef78b278df34bd"
    }
  ]
}
```

---

## Task 2 — Build and Deploy a Worker API

### Implemented Routes

The Worker exposes the following HTTP routes:

| Route | Purpose |
|---|---|
| `/` | General application information and route list |
| `/health` | Health check endpoint |
| `/metadata` | Deployment and runtime metadata |
| `/edge` | Cloudflare edge request metadata |
| `/counter` | KV-backed persisted visit counter |
| `/config` | Configuration status, including vars and secret presence |
| `/admin` | Secret-protected endpoint using `API_TOKEN` |

### Public Root Endpoint

Command:

```powershell
$env:WORKER_URL = "https://devops-lab17-edge-api.dan4ikv74.workers.dev"
Invoke-RestMethod "$env:WORKER_URL/"
```

Observed response:

```text
app         : devops-lab17-edge-api
course      : devops-core-course
version     : v1.0.0
environment : lab17
message     : Hello from Cloudflare Workers edge runtime
routes      : {/health, /metadata, /edge, /counter...}
timestamp   : 2026-05-14T14:00:00.819Z
```

Screenshot evidence: [Worker root response](edge-api/screenshots/03-worker-root-response.png)

### Health Endpoint

Command:

```powershell
Invoke-RestMethod "$env:WORKER_URL/health"
```

Observed response:

```text
status app                   version timestamp
------ ---                   ------- ---------
ok     devops-lab17-edge-api v1.0.0  2026-05-14T14:03:36.961Z
```

### Metadata Endpoint

Command:

```powershell
Invoke-RestMethod "$env:WORKER_URL/metadata"
```

Observed response:

```text
app             : devops-lab17-edge-api
course          : devops-core-course
version         : v1.0.0
runtime         : Cloudflare Workers
deploymentModel : serverless edge worker
persistence     : Workers KV binding SETTINGS
publicRouting   : workers.dev enabled
requestId       : 005b6458-9e60-4ae0-a4ec-0a6157f3873c
```

### Deployment

The Worker was deployed with Wrangler:

```powershell
npx wrangler deploy
```

Observed deployment output:

```text
Uploaded devops-lab17-edge-api
Deployed devops-lab17-edge-api triggers
  https://devops-lab17-edge-api.dan4ikv74.workers.dev
Current Version ID: fc83d47a-55f6-422c-984b-9de66c43d23a
```

A later redeploy produced the following version ID:

```text
Current Version ID: 724815f9-624e-4545-bcb4-f8f8fda252e2
```

---

## Task 3 — Global Edge Behavior

### Edge Metadata Endpoint

Command:

```powershell
Invoke-RestMethod "$env:WORKER_URL/edge"
```

Observed response:

```text
colo         : ARN
country      : SE
city         : Stockholm
asn          : 202053
httpProtocol : HTTP/1.1
tlsVersion   : TLSv1.3
note         : These values are populated by Cloudflare on deployed workers.dev requests. Some fields may be null during local development.
```

Screenshot evidence: [Edge response](edge-api/screenshots/04-edge-response.png)

### Edge Metadata Explanation

The `/edge` endpoint proves that the Worker is running on Cloudflare’s edge network because the response includes metadata injected by Cloudflare into the request context:

| Field | Observed Value | Meaning |
|---|---|---|
| `colo` | `ARN` | Cloudflare data center code |
| `country` | `SE` | Request country |
| `city` | `Stockholm` | Request city |
| `asn` | `202053` | Autonomous system number |
| `httpProtocol` | `HTTP/1.1` | Client HTTP protocol |
| `tlsVersion` | `TLSv1.3` | TLS version used by the client connection |

### Global Distribution

Cloudflare Workers are deployed to Cloudflare’s global edge network. The developer does not manually choose a VM region or deploy the same application to multiple regions. Instead, Cloudflare routes user requests to nearby edge locations and executes the Worker close to the user.

Compared with VM or Kubernetes deployments, there is no separate “deploy to 3 regions” step. In Kubernetes or VM-based platforms, the operator usually chooses regions, manages regional capacity, configures load balancing, and plans failover. With Workers, the deployment target is the Cloudflare edge platform, and Cloudflare handles global placement and routing.

### Routing Concepts

| Routing option | Description |
|---|---|
| `workers.dev` | A quick public URL provided by Cloudflare for a Worker. This lab uses `workers.dev`. |
| Routes | Attach a Worker to URL patterns on an existing Cloudflare-managed zone. |
| Custom Domains | Attach a Worker directly to a custom domain or subdomain. |

This lab uses:

```text
https://devops-lab17-edge-api.dan4ikv74.workers.dev
```

---

## Task 4 — Configuration, Secrets, and Persistence

### Plaintext Environment Variables

Plaintext variables are configured in `wrangler.jsonc`:

```jsonc
"vars": {
  "APP_NAME": "devops-lab17-edge-api",
  "COURSE_NAME": "devops-core-course",
  "APP_VERSION": "v1.0.0",
  "ENVIRONMENT": "lab17"
}
```

These values are suitable for non-sensitive configuration such as app name, course name, version, and environment. They are not suitable for secrets because they are committed to source control.

### Secrets

Two Wrangler secrets were created:

```powershell
npx wrangler secret put API_TOKEN
npx wrangler secret put ADMIN_EMAIL
```

Observed result:

```text
Success! Uploaded secret API_TOKEN
Success! Uploaded secret ADMIN_EMAIL
```

Secret values were not committed to the repository.

### Secret-Protected Admin Endpoint

Command:

```powershell
Invoke-RestMethod `
  -Uri "$env:WORKER_URL/admin" `
  -Headers @{ Authorization = "Bearer lab17-secret-token" }
```

Observed response:

```text
status     adminEmailConfigured adminEmailMasked
------     -------------------- ----------------
authorized                 True d***@gmail.com
```

### Configuration Endpoint

Command:

```powershell
Invoke-RestMethod "$env:WORKER_URL/config"
```

Observed response:

```text
vars                                                                                                     secrets
----                                                                                                     -------
@{APP_NAME=devops-lab17-edge-api; COURSE_NAME=devops-core-course; APP_VERSION=v1.0.0; ENVIRONMENT=lab17} @{apiTokenConfigured=True; adminEmailConfigured=...}
```

### Workers KV Namespace

KV namespace creation command:

```powershell
npx wrangler kv namespace create SETTINGS
```

Observed output:

```text
Creating namespace with title "SETTINGS"
Success!
```

KV namespace binding:

```json
{
  "binding": "SETTINGS",
  "id": "6dbf1d05620a4e4399ef78b278df34bd"
}
```

### KV Persistence Verification

The `/counter` endpoint stores and increments a `visits` value in Workers KV.

Before redeploy:

```powershell
Invoke-RestMethod "$env:WORKER_URL/counter"
```

Observed values:

```text
key    previous visits persistedIn
---    -------- ------ -----------
visits        1      2 Workers KV

key    previous visits persistedIn
---    -------- ------ -----------
visits        2      3 Workers KV
```

Redeploy command:

```powershell
npx wrangler deploy
```

After redeploy:

```powershell
Invoke-RestMethod "$env:WORKER_URL/counter"
```

Observed response:

```text
key    previous visits persistedIn
---    -------- ------ -----------
visits        3      4 Workers KV
```

Later verification:

```text
key    previous visits persistedIn
---    -------- ------ -----------
visits        5      6 Workers KV
```

This confirms that the value persisted in Workers KV after redeploy.

Screenshot evidence: [Counter KV response](edge-api/screenshots/05-counter-kv-response.png)

---

## Task 5 — Observability and Operations

### Logs

The Worker includes a `console.log()` statement that emits request metadata.

Wrangler tail command:

```powershell
npx wrangler tail
```

Observed log entries:

```text
Successfully created tail, expires at 2026-05-14T20:03:10Z
Connected to devops-lab17-edge-api, waiting for logs...

GET https://devops-lab17-edge-api.dan4ikv74.workers.dev/health - Ok @ 14.05.2026, 17:03:36
  (log) lab17-request {
  requestId: '4f83db01-b7d3-4e9d-8de7-4a9fc7cf7d21',
  method: 'GET',
  path: '/health',
  colo: 'ARN',
  country: 'SE'
}

GET https://devops-lab17-edge-api.dan4ikv74.workers.dev/edge - Ok @ 14.05.2026, 17:03:37
  (log) lab17-request {
  requestId: 'f1380904-e122-45a1-b7d9-89cb920d5ed0',
  method: 'GET',
  path: '/edge',
  colo: 'ARN',
  country: 'SE'
}

GET https://devops-lab17-edge-api.dan4ikv74.workers.dev/counter - Ok @ 14.05.2026, 17:03:38
  (log) lab17-request {
  requestId: '456b4bbb-2aeb-4ecc-95ce-67630754b7b4',
  method: 'GET',
  path: '/counter',
  colo: 'ARN',
  country: 'SE'
}
```

Screenshot evidence: [Worker logs](edge-api/screenshots/06-worker-logs.png)

### Metrics

Cloudflare Worker metrics were reviewed in the Cloudflare dashboard.

Observed values:

| Metric | Value |
|---|---:|
| Requests | `18` |
| Subrequests | `0` |
| Errors | `0` |
| CPU Time | `0.63 ms` |
| Wall Time | `0.94 ms` |
| Request Duration | `0.93 ms` |

Screenshot evidence: [Worker metrics](edge-api/screenshots/07-worker-metrics.png)

### Deployment History

Deployment history was reviewed using both Wrangler and the Cloudflare dashboard.

Command:

```powershell
npx wrangler deployments list
```

Observed deployments included:

```text
Created: 2026-05-14T13:55:04.825Z
Author:  dan4ikv74@gmail.com
Source:  Upload
Version: b463d49b-6fcc-4c45-8313-0993f133457b

Created: 2026-05-14T13:56:05.126Z
Author:  dan4ikv74@gmail.com
Source:  Secret Change
Version: cb7af8e7-9536-466e-8d2f-9880af7703cb

Created: 2026-05-14T13:57:00.043Z
Author:  dan4ikv74@gmail.com
Source:  Secret Change
Version: eec006cb-5536-4103-acf9-8c9a297ee5d0

Created: 2026-05-14T13:57:27.917Z
Author:  dan4ikv74@gmail.com
Source:  Unknown (deployment)
Version: fc83d47a-55f6-422c-984b-9de66c43d23a

Created: 2026-05-14T14:00:52.645Z
Author:  dan4ikv74@gmail.com
Source:  Unknown (deployment)
Version: 724815f9-624e-4545-bcb4-f8f8fda252e2
```

Cloudflare dashboard showed an active deployment with:

| Field | Value |
|---|---|
| Active version | `01f665d8` |
| Traffic | `100%` |
| Error rate | `0%` |
| Median CPU time | `0.93 ms` |

Screenshot evidence: [Deployments history](edge-api/screenshots/08-deployments-history.png)

### Rollback

Rollback can be performed with Wrangler:

```powershell
npx wrangler rollback
```

The deployment history shows multiple previous versions available for rollback.

---

## Task 6 — Kubernetes vs Cloudflare Workers Comparison

| Aspect | Kubernetes | Cloudflare Workers |
|---|---|---|
| Setup complexity | Requires cluster, nodes, networking, ingress, service discovery, resource limits, and operational setup. | Requires a Cloudflare account, Wrangler project, and configuration file. |
| Deployment speed | Slower, especially when building images, pushing to a registry, and waiting for rollout. | Fast upload and deploy through Wrangler. |
| Global distribution | Requires manual multi-region planning, regional clusters, global load balancing, and failover design. | Built into the Cloudflare edge network. No manual region selection is required. |
| Cost for small apps | Can be expensive because clusters and nodes need to run continuously. | Usually cheaper for small APIs because execution is serverless and request-based. |
| State/persistence model | Supports many storage models: PVCs, databases, object storage, operators, and stateful workloads. | Uses platform bindings such as KV, Durable Objects, R2, D1, and external services. |
| Control/flexibility | Very high. Can run almost any containerized workload and long-running processes. | More constrained. Code must fit the Workers runtime and execution model. |
| Best use case | Complex distributed systems, long-running services, internal platforms, workloads needing full container control. | Lightweight APIs, global edge routing, request middleware, low-latency public endpoints, small serverless services. |

### When to Use Kubernetes

Kubernetes is the better choice when the workload needs containers, background workers, custom networking, service meshes, persistent volumes, internal services, or detailed control over runtime and infrastructure. It is also more appropriate for applications that need long-running processes or complex multi-service architectures.

### When to Use Cloudflare Workers

Cloudflare Workers are the better choice for lightweight HTTP APIs, edge routing, global request handling, low-latency middleware, redirects, webhooks, and small services that benefit from Cloudflare’s global network. Workers are also useful when fast deployments and low operational overhead are more important than full infrastructure control.

### Recommendation

For this lab’s API, Cloudflare Workers is a good fit because the service is stateless except for a small KV-backed counter, exposes simple HTTP routes, and benefits from a global public URL without managing servers or Kubernetes resources.

For larger applications with multiple services, internal networking, custom runtime requirements, or long-running workloads, Kubernetes would be more appropriate.

---

## Reflection

Cloudflare Workers felt easier than Kubernetes because there was no need to create deployments, services, ingress resources, pods, or container images. Deployment was performed with a single Wrangler command, and the service immediately received a public `workers.dev` URL.

The constrained part is that Workers is not a Docker host. The application must be written for the Workers runtime, and persistence must use platform services such as KV instead of local files or Kubernetes persistent volumes.

The main architectural change is that the app is deployed as edge-executed serverless code rather than a container running inside a cluster. Operational concerns still exist, but they are handled differently: configuration is provided through Wrangler vars and secrets, persistence through KV, logs through Wrangler tail or the Cloudflare dashboard, and deployment history through Workers versions.

---

## Evidence Index

| Evidence | File |
|---|---|
| Cloudflare Worker dashboard | [01-cloudflare-worker-dashboard.png](edge-api/screenshots/01-cloudflare-worker-dashboard.png) |
| Wrangler authentication | [02-wrangler-whoami.png](edge-api/screenshots/02-wrangler-whoami.png) |
| Worker root response | [03-worker-root-response.png](edge-api/screenshots/03-worker-root-response.png) |
| Edge metadata response | [04-edge-response.png](edge-api/screenshots/04-edge-response.png) |
| KV counter response | [05-counter-kv-response.png](edge-api/screenshots/05-counter-kv-response.png) |
| Worker logs | [06-worker-logs.png](edge-api/screenshots/06-worker-logs.png) |
| Worker metrics | [07-worker-metrics.png](edge-api/screenshots/07-worker-metrics.png) |
| Deployment history | [08-deployments-history.png](edge-api/screenshots/08-deployments-history.png) |
