export default defineEventHandler(async (event) => {
  const { secure } = await getUserSession(event)
  const { apiBaseUrl } = useRuntimeConfig(event)

  // Revoke server-side first: deleting the cookie alone leaves the refresh token valid for 7 days.
  if (secure?.refreshToken) {
    try {
      await $fetch(`${apiBaseUrl}/api/auth/logout`, {
        method: 'POST',
        body: { refreshToken: secure.refreshToken },
      })
    } catch (err) {
      // Never block a logout: the user still leaves, but the token stays live until it expires. Log it.
      console.error('Logout: could not revoke the refresh token', err)
    }
  }

  await clearUserSession(event)
  return { ok: true }
})