<template>
  <div class="profile-header-skeleton" aria-hidden="true">
    <div class="phs-identity">
      <VSkeleton variant="circle" width="72px" height="72px" />
      <div class="phs-meta">
        <VSkeleton variant="text" width="52%" height="18px" />
        <VSkeleton variant="text" width="34%" height="13px" />
      </div>
    </div>

    <div class="phs-bio">
      <VSkeleton variant="text" width="88%" height="12px" />
      <VSkeleton variant="text" width="62%" height="12px" />
    </div>

    <VSkeleton variant="box" height="40px" radius="12px" class="phs-edit" />

    <div class="phs-tabs">
      <VSkeleton v-for="n in 3" :key="n" variant="box" width="22px" height="22px" radius="6px" />
    </div>
  </div>
</template>

<script setup lang="ts">
/**
 * First-load skeleton for the ProfilePage identity area: avatar + name/handle,
 * bio, edit button and the tab row. The static `.pf-header` stays rendered.
 */
import VSkeleton from '../VSkeleton.vue';
</script>

<style lang="scss" scoped>
.phs-identity {
  display: flex;
  align-items: center;
  gap: 16px;
  padding: 16px 24px 8px;
}

.phs-meta {
  flex: 1;
  min-width: 0;
  display: flex;
  flex-direction: column;
  gap: 8px;
}

.phs-bio {
  display: flex;
  flex-direction: column;
  gap: 6px;
  padding: 8px 24px 0;
}

.phs-edit {
  margin: 16px 24px;
  width: calc(100% - 48px);
}

.phs-tabs {
  display: flex;
  justify-content: space-around;
  padding: 12px 0;
  border-top: 1px solid #f1f3f5;
  border-bottom: 1px solid #f1f3f5;
}
</style>
