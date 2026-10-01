// shared/invitations/schemas.ts
import { z } from 'zod'

export const passwordSchema = z
  .string()
  .min(8, 'Use at least 8 characters.')
  .max(128, 'Use at most 128 characters.')
  .regex(/[A-Z]/, 'Password must contain at least one uppercase letter')
  .regex(/[a-z]/, 'Password must contain at least one lowercase letter')
  .regex(/[0-9]/, 'Password must contain at least one digit')
  .regex(/[^A-Za-z0-9]/, 'Password must contain at least one special character')

export const inviteTokenSchema = z.string().trim().regex(/^[A-Za-z0-9_-]{20,100}$/)

export const registerStaffSchema = z
  .object({
    token: inviteTokenSchema,
    firstName: z.string().trim().min(1, 'Enter your first name.').max(100),
    lastName: z.string().trim().min(1, 'Enter your last name.').max(100),
    password: passwordSchema,
    confirmPassword: z.string(),
  })
  .refine((d) => d.password === d.confirmPassword, {
    message: 'Passwords do not match.',
    path: ['confirmPassword'],
  })