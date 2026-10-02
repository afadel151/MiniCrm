import { refreshSession } from "~~/server/utils/auth_session"
export default defineEventHandler(async (event) => {
    console.log("inside server session handler");

    try {
        const { secure } = await getUserSession(event)
        console.log("secure :" + secure);

        if (!secure?.refreshToken) {
            return {
                authenticated: false,
            }
        }

        const expiresAt = secure.expiresAt ?? 0

        if (expiresAt <= Date.now()) {
            await refreshSession(event)
        }

        return {
            authenticated: true,
        }
    } catch {
        await clearUserSession(event)

        return {
            authenticated: false,
        }
    }
})