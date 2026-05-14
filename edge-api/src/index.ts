export interface Env {
  APP_NAME: string;
  COURSE_NAME: string;
  APP_VERSION: string;
  ENVIRONMENT: string;
  API_TOKEN: string;
  ADMIN_EMAIL: string;
  SETTINGS: KVNamespace;
}

type JsonValue = string | number | boolean | null | JsonValue[] | { [key: string]: JsonValue };

type JsonBody = Record<string, JsonValue>;

function json(body: JsonBody, init: ResponseInit = {}): Response {
  const headers = new Headers(init.headers);
  headers.set("content-type", "application/json; charset=utf-8");
  return new Response(JSON.stringify(body, null, 2), {
    ...init,
    headers,
  });
}

function notFound(pathname: string): Response {
  return json(
    {
      error: "not_found",
      message: `Route ${pathname} does not exist`,
      availableRoutes: ["/", "/health", "/metadata", "/edge", "/counter", "/config", "/admin"],
    },
    { status: 404 },
  );
}

function getSecretStatus(env: Env): JsonBody {
  return {
    apiTokenConfigured: Boolean(env.API_TOKEN),
    adminEmailConfigured: Boolean(env.ADMIN_EMAIL),
    adminEmailMasked: env.ADMIN_EMAIL ? env.ADMIN_EMAIL.replace(/(^.).*(@.*$)/, "$1***$2") : null,
  };
}

async function handleCounter(env: Env): Promise<Response> {
  const key = "visits";
  const raw = await env.SETTINGS.get(key);
  const previous = Number.parseInt(raw ?? "0", 10) || 0;
  const current = previous + 1;
  await env.SETTINGS.put(key, String(current));

  return json({
    key,
    previous,
    visits: current,
    persistedIn: "Workers KV",
  });
}

function handleEdge(request: Request): Response {
  const cf = request.cf;

  return json({
    colo: typeof cf?.colo === "string" ? cf.colo : null,
    country: typeof cf?.country === "string" ? cf.country : null,
    city: typeof cf?.city === "string" ? cf.city : null,
    asn: typeof cf?.asn === "number" ? cf.asn : null,
    httpProtocol: typeof cf?.httpProtocol === "string" ? cf.httpProtocol : null,
    tlsVersion: typeof cf?.tlsVersion === "string" ? cf.tlsVersion : null,
    note: "These values are populated by Cloudflare on deployed workers.dev requests. Some fields may be null during local development.",
  });
}

function handleAdmin(request: Request, env: Env): Response {
  const authHeader = request.headers.get("authorization") ?? "";
  const expected = `Bearer ${env.API_TOKEN}`;

  if (!env.API_TOKEN || authHeader !== expected) {
    return json(
      {
        error: "unauthorized",
        message: "Pass Authorization: Bearer <API_TOKEN> to access this route.",
      },
      { status: 401 },
    );
  }

  return json({
    status: "authorized",
    adminEmailConfigured: Boolean(env.ADMIN_EMAIL),
    adminEmailMasked: env.ADMIN_EMAIL.replace(/(^.).*(@.*$)/, "$1***$2"),
  });
}

export default {
  async fetch(request: Request, env: Env): Promise<Response> {
    const url = new URL(request.url);
    const requestId = crypto.randomUUID();

    console.log("lab17-request", {
      requestId,
      method: request.method,
      path: url.pathname,
      colo: request.cf?.colo ?? "local",
      country: request.cf?.country ?? "local",
    });

    if (request.method !== "GET" && request.method !== "HEAD") {
      return json(
        {
          error: "method_not_allowed",
          message: "This lab API accepts GET requests for the required endpoints.",
        },
        { status: 405, headers: { allow: "GET, HEAD" } },
      );
    }

    if (url.pathname === "/health") {
      return json({
        status: "ok",
        app: env.APP_NAME,
        version: env.APP_VERSION,
        timestamp: new Date().toISOString(),
      });
    }

    if (url.pathname === "/") {
      return json({
        app: env.APP_NAME,
        course: env.COURSE_NAME,
        version: env.APP_VERSION,
        environment: env.ENVIRONMENT,
        message: "Hello from Cloudflare Workers edge runtime",
        routes: ["/health", "/metadata", "/edge", "/counter", "/config", "/admin"],
        timestamp: new Date().toISOString(),
      });
    }

    if (url.pathname === "/metadata") {
      return json({
        app: env.APP_NAME,
        course: env.COURSE_NAME,
        version: env.APP_VERSION,
        runtime: "Cloudflare Workers",
        deploymentModel: "serverless edge worker",
        persistence: "Workers KV binding SETTINGS",
        publicRouting: "workers.dev enabled",
        requestId,
      });
    }

    if (url.pathname === "/edge") {
      return handleEdge(request);
    }

    if (url.pathname === "/counter") {
      return handleCounter(env);
    }

    if (url.pathname === "/config") {
      return json({
        vars: {
          APP_NAME: env.APP_NAME,
          COURSE_NAME: env.COURSE_NAME,
          APP_VERSION: env.APP_VERSION,
          ENVIRONMENT: env.ENVIRONMENT,
        },
        secrets: getSecretStatus(env),
        warning: "Plaintext vars are committed in wrangler.jsonc and must not contain secrets. Secret values are created with Wrangler and are not committed.",
      });
    }

    if (url.pathname === "/admin") {
      return handleAdmin(request, env);
    }

    return notFound(url.pathname);
  },
};
