// server/api/invitations/preview.post.ts
import { z } from "zod";

// POST with the token in the body: it never appears in a URL, an access log or a Referer header.
const bodySchema = z.object({ token: z.string().trim().min(20).max(100) })

export default defineEventHandler(async (event) => {
  const { token } = await readValidatedBody(event, bodySchema.parse);
  const { apiBaseUrl } = useRuntimeConfig(event)
  setHeader(event, 'Cache-Control', 'no-store');

  try {
    return await $fetch(`${apiBaseUrl}/api/invitations/preview`, {
      method: 'POST',
      body: { token },
    })
  } catch (err: any) {
    const status: number = err?.response?.status ?? err?.statusCode ?? 502
    const message =
      status < 500
        ? (err?.data?.detail ?? err?.data?.title ?? 'This invitation is unavailable.')
        : 'Service indisponible, réessayez dans un instant.'
    throw createError({ statusCode: status, message, data: { message } })
  }
});