export interface LoginResponse {
  accessToken: string;
  refreshToken: string;
  expiresIn: number;
  tokenType: string;
}

export interface LoginRequest {
  email: string;
  password: string;
}

export interface UserDto {
  id: string;
  email: string;
  firstName: string;
  lastName: string;
  role: string;
  mustChangePassword: boolean;
}

export interface RegisterUserRequest {
  email: string;
  password: string;
  confirmPassword: string;
  firstName: string;
  lastName: string;
}
export interface RegisterBusinessRequest {
  email: string;
  password: string;
  confirmPassword: string;
  firstName: string;
  lastName: string;
  businessName : string;
  phoneNumber?: string;
  // teamSize: number;
}
export interface RegisterResponse {
  data: RegisterResponseData;
  error_code?: number;
}

export interface RegisterResponseData {
  email: string;
}

 
export interface ConfirmEmailRequest {
  userId: string
  code: string // base64url-encoded Identity confirmation token
}
 
export interface ResendConfirmationRequest {
  email: string
}
 
