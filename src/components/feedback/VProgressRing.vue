<template>
  <div
    class="v-progress-ring"
    :class="{ 'v-progress-ring--overlay': overlay }"
    role="progressbar"
    :aria-valuenow="rounded"
    aria-valuemin="0"
    aria-valuemax="100"
  >
    <div class="v-progress-ring__inner" :style="{ width: `${size}px`, height: `${size}px` }">
      <svg :width="size" :height="size" :viewBox="`0 0 ${size} ${size}`">
        <circle
          class="v-progress-ring__track"
          :cx="center"
          :cy="center"
          :r="radius"
          fill="none"
          :stroke-width="stroke"
        />
        <circle
          class="v-progress-ring__fill"
          :cx="center"
          :cy="center"
          :r="radius"
          fill="none"
          :stroke-width="stroke"
          stroke-linecap="round"
          :stroke-dasharray="circumference"
          :stroke-dashoffset="dashOffset"
          :transform="`rotate(-90 ${center} ${center})`"
        />
      </svg>
      <span class="v-progress-ring__label">{{ rounded }}%</span>
    </div>
  </div>
</template>

<script setup lang="ts">
/**
 * Determinate progress ring for avatar / file uploads.
 * Spec: ring 4px, track accent@12%, fill #007BFF, percentage centered.
 * In `overlay` mode it fills the (position: relative) parent with a
 * translucent blurred backdrop while an upload is in flight.
 */
import { computed } from 'vue';

const props = withDefaults(
  defineProps<{
    /** Upload progress, 0-100. */
    progress: number;
    /** Outer diameter in px. */
    size?: number;
    /** Stroke width in px. */
    stroke?: number;
    /** Cover the parent element with a blurred backdrop. */
    overlay?: boolean;
  }>(),
  { size: 56, stroke: 4, overlay: false }
);

const clamped = computed(() => Math.min(100, Math.max(0, props.progress)));
const rounded = computed(() => Math.round(clamped.value));
const center = computed(() => props.size / 2);
const radius = computed(() => (props.size - props.stroke) / 2);
const circumference = computed(() => 2 * Math.PI * radius.value);
const dashOffset = computed(() => circumference.value * (1 - clamped.value / 100));
</script>

<style lang="scss">
.v-progress-ring {
  display: inline-flex;

  &--overlay {
    position: absolute;
    inset: 0;
    align-items: center;
    justify-content: center;
    background: rgba(255, 255, 255, 0.55);
    backdrop-filter: blur(2px);
    -webkit-backdrop-filter: blur(2px);
    z-index: 2;
  }

  &__inner {
    position: relative;
    display: inline-flex;
    align-items: center;
    justify-content: center;
  }

  &__track {
    stroke: rgba(0, 123, 255, 0.12);
  }

  &__fill {
    stroke: #007bff;
    transition: stroke-dashoffset 0.2s ease;
  }

  &__label {
    position: absolute;
    font-size: 11px;
    font-weight: 700;
    letter-spacing: -0.01em;
    color: #14142b;
  }
}
</style>
