// auth.ts
import { Injectable, signal, computed } from '@angular/core';
import { HttpClient } from '@angular/common/http';
import { firstValueFrom } from 'rxjs';
import { SecureStorage } from '@aparajita/capacitor-secure-storage';
import { LoginResponse, TokenResponse } from '../models/auth.model';
import { TokenService } from './token';
import { environment } from '../../../environments/environment';

@Injectable({ providedIn: 'root' })
export class AuthService {
  private _isLoggedIn = signal(false);
  isLoggedIn = computed(() => this._isLoggedIn());

  private refreshPromise: Promise<TokenResponse> | null = null;

  constructor(
    private tokenService: TokenService,
    private http: HttpClient
  ) {}

  async init(): Promise<void> {
    await this.tokenService.loadTokens();
    this._isLoggedIn.set(!!this.tokenService.getAccessToken());
  }

  async setTokens(res: LoginResponse | TokenResponse): Promise<void> {
    await this.tokenService.setTokens(res.accessToken, res.refreshToken);
    this._isLoggedIn.set(true);
  }

  async logout(): Promise<void> {
    await this.tokenService.clearTokens();
    this._isLoggedIn.set(false);
    this.refreshPromise = null;
  }

  getToken(): string | null {
    return this.tokenService.getAccessToken();
  }

  async refreshToken(): Promise<TokenResponse> {
    if (this.refreshPromise) {
      return this.refreshPromise;
    }

    this.refreshPromise = this.performRefresh();

    try {
      return await this.refreshPromise;
    } finally {
      this.refreshPromise = null;
    }
  }

  private async performRefresh(): Promise<TokenResponse> {
    const refreshToken = this.tokenService.getRefreshToken();

    if (!refreshToken) {
      throw new Error('No refresh token available');
    }

    // Gunakan HttpClient langsung, bukan ApiService
    // karena /auth/refresh adalah public endpoint
    const response = await firstValueFrom(
      this.http.post<TokenResponse>(
        `${environment.apiUrl}/auth/refresh`,
        { refreshToken }
      )
    );

    await this.setTokens(response);
    return response;
  }

  async setSessionId(sessionId: string): Promise<void> {
    await SecureStorage.set('session_id', sessionId);
  }

  async getSessionId(): Promise<string | null> {
    try {
      const result = await SecureStorage.get('session_id');
      return (result as string) ?? null;
    } catch {
      return null;
    }
  }

  async clearSessionId(): Promise<void> {
    await SecureStorage.remove('session_id');
  }

  async setOtpExpiresAt(expiresAt: number): Promise<void> {
    await SecureStorage.set('otp_expires_at', expiresAt.toString());
  }

  async getOtpExpiresAt(): Promise<number> {
    try {
      const result = await SecureStorage.get('otp_expires_at');
      return parseInt(result as string) || 0;
    } catch {
      return 0;
    }
  }

  async clearOtpExpiresAt(): Promise<void> {
    await SecureStorage.remove('otp_expires_at');
  }
}