<template>
  <div class="post-grid-skeleton" aria-hidden="true">
    <VSkeleton
      v-for="n in count"
      :key="n"
      variant="box"
      width="100%"
      radius="0"
      class="pgs-tile"
    />
  </div>
</template>

<script setup lang="ts">
/**
 * First-load skeleton for the 3-column post grid. Mirrors `.post-grid` /
 * `.post-tile` used by ExplorePage, ProfilePage and ServerDetailPage.
 */
import VSkeleton from '../VSkeleton.vue';

withDefaults(defineProps<{ count?: number }>(), { count: 9 });
</script>

<style lang="scss" scoped>
.post-grid-skeleton {
  display: grid;
  grid-template-columns: repeat(3, 1fr);
  gap: 2px;
}

.pgs-tile {
  aspect-ratio: 1;
}
</style>
