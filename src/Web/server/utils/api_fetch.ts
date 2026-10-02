import { isError, type H3Event } from "h3";
import type { LoginResponse } from "#shared/auth/auth.dto";

// Keep equal to the API's refresh-token lifetime (TokenService: RefreshTokenDays = 7).
export const SESSION_MAX_AGE = 60 * 60 * 24 * 7;

const REFRESH_BUFFER_MS = 30_000; // refresh this long before the access token expires
const SHARE_WINDOW_MS = 10_000; // must not exceed the API's rotation grace window

interface ApiOptions {
  method?: "GET" | "POST" | "PUT" | "PATCH" | "DELETE";
  query?: Record<string, any>;
  body?: any;
  headers?: Record<string, string>;
}

// One refresh call per refresh token, shared by parallel requests in this Node process.
const inflight = new Map<string, Promise<LoginResponse>>();

function refreshTokens(refreshToken: string): Promise<LoginResponse> {
  const existing = inflight.get(refreshToken);
  if (existing) return existing;

  const { apiBaseUrl } = useRuntimeConfig();
  const request = $fetch<LoginResponse>(`${apiBaseUrl}/api/auth/refresh`, {
    method: "POST",
    body: { refreshToken },
  });
  inflight.set(refreshToken, request);

  const timer = setTimeout(
    () => inflight.delete(refreshToken),
    SHARE_WINDOW_MS,
  );
  request.catch(() => {
    clearTimeout(timer);
    inflight.delete(refreshToken);
  });
  return request;
}

function fail(statusCode: number, message: string, errors?: unknown) {
  return createError({ statusCode, message, data: { message, errors } });
}

async function refreshSession(event: H3Event): Promise<string> {
  const { secure } = await getUserSession(event);

  let tokens: LoginResponse | undefined;

  if (secure?.refreshToken) {
    try {
      tokens = await refreshTokens(secure.refreshToken);
    } catch (err: any) {
      const status = err?.response?.status;

      // Only a definitive rejection ends the session;
      // a network error or 5xx keeps the user logged in.
      if (status !== 400 && status !== 401 && status !== 403) {
        throw fail(503, "Service indisponible, réessayez dans un instant.");
      }
    }
  }

  if (!tokens) {
    await clearUserSession(event);
    throw fail(401, "Session expirée. Veuillez vous reconnecter.");
  }

  await setUserSession(
    event,
    {
      secure: {
        jwt: tokens.accessToken,
        refreshToken: tokens.refreshToken,
        expiresAt: Date.now() + tokens.expiresIn * 1000,
      },
    },
    { maxAge: SESSION_MAX_AGE },
  );

  return tokens.accessToken;
}
function toH3Error(err: any) {
  if (isError(err)) {
    return err;
  }

  const status = err?.response?.status;

  if (!status) {
    return fail(503, "Impossible de joindre le serveur.");
  }

  const problem = err?.data ?? err?.response?._data;

  if (status >= 500) {
    return fail(status, "Une erreur interne est survenue.");
  }

  const message =
    problem?.detail ??
    problem?.message ??
    problem?.title ??
    "La requête a échoué.";

  return fail(status, message, problem?.errors);
}

/** Calls the ASP.NET API as the signed-in user. Returns the status and the parsed body. */
export async function apiFetchRaw<T = unknown>(
  event: H3Event,
  path: string,
  opts: ApiOptions = {},
) {
  const { apiBaseUrl } = useRuntimeConfig(event);
  const { secure } = await requireUserSession(event); // 401 when there is no session

  let jwt = secure?.jwt;
  if (!jwt || (secure?.expiresAt ?? 0) - REFRESH_BUFFER_MS <= Date.now()) {
    jwt = await refreshSession(event);
  }

  // Options are cast on purpose: Nitro's typed $fetch rejects a plain method/headers object.
  const send = (token: string) =>
    $fetch.raw(`${apiBaseUrl}${path}`, {
      ...opts,
      headers: { ...opts.headers, Authorization: `Bearer ${token}` },
    } as any) as Promise<{ status: number; _data: T }>;

  try {
    return await send(jwt);
  } catch (err: any) {
    if (err?.response?.status !== 401) throw toH3Error(err);
  }

  // Rejected despite looking fresh (clock skew, revoked, key rotated): refresh once, retry once.
  try {
    return await send(await refreshSession(event));
  } catch (err: any) {
    throw toH3Error(err);
  }
}

/** Same as apiFetchRaw, but returns only the parsed body. */
export async function apiFetch<T = unknown>(
  event: H3Event,
  path: string,
  opts: ApiOptions = {},
) {
  return (await apiFetchRaw<T>(event, path, opts))._data;
}
