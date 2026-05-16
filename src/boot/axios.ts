import { boot } from 'quasar/wrappers';
import axios, {
  type AxiosInstance,
  type InternalAxiosRequestConfig,
} from 'axios';
import { useAuthStore } from 'src/stores/auth.store';

declare module '@vue/runtime-core' {
  interface ComponentCustomProperties {
    $axios: AxiosInstance;
    $api: AxiosInstance;
  }
}

const baseURL = process.env.API_URL ?? 'http://localhost:8081/api';

const api: AxiosInstance = axios.create({ baseURL });

type RetriableConfig = InternalAxiosRequestConfig & { _retry?: boolean };

let refreshInflight: Promise<string | null> | null = null;

const SKIP_REFRESH_PATHS = ['/auth/login', '/auth/refresh', '/auth/signup/'];

function shouldSkipRefresh(url: string | undefined): boolean {
  if (!url) return false;
  return SKIP_REFRESH_PATHS.some((p) => url.includes(p));
}

export default boot(({ router, store }) => {
  api.interceptors.request.use(async (config) => {
    const authStore = useAuthStore(store);
    const token = await authStore.getToken();
    if (token) {
      config.headers.Authorization = `Bearer ${token}`;
    }
    return config;
  });

  api.interceptors.response.use(
    (response) => response,
    async (error) => {
      const status = error.response?.status as number | undefined;
      const original = error.config as RetriableConfig | undefined;

      const canRetry =
        status === 401 &&
        !!original &&
        !original._retry &&
        !shouldSkipRefresh(original.url);

      if (canRetry && original) {
        original._retry = true;
        const authStore = useAuthStore(store);

        try {
          if (!refreshInflight) {
            refreshInflight = authStore.refreshTokens();
          }
          const newToken = await refreshInflight;
          refreshInflight = null;

          if (!newToken) {
            throw new Error('refresh_failed');
          }

          original.headers.Authorization = `Bearer ${newToken}`;
          return api(original);
        } catch (refreshErr) {
          refreshInflight = null;
          await authStore.clearAuth();
          await router.push({ name: 'login' });
          return Promise.reject(
            refreshErr instanceof Error ? refreshErr : new Error(String(refreshErr))
          );
        }
      }

      return Promise.reject(error instanceof Error ? error : new Error(String(error)));
    }
  );
});

export { api, baseURL };
