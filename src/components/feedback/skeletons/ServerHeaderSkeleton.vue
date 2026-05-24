<template>
  <div class="server-header-skeleton" aria-hidden="true">
    <div class="shs-banner-wrap">
      <VSkeleton variant="box" width="100%" height="140px" radius="0" />
      <VSkeleton variant="box" width="88px" height="88px" radius="22px" class="shs-avatar" />
    </div>

    <div class="shs-info">
      <VSkeleton variant="text" width="56%" height="20px" />
      <VSkeleton variant="text" width="40%" height="12px" />
      <VSkeleton variant="text" width="92%" height="12px" class="shs-desc" />
      <VSkeleton variant="text" width="70%" height="12px" />
    </div>

    <div class="shs-tabs">
      <VSkeleton v-for="n in 2" :key="n" variant="text" width="64px" height="13px" />
    </div>
  </div>
</template>

<script setup lang="ts">
/**
 * First-load skeleton for ServerDetailPage: banner + overlapping avatar, server
 * name/meta/description and the tab row. The static `.sd-header` stays rendered.
 */
import VSkeleton from '../VSkeleton.vue';
</script>

<style lang="scss" scoped>
.shs-banner-wrap {
  position: relative;
  margin-bottom: 56px;
}

.shs-avatar {
  position: absolute;
  left: 20px;
  bottom: -40px;
  border: 4px solid #fff;
}

.shs-info {
  display: flex;
  flex-direction: column;
  gap: 8px;
  padding: 0 20px 20px;
}

.shs-desc {
  margin-top: 4px;
}

.shs-tabs {
  display: flex;
  gap: 28px;
  padding: 14px 20px;
  border-top: 1px solid #f1f3f5;
  border-bottom: 1px solid #f1f3f5;
}
</style>
