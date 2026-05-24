<template>
  <transition name="v-field-error">
    <div v-if="message" class="v-field-error" role="alert">
      <span class="v-field-error__badge" aria-hidden="true">!</span>
      <span class="v-field-error__text">{{ message }}</span>
    </div>
  </transition>
</template>

<script setup lang="ts">
/**
 * Inline error for fields that are not a VInput (avatar picker, file upload,
 * custom controls). For text inputs use VInput's built-in error state instead.
 * Shakes once each time a message appears.
 */
defineProps<{ message?: string }>();
</script>

<style lang="scss">
.v-field-error {
  display: flex;
  align-items: center;
  gap: 6px;
  margin-top: 6px;
  animation: vd-shake 0.4s ease 1;

  &__badge {
    flex: 0 0 auto;
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

  &__text {
    font-size: 11.5px;
    font-weight: 500;
    color: #ef4444;
  }
}

.v-field-error-enter-active {
  transition: opacity 0.2s ease;
}
.v-field-error-enter-from {
  opacity: 0;
}

@media (prefers-reduced-motion: reduce) {
  .v-field-error { animation: none; }
}
</style>
