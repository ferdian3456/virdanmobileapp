import { Routes } from '@angular/router';
import { authGuard } from './core/guards/auth-guard';

export const routes: Routes = [
  {
    path: '',
    redirectTo: 'login',
    pathMatch: 'full',
  },
  {
    path: 'register',
    loadComponent: () => import('./features/register/register.page').then(m => m.RegisterPage)
  },
  {
    path: 'login',
    loadComponent: () => import('./features/login/login.page').then(m => m.LoginPage)
  },
  {
    path: 'verify-otp',
    loadComponent: () => import('./features/verify-otp/verify-otp.page').then( m => m.VerifyOtpPage)
  },
];