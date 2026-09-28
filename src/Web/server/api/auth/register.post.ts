// server/api/auth/register.post.ts
import { z } from "zod";
import {
  RegisterResponse,
  RegisterResponseData,
  RegisterUserRequest,
} from "~~/shared/auth/auth.dto";

const bodySchema = z
  .object({
    email: z.string().email(),
    password: z
      .string()
      .min(8)
      .regex(/[A-Z]/, "Password must contain at least one uppercase letter")
      .regex(/[a-z]/, "Password must contain at least one lowercase letter")
      .regex(/[0-9]/, "Password must contain at least one digit")
      .regex(
        /[^A-Za-z0-9]/,
        "Password must contain at least one special character",
      ),
    confirmPassword: z.string(),
    firstName: z.string().max(100),
    lastName: z.string().max(100),
  })
  .refine((data) => data.password === data.confirmPassword, {
    message: "Passwords do not match.",
    path: ["confirmPassword"],
  });

export default defineEventHandler(async (event) => {
  const body = await readValidatedBody<RegisterUserRequest>(
    event,
    bodySchema.parse,
  );
  const config = useRuntimeConfig();

  try {
    return await $fetch<RegisterResponseData>(
      `${config.apiBaseUrl}/api/auth/register`,
      { method: "POST", body },
    );
  } catch (err: any) {
    const detail =
      err.data?.detail ?? err.data?.title ?? "Registration failed.";
    throw createError({
      statusCode: err.response?.status ?? err.statusCode ?? 400,
      message: detail,
      data: { message: detail },
    });
  }
});
