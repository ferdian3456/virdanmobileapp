import { defineStore } from 'pinia';
import { ref, computed } from 'vue';
import axios from 'axios';
import { SecureStorage } from '@aparajita/capacitor-secure-storage';
import { api, baseURL } from 'src/boot/axios';

export interface UserData {
  id: string;
  username: string;
  email: string;
  fullname: string;
  bio: string | null;
  avatarImage: string | null;
  createDatetime?: string;
  updateDatetime?: string;
}

export interface TokenResponse {
  accessToken: string;
  accessTokenExpiresIn: number;
  refreshToken: string;
  refreshTokenExpiresIn: number;
  tokenType: string;
}

const KEY_ACCESS = 'access_token';
const KEY_REFRESH = 'refresh_token';
const KEY_SESSION = 'signup_session_id';
const KEY_OTP_EXP = 'otp_expires_at';

export const useAuthStore = defineStore('auth', () => {
  const token = ref<string | null>(null);
  const user = ref<UserData | null>(null);

  const isLoggedIn = computed(() => !!token.value);

  /* ─── Token storage ──────────────────────────────────────────── */

  async function getToken(): Promise<string | null> {
    if (!token.value) {
      const value = await SecureStorage.get(KEY_ACCESS);
      token.value = (value as string | null) ?? null;
    }
    return token.value;
  }

  async function getRefreshToken(): Promise<string | null> {
    const value = await SecureStorage.get(KEY_REFRESH);
    return (value as string | null) ?? null;
  }

  async function setToken(newToken: string) {
    await SecureStorage.set(KEY_ACCESS, newToken);
    token.value = newToken;
  }

  async function setTokens(tokens: { accessToken: string; refreshToken: string }) {
    await SecureStorage.set(KEY_ACCESS, tokens.accessToken);
    await SecureStorage.set(KEY_REFRESH, tokens.refreshToken);
    token.value = tokens.accessToken;
  }

  async function clearAuth() {
    await SecureStorage.remove(KEY_ACCESS);
    await SecureStorage.remove(KEY_REFRESH);
    token.value = null;
    user.value = null;
  }

  /* ─── Auth flows ─────────────────────────────────────────────── */

  async function fetchUser(): Promise<UserData> {
    const response = await api.get<UserData>('/users/me');
    user.value = response.data;
    return response.data;
  }

  async function login(payload: { username: string; password: string }): Promise<UserData> {
    const response = await api.post<TokenResponse>('/auth/login', payload);
    await setTokens({
      accessToken: response.data.accessToken,
      refreshToken: response.data.refreshToken,
    });
    return fetchUser();
  }

  /**
   * Refresh the access token using the stored refresh token.
   * Uses bare axios to avoid the api interceptor recursion.
   * Returns the new access token, or null if refresh failed.
   */
  async function refreshTokens(): Promise<string | null> {
    const refreshToken = await getRefreshToken();
    if (!refreshToken) return null;

    try {
      const res = await axios.post<TokenResponse>(`${baseURL}/auth/refresh`, {
        refreshToken,
      });
      await setTokens({
        accessToken: res.data.accessToken,
        refreshToken: res.data.refreshToken,
      });
      return res.data.accessToken;
    } catch {
      return null;
    }
  }

  /**
   * Server-side logout (best-effort) followed by local clear.
   */
  async function logout(): Promise<void> {
    try {
      await api.post('/users/logout');
    } catch {
      // Ignore — local state will still be cleared.
    }
    await clearAuth();
  }

  /* ─── Signup session helpers ─────────────────────────────────── */

  async function getSessionId(): Promise<string | null> {
    const value = await SecureStorage.get(KEY_SESSION);
    return (value as string | null) ?? null;
  }

  async function setSessionId(id: string) {
    await SecureStorage.set(KEY_SESSION, id);
  }

  async function clearSessionId() {
    await SecureStorage.remove(KEY_SESSION);
  }

  async function getOtpExpiresAt(): Promise<number> {
    const value = await SecureStorage.get(KEY_OTP_EXP);
    return Number(value) || 0;
  }

  async function setOtpExpiresAt(expiresAt: number) {
    await SecureStorage.set(KEY_OTP_EXP, expiresAt.toString());
  }

  async function clearOtpExpiresAt() {
    await SecureStorage.remove(KEY_OTP_EXP);
  }

  return {
    token,
    user,
    isLoggedIn,
    getToken,
    getRefreshToken,
    setToken,
    setTokens,
    clearAuth,
    login,
    fetchUser,
    refreshTokens,
    logout,
    getSessionId,
    setSessionId,
    clearSessionId,
    getOtpExpiresAt,
    setOtpExpiresAt,
    clearOtpExpiresAt,
  };
});
