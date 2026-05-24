<template>
  <div class="comment-list-skeleton" aria-hidden="true">
    <div v-for="n in count" :key="n" class="cls-row">
      <VSkeleton variant="circle" width="36px" height="36px" />
      <div class="cls-body">
        <VSkeleton variant="text" width="86%" height="13px" />
        <VSkeleton variant="text" width="48%" height="13px" />
        <VSkeleton variant="text" width="30%" height="10px" class="cls-line2" />
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">
/**
 * First-load skeleton for the CommentsPage list. Mirrors the `.cm-row` layout
 * of CommentNode: circle avatar + two content lines + a meta line.
 */
import VSkeleton from '../VSkeleton.vue';

withDefaults(defineProps<{ count?: number }>(), { count: 6 });
</script>

<style lang="scss" scoped>
.cls-row {
  display: flex;
  gap: 12px;
  align-items: flex-start;
  padding: 10px 16px;
}

.cls-body {
  flex: 1;
  min-width: 0;
  display: flex;
  flex-direction: column;
  gap: 6px;
}

.cls-line2 {
  margin-top: 2px;
}
</style>
