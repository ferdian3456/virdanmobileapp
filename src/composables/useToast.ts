import { reactive } from 'vue';

/**
 * Brand toast system — replaces the former Quasar Notify wrapper.
 *
 * State is a module-level reactive singleton: every `useToast()` caller and
 * the single `<VToastHost>` share the same queue. Auto-dismiss timers are
 * owned here so callers never manage timeouts.
 */

export type ToastType = 'success' | 'error' | 'warning' | 'info';

export interface ToastOptions {
  /** Bold first line. Required. */
  title: string;
  /** Muted second line. Optional. */
  caption?: string;
  /** Retry handler — only honored for error toasts. */
  onRetry?: () => void;
  /** Override auto-dismiss in ms. 0 keeps the toast until dismissed. */
  duration?: number;
}

export interface ToastItem extends ToastOptions {
  id: number;
  type: ToastType;
}

/** Maximum simultaneously visible toasts; oldest is dropped past this. */
const MAX_STACK = 3;

const DEFAULT_DURATION: Record<ToastType, number> = {
  success: 2600,
  warning: 2600,
  info: 2600,
  error: 5000,
};

const toasts = reactive<ToastItem[]>([]);
const timers = new Map<number, ReturnType<typeof setTimeout>>();
let seq = 0;

function dismiss(id: number): void {
  const index = toasts.findIndex((t) => t.id === id);
  if (index !== -1) toasts.splice(index, 1);

  const timer = timers.get(id);
  if (timer) {
    clearTimeout(timer);
    timers.delete(id);
  }
}

function push(type: ToastType, options: ToastOptions): number {
  const id = ++seq;
  const item: ToastItem = { ...options, id, type };

  // Retry is meaningful only for errors; drop it everywhere else.
  if (type !== 'error') delete item.onRetry;

  toasts.push(item);

  // Enforce the stack cap by evicting the oldest toasts.
  while (toasts.length > MAX_STACK) {
    dismiss(toasts[0]!.id);
  }

  const duration = options.duration ?? DEFAULT_DURATION[type];
  if (duration > 0) {
    timers.set(
      id,
      setTimeout(() => dismiss(id), duration)
    );
  }

  return id;
}

/** Caller-facing API: emit toasts. Returns the toast id for manual dismissal. */
export function useToast() {
  return {
    success: (options: ToastOptions) => push('success', options),
    error: (options: ToastOptions) => push('error', options),
    warning: (options: ToastOptions) => push('warning', options),
    info: (options: ToastOptions) => push('info', options),
    dismiss,
  };
}

/** Host-facing API: read the live queue and dismiss entries. */
export function useToastQueue() {
  return { toasts, dismiss };
}
