// server/api/invitations/register.post.ts
import { z } from 'zod'

// Same policy as register.post.ts. Consider extracting it to a shared util.
const passwordSchema = z
  .string()
  .min(8)
  .max(128)
  .regex(/[A-Z]/, 'Password must contain at least one uppercase letter')
  .regex(/[a-z]/, 'Password must contain at least one lowercase letter')
  .regex(/[0-9]/, 'Password must contain at least one digit')
  .regex(/[^A-Za-z0-9]/, 'Password must contain at least one special character')

// No email field: the address comes from the invitation and cannot be chosen here.
const bodySchema = z
  .object({
    token: z.string().trim().min(20).max(100),
    firstName: z.string().trim().min(1).max(100),
    lastName: z.string().trim().min(1).max(100),
    password: passwordSchema,
    confirmPassword: z.string(),
  })
  .refine((d) => d.password === d.confirmPassword, {
    message: 'Passwords do not match.',
    path: ['confirmPassword'],
  })

export default defineEventHandler(async (event) => {
  const body = await readValidatedBody(event, bodySchema.parse)
  const { apiBaseUrl } = useRuntimeConfig(event)
  setHeader(event, 'Cache-Control', 'no-store')

  try {
    // Returns { businessId, businessName, role, alreadyMember }. No session is created here:
    // the page should call the existing /api/auth/login with the same credentials afterwards.
    return await $fetch(`${apiBaseUrl}/api/invitations/register`, { method: 'POST', body })
  } catch (err: any) {
    const status: number = err?.response?.status ?? err?.statusCode ?? 502
    let message = 'Registration failed.'
    if (status < 500) {
      message = err?.data?.detail ?? err?.data?.title ?? message
    } else {
      console.error('[invitation-register] backend error', status, err?.data)
      message = 'Service indisponible, réessayez dans un instant.'
    }
    throw createError({ statusCode: status, message, data: { message } })
  }
})