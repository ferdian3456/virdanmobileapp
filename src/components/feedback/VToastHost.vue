<template>
  <teleport to="body">
    <div class="v-toast-host">
      <transition-group name="v-toast-list">
        <VToast
          v-for="item in toasts"
          :key="item.id"
          :toast="item"
          @dismiss="dismiss(item.id)"
        />
      </transition-group>
    </div>
  </teleport>
</template>

<script setup lang="ts">
/**
 * Single global toast outlet. Mount once at the app root; it teleports the
 * stack to <body> so toasts always render above pages, sheets and dialogs.
 */
import { useToastQueue } from 'src/composables/useToast';
import VToast from './VToast.vue';

const { toasts, dismiss } = useToastQueue();
</script>

<style lang="scss">
.v-toast-host {
  position: fixed;
  top: calc(var(--safe-top, 0px) + 70px);
  left: 0;
  right: 0;
  z-index: 7000;
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 10px;
  padding: 0 16px;
  // Let touches pass through the gaps; each toast re-enables its own events.
  pointer-events: none;
}

.v-toast-list-enter-active,
.v-toast-list-leave-active,
.v-toast-list-move {
  transition: opacity 0.22s ease, transform 0.22s ease;
}

.v-toast-list-enter-from,
.v-toast-list-leave-to {
  opacity: 0;
  transform: translateY(-12px);
}

@media (prefers-reduced-motion: reduce) {
  .v-toast-list-enter-active,
  .v-toast-list-leave-active {
    transition: opacity 0.22s ease;
  }
  .v-toast-list-enter-from,
  .v-toast-list-leave-to {
    transform: none;
  }
}
</style>
