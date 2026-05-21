import { AxiosError } from 'axios';
import type { ToastOptions } from 'src/composables/useToast';

export interface ApiErrorPayload {
  code: string;
  message: string;
  param?: string;
}

interface NormalizedError {
  code: string;
  message: string;
  param?: string;
  status?: number;
}

const FALLBACK_MESSAGE = 'An unexpected error occurred. Please try again.';

export function normalizeError(error: unknown): NormalizedError {
  if (error instanceof AxiosError) {
    const status = error.response?.status;
    const payload = error.response?.data as
      | { error?: ApiErrorPayload }
      | ApiErrorPayload
      | undefined;
    const inner = (payload && 'error' in payload ? payload.error : payload) as
      | ApiErrorPayload
      | undefined;

    const result: NormalizedError = {
      code: inner?.code ?? 'NETWORK_ERROR',
      message: inner?.message ?? FALLBACK_MESSAGE,
    };
    if (inner?.param) result.param = inner.param;
    if (status !== undefined) result.status = status;
    return result;
  }

  if (error instanceof Error) {
    return { code: 'UNKNOWN_ERROR', message: error.message || FALLBACK_MESSAGE };
  }

  return { code: 'UNKNOWN_ERROR', message: FALLBACK_MESSAGE };
}

export function applyFieldErrors(
  error: unknown,
  errors: Record<string, string>,
  fallbackKey = 'general'
): void {
  const normalized = normalizeError(error);
  if (normalized.param) {
    errors[normalized.param] = normalized.message;
  } else {
    errors[fallbackKey] = normalized.message;
  }
}

/**
 * Builds brand error-toast options from an API error.
 * Network failures get a generic connection headline + caption; other
 * failures surface the server message as the title.
 *
 * Pass `onRetry` ONLY for safe-to-repeat actions (data loads/fetches).
 * Never pass it for create/update/delete — a retry could duplicate the
 * operation.
 */
export function apiErrorToast(error: unknown, onRetry?: () => void): ToastOptions {
  const normalized = normalizeError(error);
  const isNetwork =
    normalized.status === undefined || normalized.code === 'NETWORK_ERROR';

  const options: ToastOptions = isNetwork
    ? {
        title: 'Tidak dapat terhubung',
        caption: 'Periksa koneksi internetmu lalu coba lagi.',
      }
    : { title: normalized.message };

  if (onRetry) options.onRetry = onRetry;
  return options;
}
