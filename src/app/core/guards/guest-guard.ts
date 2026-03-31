import { inject } from '@angular/core';
import { CanActivateFn, Router } from '@angular/router';
import { AuthService } from '../services/auth';
import { TokenService } from '../services/token';

export const guestGuard: CanActivateFn = async () => {
  const auth = inject(AuthService);
  const tokenService = inject(TokenService);
  const router = inject(Router);

  // Pastikan token sudah dimuat dari SecureStorage
  await auth.init();

  const accessToken = tokenService.getAccessToken();
  const refreshToken = tokenService.getRefreshToken();

  // Jika sudah ada access token DAN refresh token, 
  // maka user dianggap sudah login dan tidak boleh ke halaman auth
  if (accessToken && refreshToken) {
    router.navigate(['/app/home']);
    return false;
  }

  return true;
};
