declare module '#auth-utils' {
  interface User {
    id: string,
    email: string
    firstName: string
    lastName: string
    role: string
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
  
  interface CurrentBusiness {
    businessId: int,
    businessName: string,
    membershipRole: string,
    isPrimaryOwner: bool
  }
}

export {}