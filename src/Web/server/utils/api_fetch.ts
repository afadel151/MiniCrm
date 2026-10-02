import { isError, type H3Event } from "h3";
import type { LoginResponse } from "#shared/auth/auth.dto";
import { fail, toH3Error } from "./http";
import { refreshSession, refreshTokens } from "./auth_session";

// Keep equal to the API's refresh-token lifetime (TokenService: RefreshTokenDays = 7).

const REFRESH_BUFFER_MS = 30_000; // refresh this long before the access token expires

interface ApiOptions {
  method?: "GET" | "POST" | "PUT" | "PATCH" | "DELETE";
  query?: Record<string, any>;
  body?: any;
  headers?: Record<string, string>;
}

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
