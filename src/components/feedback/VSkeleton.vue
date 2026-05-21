<template>
  <div
    class="v-skeleton"
    :class="`v-skeleton--${variant}`"
    :style="boxStyle"
    aria-hidden="true"
  />
</template>

<script setup lang="ts">
/**
 * Skeleton shimmer primitive for first-load states.
 * Compose page-specific skeletons (feed card, profile header, ...) from this.
 * Spec: shimmer 1.4s linear, tone #ecedf2 -> #f6f7fa, radius 6-12px.
 */
import { computed } from 'vue';

const props = withDefaults(
  defineProps<{
    /** box: generic block, text: thin line, circle: avatar placeholder. */
    variant?: 'box' | 'text' | 'circle';
    width?: string;
    height?: string;
    /** Overrides the variant default radius. */
    radius?: string;
  }>(),
  { variant: 'box' }
);

const boxStyle = computed(() => {
  const style: Record<string, string> = {};
  if (props.width) style.width = props.width;
  if (props.height) style.height = props.height;
  if (props.radius) style.borderRadius = props.radius;
  return style;
});
</script>

<style lang="scss">
.v-skeleton {
  display: block;
  background: linear-gradient(90deg, #ecedf2 25%, #f6f7fa 50%, #ecedf2 75%);
  background-size: 200% 100%;
  animation: vd-shimmer 1.4s linear infinite;

  &--box {
    height: 16px;
    border-radius: 8px;
  }

  &--text {
    height: 12px;
    border-radius: 6px;
  }

  &--circle {
    aspect-ratio: 1 / 1;
    border-radius: 999px;
  }
}

@media (prefers-reduced-motion: reduce) {
  .v-skeleton {
    animation: none;
    background-position: 50% 0;
  }
}
</style>
