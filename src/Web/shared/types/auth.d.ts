declare module '#auth-utils' {
  interface User {
    id: string,
    email: string
    firstName: string
    lastName: string
    roles: string[]
    mustChangePassword: boolean
  }

  interface SecureSessionData {
    jwt: string
    refreshToken: string
    expiresAt: number
  }

  interface UserSession {
    loggedInAt?: number
  }
}

export {}