<template>
  <div class="feed-skeleton" aria-hidden="true">
    <PostCardSkeleton v-for="n in count" :key="n" />
  </div>
</template>

<script setup lang="ts">
/**
 * First-load skeleton for the HomePage feed: a stack of post card skeletons.
 */
import PostCardSkeleton from './PostCardSkeleton.vue';

withDefaults(defineProps<{ count?: number }>(), { count: 3 });
</script>

<style lang="scss" scoped>
.feed-skeleton {
  background: #fff;
}
</style>
