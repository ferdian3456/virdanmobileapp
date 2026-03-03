export interface SignupStartResponse {
  sessionId: string;
  otpExpiresAt: number; // Unix timestamp in seconds
}

export interface LoginResponse {
    accessToken: string;
	accessTokenExpiresIn: number;
	refreshToken: string;
	refreshTokenExpiresIn: number;
	tokenType: string;
}

