import { z } from "zod";
import { LoginResponse, LoginRequest, UserDto } from "#shared/auth/auth.dto";

const bodySchema = z.object({
  email: z.string().email(),
  password: z.string().min(1, "Password is required"),
});

export default defineEventHandler(async (event) => {
  const body = await readValidatedBody<LoginRequest>(event, bodySchema.parse);

  const config = useRuntimeConfig();

  try {
    const response = await $fetch<LoginResponse>(
      `${config.apiBaseUrl}/api/auth/login`,
      {
        method: "POST",
        body: body,
      },
    );

    const userProfile = await $fetch<UserDto>(
      `${config.apiBaseUrl}/api/auth/me`,
      {
        headers: { Authorization: `Bearer ${response.accessToken}` },
      },
    );
    await setUserSession(
      event,
      {
        user: {
          id: userProfile.id,
          email: userProfile.email,
          firstName: userProfile.firstName,
          lastName: userProfile.lastName,
          roles: userProfile.roles,
          mustChangePassword: userProfile.mustChangePassword,
        },
        secure: {
          jwt: response.accessToken,
          refreshToken: response.refreshToken,
          expiresAt: Date.now() + response.expiresIn * 1000,
        },
        loggedInAt: Date.now(),
      },
      {
        maxAge: SESSION_MAX_AGE, // Cookie expires when JWT expires
      },
    );
    return { user: userProfile };
  } catch (error: any) {
    const problem = error?.data;
    const detail = problem?.detail ?? problem?.title ?? "Login failed.";
    throw createError({
      statusCode: error.response?.status ?? error.statusCode ?? 400,
      message: detail,
      data: { message: detail, code: problem?.code },
    });
  }
});
