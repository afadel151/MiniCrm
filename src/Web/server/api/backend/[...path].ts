// /api/backend/<anything>  ->  <apiBaseUrl>/api/<anything>, with the user's Bearer token attached.
const ALLOWED_METHODS = ["GET", "POST", "PUT", "PATCH", "DELETE"] as const;
type Method = (typeof ALLOWED_METHODS)[number];
const BLOCKED_PATH = /^auth(\/|$)/i;
const SAFE_PATH = /^[A-Za-z0-9._~-]+(\/[A-Za-z0-9._~-]+)*$/;
const FORWARD_HEADERS = ["content-type", "accept", "accept-language"];
const MAX_BODY_BYTES = 1_000_000;

function isSameOrigin(event: Parameters<typeof getHeader>[0]) {
  const origin = getHeader(event, "origin");
  if (!origin) return true;
  try {
    return (
      new URL(origin).host === getRequestHost(event, { xForwardedHost: true })
    );
  } catch {
    return false;
  }
}

export default defineEventHandler(async (event) => {
  const method = event.method as Method;
  if (!ALLOWED_METHODS.includes(method))
    throw createError({ statusCode: 405, message: "Méthode non autorisée." });

  const path = getRouterParam(event, "path") ?? "";
  const safe =
    SAFE_PATH.test(path) &&
    !path.split("/").some((segment) => segment === "." || segment === "..");
  if (!safe || BLOCKED_PATH.test(path))
    throw createError({ statusCode: 404, message: "Introuvable." });

  if (method !== "GET" && !isSameOrigin(event)) {
    throw createError({ statusCode: 403, message: "Origine non autorisée." });
  }

  const hasBody = method === "POST" || method === "PUT" || method === "PATCH";
  if (
    hasBody &&
    Number(getHeader(event, "content-length") ?? 0) > MAX_BODY_BYTES
  ) {
    throw createError({
      statusCode: 413,
      message: "Corps de requête trop volumineux.",
    });
  }
  const body = hasBody ? await readRawBody(event, false) : undefined;

  const headers: Record<string, string> = {};
  for (const name of FORWARD_HEADERS) {
    const value = getHeader(event, name);
    if (value) headers[name] = value;
  }

  const res = await apiFetchRaw(event, `/api/${path}`, {
    method,
    query: getQuery(event),
    body,
    headers,
  });
  setHeader(event, "Cache-Control", "no-store");
  if (res.status === 204) return sendNoContent(event);
  setResponseStatus(event, res.status);
  return res._data;
});
