import { defineRouter } from '#q-app/wrappers';
import {
  createMemoryHistory,
  createRouter,
  createWebHashHistory,
  createWebHistory,
} from 'vue-router';
import routes from './routes';

import { useAuthStore } from 'src/stores/auth.store';
import { useAppStore } from 'src/stores/app.store';

export default defineRouter(function ({ store }) {
  const createHistory = process.env.SERVER
    ? createMemoryHistory
    : process.env.VUE_ROUTER_MODE === 'history'
      ? createWebHistory
      : createWebHashHistory;

  const Router = createRouter({
    scrollBehavior: () => ({ left: 0, top: 0 }),
    routes,
    history: createHistory(process.env.VUE_ROUTER_BASE),
  });

  if (process.env.DEV) {
    (window as unknown as { __router?: typeof Router }).__router = Router;
  }

  Router.beforeEach(async (to) => {
    const authStore = useAuthStore(store);
    const appStore = useAppStore(store);

    const isAuthenticated = !!(await authStore.getToken());

    // 1. guestOnly routes — already authenticated user goes to /app/home.
    if (to.meta.guestOnly && isAuthenticated) {
      return { name: 'home' };
    }

    // 2. requiresAuth — kick out anonymous users.
    if (to.meta.requiresAuth && !isAuthenticated) {
      return { name: 'login' };
    }

    // 3. requiresServer — user must have at least one joined server.
    if (to.meta.requiresServer && isAuthenticated) {
      try {
        if (!appStore.isInitialized) {
          await appStore.fetchMyServers();
        }
        if (!appStore.hasServers) {
          return { name: 'onboarding-server-choice' };
        }
      } catch {
        // Network or server failure — let the page render its own empty/error state
        // rather than redirecting blindly.
      }
    }

    return true;
  });

  return Router;
});
