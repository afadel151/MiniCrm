// server/api/auth/register.post.ts
import { z } from 'zod'
import type { RegisterResponseData } from '~~/shared/auth/auth.dto'

const passwordSchema = z
  .string()
  .min(8)
  .max(128)
  .regex(/[A-Z]/, 'Password must contain at least one uppercase letter')
  .regex(/[a-z]/, 'Password must contain at least one lowercase letter')
  .regex(/[0-9]/, 'Password must contain at least one digit')
  .regex(/[^A-Za-z0-9]/, 'Password must contain at least one special character')

const baseFields = {
  firstName: z.string().trim().min(1).max(100),
  lastName: z.string().trim().min(1).max(100),
  email: z.string().trim().toLowerCase().email().max(254),
  password: passwordSchema,
  confirmPassword: z.string(),
}

const clientSchema = z.object({
  ...baseFields,
  accountType: z.literal('client'),
})

const businessSchema = z.object({
  ...baseFields,
  accountType: z.literal('business'),
  businessName: z.string().trim().min(1).max(150),
  phoneNumber: z.string().trim().max(30),
  // teamSize: z.coerce.number().int().min(1).max(100_000),
})

const bodySchema = z
  .discriminatedUnion('accountType', [clientSchema, businessSchema])
  .refine((d) => d.password === d.confirmPassword, {
    message: 'Passwords do not match.',
    path: ['confirmPassword'],
  })

const BACKEND_ROUTE = {
  client: '/api/auth/register/client',
  business: '/api/auth/register/business',
} as const

export default defineEventHandler(async (event) => {
  const { accountType, ...payload } = await readValidatedBody(event, bodySchema.parse)
  const config = useRuntimeConfig()

  try {
    return await $fetch<RegisterResponseData>(
      `${config.apiBaseUrl}${BACKEND_ROUTE[accountType]}`,
      { method: 'POST', body: payload },
    )
  } catch (err: any) {
    const status: number = err.response?.status ?? err.statusCode ?? 502
    let message = 'Registration failed.'
    if (status < 500) {
      message = err.data?.detail ?? err.data?.title ?? message
    } else {
      console.error('[register] backend error', status, err.data)
    }

    throw createError({
      statusCode: status,
      message,
      data: { message },
    })
  }
})