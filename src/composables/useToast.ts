import { Notify, type QNotifyCreateOptions } from 'quasar';

type ToastType = 'positive' | 'negative' | 'warning' | 'info';

const baseConfig: QNotifyCreateOptions = {
  position: 'top',
  timeout: 3000,
  progress: false,
  textColor: 'white',
};

export function useToast() {
  function notify(type: ToastType, message: string, opts: QNotifyCreateOptions = {}) {
    Notify.create({ ...baseConfig, type, message, ...opts });
  }

  return {
    success: (message: string, opts?: QNotifyCreateOptions) =>
      notify('positive', message, opts),
    error: (message: string, opts?: QNotifyCreateOptions) =>
      notify('negative', message, opts),
    warning: (message: string, opts?: QNotifyCreateOptions) =>
      notify('warning', message, opts),
    info: (message: string, opts?: QNotifyCreateOptions) => notify('info', message, opts),
  };
}
