import { inject } from '@angular/core';
import { CanActivateFn, Router } from '@angular/router';
import { AuthService } from '../services/auth';

export const sessionGuard: CanActivateFn = async () => {
  const auth = inject(AuthService);
  const router = inject(Router);
  const sessionId = await auth.getSessionId();
  if (!sessionId) {
    router.navigate(['/login']);
    return false;
  }
  return true;
};