import { Routes } from '@angular/router';
import { authGuard } from './core/guards/auth-guard';
import { sessionGuard } from './core/guards/session-guard';

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
    loadComponent: () => import('./features/verify-otp/verify-otp.page').then(m => m.VerifyOtpPage), canActivate: [sessionGuard]
  },
  {
    path: 'verify-username',
    loadComponent: () => import('./features/verify-username/verify-username.page').then(m => m.VerifyUsernamePage), canActivate: [sessionGuard]
  },
  {
    path: 'verify-password',
    loadComponent: () => import('./features/verify-password/verify-password.page').then(m => m.VerifyPasswordPage), canActivate: [sessionGuard]
  },
  {
    path: 'app',
    loadComponent: () => import('./shared/layout/main-layout/main-layout.component').then(m => m.MainLayoutComponent),
    canActivate: [authGuard],
    children: [
      { path: '', redirectTo: 'home', pathMatch: 'full' },
      { path: 'home', loadComponent: () => import('./features/homepage/homepage.page').then(m => m.HomepagePage) },
      // { path: 'search', loadComponent: () => import('./features/search/search.page').then(m => m.SearchPage) },
      // { path: 'add-post', loadComponent: () => import('./features/add-post/add-post.page').then(m => m.AddPostPage) },
      // { path: 'notifications', loadComponent: () => import('./features/notifications/notifications.page').then(m => m.NotificationsPage) },
      // { path: 'profile', loadComponent: () => import('./features/profile/profile.page').then(m => m.ProfilePage) },
    ]
  }
]