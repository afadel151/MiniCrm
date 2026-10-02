import { LoginResponse } from "~~/shared/auth/auth.dto";
import { isError, type H3Event } from "h3";
import { fail } from "./http";
const inflight = new Map<string, Promise<LoginResponse>>();
const SHARE_WINDOW_MS = 10_000; // must not exceed the API's rotation grace window
export const SESSION_MAX_AGE = 60 * 60 * 24 * 7;

export async function refreshSession(event: H3Event): Promise<string> {
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

export function refreshTokens(refreshToken: string): Promise<LoginResponse> {
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