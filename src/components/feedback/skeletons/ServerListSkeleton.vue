<template>
  <div class="server-list-skeleton" aria-hidden="true">
    <div v-for="n in count" :key="n" class="sls-row">
      <VSkeleton variant="circle" width="44px" height="44px" />
      <div class="sls-meta">
        <VSkeleton variant="text" width="42%" height="14px" />
        <VSkeleton variant="text" width="78%" height="12px" />
        <VSkeleton variant="text" width="48%" height="11px" />
      </div>
      <VSkeleton variant="box" width="64px" height="32px" radius="999px" />
    </div>
  </div>
</template>

<script setup lang="ts">
/**
 * First-load skeleton for the discovery server list (Onboarding + Explore
 * Servers). Mirrors the `.server-row` layout: circle avatar, three text
 * lines, a pill join button.
 */
import VSkeleton from '../VSkeleton.vue';

withDefaults(defineProps<{ count?: number }>(), { count: 5 });
</script>

<style lang="scss" scoped>
.sls-row {
  display: flex;
  align-items: center;
  gap: 12px;
  padding: 12px 0;
  border-bottom: 1px solid #f1f3f5;

  &:last-child {
    border-bottom: 0;
  }
}

.sls-meta {
  flex: 1;
  min-width: 0;
  display: flex;
  flex-direction: column;
  gap: 6px;
}
</style>
