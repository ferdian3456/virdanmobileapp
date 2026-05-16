<template>
  <div class="v-input-wrapper">
    <q-input
      v-bind="$attrs"
      :model-value="modelValue"
      @update:model-value="val => $emit('update:modelValue', val)"
      outlined
      bg-color="white"
      class="v-input"
      :label="label"
      hide-bottom-space
    >
      <!-- Forward all slots to q-input -->
      <template v-for="(_, name) in $slots" v-slot:[name]="slotProps">
        <slot :name="name" v-bind="slotProps || {}" />
      </template>
    </q-input>
  </div>
</template>

<script setup lang="ts">
/**
 * Reusable Virdan Input Component
 * Standardizes the 12px border radius and 52px height
 */
defineProps<{
  modelValue: string | number | null | undefined;
  label?: string;
}>();

defineEmits<{
  (e: 'update:modelValue', value: string | number | null | undefined): void;
}>();

// Inherit attributes like type, error, etc.
defineOptions({
  inheritAttrs: false
});
</script>

<style lang="scss">
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

  &.q-field--focused, &.q-field--float {
    .q-field__label {
      color: var(--q-primary);
    }
  }
}
</style>
