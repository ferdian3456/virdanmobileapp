<template>
  <q-btn
    v-bind="$attrs"
    :loading="loading"
    unelevated
    no-caps
    class="v-button text-weight-bold"
    :class="{ 'v-button--loading': loading }"
  >
    <slot />
    <!-- Forward named slots (default handled above, loading handled below). -->
    <template
      v-for="name in forwardedSlots"
      :key="name"
      v-slot:[name]="slotProps"
    >
      <slot :name="name" v-bind="slotProps || {}" />
    </template>

    <!-- In-place button spinner: keeps the label visible while submitting. -->
    <template #loading>
      <q-spinner class="v-button__spinner" size="14px" :thickness="2" />
      <span v-if="loadingLabel" class="v-button__loading-label">
        {{ loadingLabel }}
      </span>
    </template>
  </q-btn>
</template>

<script setup lang="ts">
/**
 * Reusable Virdan Button.
 * Standardizes the 14px border radius and 48px height, and the feedback
 * design-system loading state (spinner + optional "Saving…" label).
 */
import { computed, useSlots } from 'vue';

defineProps<{
  /** Shows the in-place spinner and blocks interaction. */
  loading?: boolean;
  /** Optional label shown next to the spinner, e.g. "Menyimpan…". */
  loadingLabel?: string;
}>();

defineOptions({ inheritAttrs: false });

const slots = useSlots();
const forwardedSlots = computed(() =>
  Object.keys(slots).filter((name) => name !== 'default' && name !== 'loading')
);
</script>

<style lang="scss">
.v-button {
  border-radius: 14px !important;
  min-height: 48px;
  font-weight: 600;
  letter-spacing: -0.01em;

  &--loading {
    opacity: 0.95;
    pointer-events: none;
  }

  &__loading-label {
    margin-left: 8px;
  }
}
</style>
