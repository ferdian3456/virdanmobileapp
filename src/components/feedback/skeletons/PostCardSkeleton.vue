<template>
  <article class="post-card-skeleton" aria-hidden="true">
    <header class="pcs-header">
      <VSkeleton variant="circle" width="36px" height="36px" />
      <div class="pcs-meta">
        <VSkeleton variant="text" width="38%" height="13px" />
        <VSkeleton variant="text" width="24%" height="11px" />
      </div>
    </header>

    <VSkeleton variant="box" width="100%" radius="0" class="pcs-image" />

    <div class="pcs-actions">
      <VSkeleton variant="box" width="26px" height="26px" radius="8px" />
      <VSkeleton variant="box" width="26px" height="26px" radius="8px" />
      <VSkeleton variant="box" width="26px" height="26px" radius="8px" />
    </div>

    <div class="pcs-caption">
      <VSkeleton variant="text" width="82%" height="12px" />
      <VSkeleton variant="text" width="56%" height="12px" />
    </div>
  </article>
</template>

<script setup lang="ts">
/**
 * First-load skeleton for a single feed post card. Mirrors the `.feed-card`
 * layout in HomePage (avatar + meta header, square image, action row, caption).
 * Used standalone on PostDetailPage and stacked by FeedSkeleton.
 */
import VSkeleton from '../VSkeleton.vue';
</script>

<style lang="scss" scoped>
.post-card-skeleton {
  border-bottom: 1px solid #f1f3f5;
  padding-bottom: 8px;
}

.pcs-header {
  display: flex;
  align-items: center;
  gap: 12px;
  padding: 12px 16px 8px;
}

.pcs-meta {
  flex: 1;
  min-width: 0;
  display: flex;
  flex-direction: column;
  gap: 6px;
}

.pcs-image {
  aspect-ratio: 1;
  // VSkeleton box ships a fixed 16px height; release it so aspect-ratio wins.
  height: auto;
}

.pcs-actions {
  display: flex;
  gap: 16px;
  padding: 10px 16px;
}

.pcs-caption {
  display: flex;
  flex-direction: column;
  gap: 6px;
  padding: 0 16px 12px;
}
</style>
