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
      { path: 'explore', loadComponent: () => import('./features/explore/explore.page').then(m => m.ExplorePage) },
      { path: 'create-post', loadComponent: () => import('./features/create-post/create-post.page').then(m => m.CreatePostPage) },
      { path: 'notification', loadComponent: () => import('./features/notification/notification.page').then(m => m.NotificationPage) },
      { path: 'profile', loadComponent: () => import('./features/profile/profile.page').then(m => m.ProfilePage) },
      { path: 'explore-servers', loadComponent: () => import('./features/explore-servers/explore-servers.page').then(m => m.ExploreServersPage) },
      {
        path: 'feed',
        loadComponent: () => import('./features/feed/feed.page').then( m => m.FeedPage)
      },
    ]
  },
  {
    path: 'app/comments',
    loadComponent: () => import('./features/comments/comments.page').then(m => m.CommentsPage),
    canActivate: [authGuard],
  },
  {
    path: 'app/post-detail/:postId',
    loadComponent: () => import('./features/post-detail/post-detail.page').then(m => m.PostDetailPage),
    canActivate: [authGuard],
  },

]