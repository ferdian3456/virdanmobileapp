<template>
  <q-btn
    v-bind="$attrs"
    unelevated
    no-caps
    class="v-button text-weight-bold"
  >
    <slot />
    <!-- Forward all slots just in case, though q-btn handles default slot -->
    <template v-for="(_, name) in $slots" v-slot:[name]="slotProps">
      <slot :name="name" v-bind="slotProps || {}" />
    </template>
  </q-btn>
</template>

<script setup lang="ts">
/**
 * Reusable Virdan Button Component
 * Standardizes the 12px border radius and 48px height
 */
defineOptions({
  inheritAttrs: false
});
</script>

<style lang="scss">
.v-button {
  border-radius: 14px !important;
  min-height: 48px;
  font-weight: 600;
  letter-spacing: -0.01em;
}
</style>
