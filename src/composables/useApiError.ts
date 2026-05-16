import { AxiosError } from 'axios';

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
