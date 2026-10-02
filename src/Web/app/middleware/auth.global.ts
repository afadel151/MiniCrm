// middleware/auth.ts

import { refreshSession } from "~~/server/utils/auth_session";

export default defineNuxtRouteMiddleware(async (to) => {
  const { loggedIn, fetch: fetchSession } = useUserSession();
  if (to.meta.public) {
    return;
  }
  if (loggedIn.value) {
    return;
  }
  console.log("not public not logged");

  try {
    console.log("fetching session");
    
    const session = await $fetch<{ authenticated: boolean }>(
      "/api/auth/session",
    );
    console.log("fetched session:" + session.authenticated);

    if (session.authenticated) {
      await fetchSession();
      return;
    }
  } catch {}

  return navigateTo({
    path: "/auth/login",
    query: {
      redirect: to.fullPath,
    },
  });
});
