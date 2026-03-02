import { Injectable, signal, computed } from '@angular/core';
import { Preferences } from '@capacitor/preferences';

@Injectable({ providedIn: 'root' })
export class AuthService {
  private _token = signal<string | null>(null);
  isLoggedIn = computed(() => !!this._token());

  async init() {
    const { value } = await Preferences.get({ key: 'token' });
    this._token.set(value);
  }

  async setToken(token: string) {
    this._token.set(token);
    await Preferences.set({ key: 'token', value: token });
  }

  async logout() {
    this._token.set(null);
    await Preferences.remove({ key: 'token' });
  }

  getToken() {
    return this._token();
  }
}