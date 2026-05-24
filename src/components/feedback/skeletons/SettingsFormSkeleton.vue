<template>
  <div class="settings-form-skeleton" aria-hidden="true">
    <div class="sfs-avatar-section">
      <VSkeleton variant="circle" width="96px" height="96px" />
      <VSkeleton variant="text" width="140px" height="13px" class="sfs-link" />
    </div>

    <div v-for="n in rows" :key="n" class="sfs-row">
      <VSkeleton variant="text" width="32%" height="11px" />
      <VSkeleton variant="box" :height="n === 2 ? '88px' : '44px'" radius="8px" />
    </div>
  </div>
</template>

<script setup lang="ts">
/**
 * First-load skeleton for the edit-form pages (EditProfilePage,
 * EditServerSettingsPage): centered avatar + change link, then stacked
 * label + input rows. Row 2 is taller to stand in for a textarea field.
 */
import VSkeleton from '../VSkeleton.vue';

withDefaults(defineProps<{ rows?: number }>(), { rows: 5 });
</script>

<style lang="scss" scoped>
.sfs-avatar-section {
  padding: 24px 0 16px;
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 12px;
}

.sfs-row {
  display: flex;
  flex-direction: column;
  gap: 8px;
  padding: 8px 24px;
}
</style>
