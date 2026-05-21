<template>
  <div class="v-input-wrapper" :class="{ 'v-input-wrapper--shake': shake }">
    <q-input
      v-bind="$attrs"
      :model-value="modelValue"
      :error="error"
      :error-message="errorMessage"
      no-error-icon
      outlined
      bg-color="white"
      class="v-input"
      :label="label"
      hide-bottom-space
      @update:model-value="(val) => $emit('update:modelValue', val)"
    >
      <!-- Forward named slots (append handled explicitly below). -->
      <template
        v-for="name in forwardedSlots"
        :key="name"
        v-slot:[name]="slotProps"
      >
        <slot :name="name" v-bind="slotProps || {}" />
      </template>

      <template #append>
        <slot name="append" />
        <span v-if="error" class="v-input__error-badge" aria-hidden="true">!</span>
      </template>
    </q-input>
  </div>
</template>

<script setup lang="ts">
/**
 * Reusable Virdan Input.
 * Standardizes the 12px border radius and 52px height, plus the feedback
 * design-system inline error state (1.5px red border, "!" badge, shake).
 */
import { computed, ref, useSlots, watch } from 'vue';

const props = defineProps<{
  modelValue: string | number | null | undefined;
  label?: string;
  /** Marks the field invalid: red border + "!" badge + shake. */
  error?: boolean;
  /** Message shown below the field when `error` is true. */
  errorMessage?: string;
}>();

defineEmits<{
  (e: 'update:modelValue', value: string | number | null | undefined): void;
}>();

defineOptions({ inheritAttrs: false });

const slots = useSlots();
const forwardedSlots = computed(() =>
  Object.keys(slots).filter((name) => name !== 'append')
);

// Shake once on each false -> true transition of the error state.
const shake = ref(false);
let shakeTimer: ReturnType<typeof setTimeout> | undefined;

watch(
  () => props.error,
  (isError, wasError) => {
    if (isError && !wasError) {
      shake.value = true;
      clearTimeout(shakeTimer);
      shakeTimer = setTimeout(() => {
        shake.value = false;
      }, 400);
    }
  }
);
</script>

<style lang="scss">
.v-input-wrapper--shake {
  animation: vd-shake 0.4s ease 1;
}

.v-input {
  .q-field__control {
    border-radius: 12px !important;
    height: 52px !important;

    &::before {
      border-color: #e5e7eb !important;
    }
  }

  .q-field__label {
    color: #9ca3af;
  }

  &.q-field--focused,
  &.q-field--float {
    .q-field__label {
      color: var(--q-primary);
    }
  }

  // ─── Inline error state ──────────────────────────────────────
  &.q-field--error {
    .q-field__control::before {
      border-color: #ef4444 !important;
      border-width: 1.5px !important;
    }

    .q-field__messages {
      color: #ef4444;
    }

    .q-field__label {
      color: #ef4444;
    }
  }

  &__error-badge {
    display: flex;
    align-items: center;
    justify-content: center;
    width: 20px;
    height: 20px;
    border-radius: 999px;
    background: #ef4444;
    color: #ffffff;
    font-size: 12px;
    font-weight: 700;
    line-height: 1;
  }
}

@media (prefers-reduced-motion: reduce) {
  .v-input-wrapper--shake { animation: none; }
}
</style>
