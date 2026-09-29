import { z } from "zod";
import { LoginResponse, UserDto } from "#shared/auth/auth.dto";

const bodySchema = z.object({
  idToken: z.string().min(1, "Google ID token is required"),
  role: z.enum(["Client", "BusinessManager"]).optional(),
  businessName: z.string().optional(),
});

export default defineEventHandler(async (event) => {
  const body = await readValidatedBody(event, bodySchema.parse);
  const config = useRuntimeConfig();

  try {
    const response = await $fetch<LoginResponse>(
      `${config.apiBaseUrl}/api/auth/login/google`,
      { method: "POST", body: body },
    );
    console.log(response);
    

    const userProfile = await $fetch<UserDto>(
      `${config.apiBaseUrl}/api/auth/me`,
      { headers: { Authorization: `Bearer ${response.accessToken}` } },
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
      { maxAge: SESSION_MAX_AGE },
    );

    return { user: userProfile };
  } catch (error: any) {
    console.log(error);
    
    const problem = error?.data;
    const detail =
      problem?.detail ?? problem?.title ?? "Google sign-in failed.";
    throw createError({
      statusCode: error.response?.status ?? error.statusCode ?? 400,
      message: error,
      data: { message: detail, code: problem?.code },
    });
  }
});
