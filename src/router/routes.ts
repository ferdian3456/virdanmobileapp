import type { RouteRecordRaw } from 'vue-router';

const routes: RouteRecordRaw[] = [
  {
    path: '/',
    redirect: '/app/home',
  },

  /* ─── Onboarding gate (after register / first login with no server) ─── */
  {
    path: '/onboarding',
    component: () => import('layouts/BlankLayout.vue'),
    meta: { requiresAuth: true },
    redirect: '/onboarding/server-choice',
    children: [
      {
        path: 'server-choice',
        name: 'onboarding-server-choice',
        component: () => import('pages/OnboardingServerChoicePage.vue'),
      },
      {
        path: 'create-server',
        name: 'onboarding-create-server',
        component: () => import('pages/CreateServerPage.vue'),
        meta: { onboardingFlow: true },
      },
      {
        path: 'create-server/profile',
        name: 'onboarding-create-server-profile',
        component: () => import('pages/YourProfilePage.vue'),
        meta: { onboardingFlow: true },
      },
      {
        path: 'explore-servers',
        name: 'onboarding-explore-servers',
        component: () => import('pages/ExploreServersPage.vue'),
        meta: { onboardingFlow: true },
      },
    ],
  },

  /* ─── Authenticated app shell ─── */
  {
    path: '/app',
    component: () => import('layouts/MainLayout.vue'),
    meta: { requiresAuth: true, requiresServer: true },
    redirect: '/app/home',
    children: [
      { path: 'home', name: 'home', component: () => import('pages/HomePage.vue') },
      { path: 'explore', name: 'explore', component: () => import('pages/ExplorePage.vue') },
      {
        path: 'create-post',
        name: 'create-post',
        component: () => import('pages/CreatePostPage.vue'),
        meta: { hideBottomNav: true },
      },
      {
        path: 'notifications',
        name: 'notifications',
        component: () => import('pages/NotificationsPage.vue'),
      },
      { path: 'profile', name: 'profile', component: () => import('pages/ProfilePage.vue') },

      /* ─── Server-domain routes ─── */
      {
        path: 'create-server',
        name: 'create-server',
        component: () => import('pages/CreateServerPage.vue'),
        meta: { hideBottomNav: true },
      },
      {
        path: 'create-server/profile',
        name: 'create-server-profile',
        component: () => import('pages/YourProfilePage.vue'),
        meta: { hideBottomNav: true },
      },
      {
        path: 'explore-servers',
        name: 'explore-servers',
        component: () => import('pages/ExploreServersPage.vue'),
      },
      {
        path: 'server/:id',
        name: 'server-detail',
        component: () => import('pages/ServerDetailPage.vue'),
        props: true,
      },
      {
        path: 'server/:id/settings',
        name: 'server-settings',
        component: () => import('pages/EditServerSettingsPage.vue'),
        props: true,
      },

      /* ─── Post / interaction routes ─── */
      {
        path: 'post/:postId',
        name: 'post-detail',
        component: () => import('pages/PostDetailPage.vue'),
        props: true,
      },
      {
        path: 'comments/:postId',
        name: 'comments',
        component: () => import('pages/CommentsPage.vue'),
        props: true,
        meta: { hideBottomNav: true },
      },

      /* ─── Mocked pages (no BE yet) ─── */
      {
        path: 'messages',
        name: 'messages',
        component: () => import('pages/ChatPage.vue'),
      },
      {
        path: 'settings',
        name: 'settings',
        component: () => import('pages/SettingsPage.vue'),
        meta: { hideBottomNav: true },
      },
      {
        path: 'edit-profile',
        name: 'edit-profile',
        component: () => import('pages/EditProfilePage.vue'),
        meta: { hideBottomNav: true },
      },
      {
        path: 'change-password',
        name: 'change-password',
        component: () => import('pages/ChangePasswordPage.vue'),
        meta: { hideBottomNav: true },
      },
      {
        path: 'change-email',
        name: 'change-email',
        component: () => import('pages/ChangeEmailPage.vue'),
        meta: { hideBottomNav: true },
      },
      {
        path: 'notification-settings',
        name: 'notification-settings',
        component: () => import('pages/NotificationSettingsPage.vue'),
        meta: { hideBottomNav: true },
      },
      {
        path: 'privacy-security',
        name: 'privacy-security',
        component: () => import('pages/PrivacySecurityPage.vue'),
        meta: { hideBottomNav: true },
      },
      {
        path: 'help-center',
        name: 'help-center',
        component: () => import('pages/HelpCenterPage.vue'),
        meta: { hideBottomNav: true },
      },
      {
        path: 'terms-of-service',
        name: 'terms-of-service',
        component: () => import('pages/TermsOfServicePage.vue'),
        meta: { hideBottomNav: true },
      },
      {
        path: 'privacy-policy',
        name: 'privacy-policy',
        component: () => import('pages/PrivacyPolicyPage.vue'),
        meta: { hideBottomNav: true },
      },
    ],
  },

  /* ─── Auth chain (signup steps + login) ─── */
  {
    path: '/auth',
    component: () => import('layouts/BlankLayout.vue'),
    redirect: '/auth/login',
    children: [
      {
        path: 'login',
        name: 'login',
        component: () => import('pages/LoginPage.vue'),
        meta: { guestOnly: true },
      },
      {
        path: 'register',
        name: 'register',
        component: () => import('pages/RegisterPage.vue'),
        meta: { guestOnly: true },
      },
      {
        path: 'verify-otp',
        name: 'verify-otp',
        component: () => import('pages/VerifyOtpPage.vue'),
        meta: { guestOnly: true },
      },
      {
        path: 'verify-password',
        name: 'verify-password',
        component: () => import('pages/VerifyPasswordPage.vue'),
        meta: { guestOnly: true },
      },
    ],
  },

  /* ─── 404 ─── */
  {
    path: '/:catchAll(.*)*',
    component: () => import('pages/ErrorNotFound.vue'),
  },
];

export default routes;
