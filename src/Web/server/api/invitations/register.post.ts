// server/api/invitations/register.post.ts  (replaces the earlier version)
import { registerStaffSchema } from '#shared/invitations/schemas'
import type { LoginResponse, UserDto } from '#shared/auth/auth.dto'

interface RegisterStaffResult {
  businessId: number
  businessName: string
  role: string
  email: string
}

export default defineEventHandler(async (event) => {
  const body = await readValidatedBody(event, registerStaffSchema.parse)
  const { apiBaseUrl } = useRuntimeConfig(event)
  setHeader(event, 'Cache-Control', 'no-store')

  // 1. Create the account and the membership. Anything that fails here is the caller's to see.
  let joined: RegisterStaffResult
  try {
    joined = await $fetch<RegisterStaffResult>(`${apiBaseUrl}/api/invitations/register`, {
      method: 'POST',
      body, // includes token + confirmPassword, which the API validates again
    })
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

  // 2. Sign in the same way login.post.ts does. The email never leaves the server.
  try {
    const auth = await $fetch<LoginResponse>(`${apiBaseUrl}/api/auth/login`, {
      method: 'POST',
      body: { email: joined.email, password: body.password },
    })
    const profile = await $fetch<UserDto>(`${apiBaseUrl}/api/auth/me`, {
      headers: { Authorization: `Bearer ${auth.accessToken}` },
    })

    await setUserSession(
      event,
      {
        user: {
          id: profile.id,
          email: profile.email,
          firstName: profile.firstName,
          lastName: profile.lastName,
          role: profile.role,
          mustChangePassword: profile.mustChangePassword,
        },
        secure: {
          jwt: auth.accessToken,
          refreshToken: auth.refreshToken,
          expiresAt: Date.now() + auth.expiresIn * 1000,
        },
        loggedInAt: Date.now(),
      },
      { maxAge: SESSION_MAX_AGE }, // auto-imported from your server utils, as in login.post.ts
    )

    return { signedIn: true, businessId: joined.businessId, businessName: joined.businessName, role: joined.role }
  } catch (err) {
    // The account and membership exist. Do not report a failure: send the person to the sign-in form.
    console.error('[invitation-register] account created but sign-in failed', err)
    return { signedIn: false, businessId: joined.businessId, businessName: joined.businessName, role: joined.role }
  }
})