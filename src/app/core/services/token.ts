import { Injectable } from '@angular/core';
import { SecureStorage } from '@aparajita/capacitor-secure-storage';

@Injectable({ providedIn: 'root' })
export class TokenService {
  private _accessToken: string | null = null;
  private _refreshToken: string | null = null;

  async loadTokens(): Promise<void> {
    try {
      const access = await SecureStorage.get('access_token');
      this._accessToken = (access as string) ?? null;
    } catch {
      this._accessToken = null;
    }

    try {
      const refresh = await SecureStorage.get('refresh_token');
      this._refreshToken = (refresh as string) ?? null;
    } catch {
      this._refreshToken = null;
    }
  }

  async setTokens(accessToken: string, refreshToken: string): Promise<void> {
    console.log('setTokens called', { accessToken, refreshToken });
    try {
      await SecureStorage.set('access_token', accessToken);
      console.log('access_token saved');
      await SecureStorage.set('refresh_token', refreshToken);
      console.log('refresh_token saved');
    } catch (e) {
      console.error('SecureStorage error', e);
    }
    this._accessToken = accessToken;
    this._refreshToken = refreshToken;
  }

  async clearTokens(): Promise<void> {
    try { await SecureStorage.remove('access_token'); } catch {}
    try { await SecureStorage.remove('refresh_token'); } catch {}
    this._accessToken = null;
    this._refreshToken = null;
  }

  getAccessToken(): string | null {
    return this._accessToken;
  }

  getRefreshToken(): string | null {
    return this._refreshToken;
  }
}