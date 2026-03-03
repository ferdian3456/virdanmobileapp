import { Injectable, signal, computed } from '@angular/core';
import { SecureStorage } from '@aparajita/capacitor-secure-storage';
import { LoginResponse } from '../models/auth.model';

@Injectable({ providedIn: 'root' })
export class AuthService {
  private _token = signal<string | null>(null);
  isLoggedIn = computed(() => !!this._token());

  async init() {
    try {
      const result = await SecureStorage.get('access_token');
      this._token.set(result as string ?? null);
    } catch {
      this._token.set(null);
    }
  }

  async setSessionId(sessionId: string) {
    await SecureStorage.set('session_id', sessionId);
  }

  async getSessionId(): Promise<string | null> {
    try {
      const result = await SecureStorage.get('session_id');
      return result as string ?? null;
    } catch {
      return null;
    }
  }

  async clearSessionId() {
    await SecureStorage.remove('session_id');
  }

  async setTokens(res: LoginResponse) {
    await SecureStorage.set('access_token', res.accessToken);
    await SecureStorage.set('refresh_token', res.refreshToken);
    this._token.set(res.accessToken);
  }

  async logout() {
    await SecureStorage.remove('access_token');
    await SecureStorage.remove('refresh_token');
    this._token.set(null);
  }

  getToken() {
    return this._token();
  }
}