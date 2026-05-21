<template>
  <div
    class="v-toast"
    :class="[`v-toast--${toast.type}`, { 'v-toast--shake': toast.type === 'error' }]"
    role="status"
    aria-live="polite"
  >
    <span class="v-toast__bubble">
      <component :is="icon" :size="14" :stroke-width="3" />
    </span>

    <div class="v-toast__body">
      <p class="v-toast__title">{{ toast.title }}</p>
      <p v-if="toast.caption" class="v-toast__caption">{{ toast.caption }}</p>
    </div>

    <button
      v-if="toast.type === 'error' && toast.onRetry"
      type="button"
      class="v-toast__retry"
      @click="onRetryClick"
    >
      Coba lagi
    </button>
  </div>
</template>

<script setup lang="ts">
/**
 * Single brand toast. Purely presentational — the queue, timers and stacking
 * live in useToast.ts; this component only renders one ToastItem and reports
 * dismissal back to the host.
 */
import { computed } from 'vue';
import { Check, X, TriangleAlert, Info } from 'lucide-vue-next';
import type { ToastItem } from 'src/composables/useToast';

const props = defineProps<{ toast: ToastItem }>();
const emit = defineEmits<{ (e: 'dismiss'): void }>();

const icon = computed(() => {
  switch (props.toast.type) {
    case 'success':
      return Check;
    case 'error':
      return X;
    case 'warning':
      return TriangleAlert;
    default:
      return Info;
  }
});

function onRetryClick(): void {
  props.toast.onRetry?.();
  emit('dismiss');
}
</script>

<style lang="scss">
.v-toast {
  display: flex;
  align-items: flex-start;
  gap: 12px;
  width: min(440px, calc(100vw - 32px));
  padding: 14px 16px;
  background: #ffffff;
  border: 1px solid #eef0f4;
  border-radius: 16px;
  box-shadow: 0 8px 24px rgba(20, 20, 43, 0.12);
  pointer-events: auto;

  &__bubble {
    flex: 0 0 auto;
    display: flex;
    align-items: center;
    justify-content: center;
    width: 24px;
    height: 24px;
    border-radius: 999px;
    color: #ffffff;
  }

  &__body {
    flex: 1 1 auto;
    min-width: 0;
  }

  &__title {
    margin: 0;
    font-size: 13px;
    font-weight: 700;
    letter-spacing: -0.01em;
    color: #14142b;
  }

  &__caption {
    margin: 2px 0 0;
    font-size: 11.5px;
    font-weight: 500;
    color: #9b9db0;
  }

  &__retry {
    flex: 0 0 auto;
    align-self: center;
    padding: 6px 12px;
    border: 0;
    border-radius: 999px;
    background: rgba(239, 68, 68, 0.1);
    color: #ef4444;
    font-size: 11.5px;
    font-weight: 700;
    cursor: pointer;
  }

  // ─── Type variants ───────────────────────────────────────────
  &--success .v-toast__bubble { background: #007bff; }
  &--info .v-toast__bubble { background: #007bff; }
  &--warning .v-toast__bubble { background: #f59e0b; }

  &--error {
    border-color: rgba(239, 68, 68, 0.28);
    .v-toast__bubble { background: #ef4444; }
  }

  // Error toasts shake once shortly after appearing.
  &--shake {
    animation: vd-shake 0.5s ease 0.32s 1;
  }
}

@media (prefers-reduced-motion: reduce) {
  .v-toast--shake { animation: none; }
}
</style>
