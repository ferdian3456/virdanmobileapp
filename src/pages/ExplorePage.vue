<template>
  <q-page class="explore-page">
    <!-- Search bar -->
    <div class="search-wrap">
      <Search :size="18" class="search-icon" />
      <input
        v-model="searchQuery"
        type="search"
        placeholder="Search people, tags, places…"
        class="search-input"
      />
    </div>

    <!-- Loading -->
    <PostGridSkeleton v-if="loading && posts.length === 0" />

    <!-- Empty state -->
    <div v-else-if="filteredPosts.length === 0" class="empty-section">
      <img src="/assets/illustrator/social.svg" alt="" style="width: 240px" class="empty-illustration" />
      <div class="empty-title">No posts yet</div>
      <p class="empty-help">Be the first to share something in your servers.</p>
      <button class="empty-cta" type="button" @click="goCreatePost">Create a Post</button>
    </div>

    <!-- Post grid -->
    <div v-else class="post-grid">
      <button
        v-for="post in filteredPosts"
        :key="post.id"
        class="post-tile"
        type="button"
        @click="openPost(post)"
      >
        <img v-if="post.imageUrl" :src="post.imageUrl" alt="" />
      </button>
    </div>

    <q-infinite-scroll
      v-if="hasMore"
      :disable="loading || !hasMore"
      @load="loadMore"
    >
      <template #loading>
        <div class="state-block">
          <q-spinner-dots color="primary" size="32px" />
        </div>
      </template>
    </q-infinite-scroll>
  </q-page>
</template>

<script setup lang="ts">
import { ref, computed, onMounted } from 'vue';
import { useRouter } from 'vue-router';
import { Search } from 'lucide-vue-next';
import { storeToRefs } from 'pinia';
import { api } from 'src/boot/axios';
import { useAppStore } from 'src/stores/app.store';
import PostGridSkeleton from 'src/components/feedback/skeletons/PostGridSkeleton.vue';

interface ExplorePostAuthor {
  userId: string;
  nickname: string;
  avatarUrl: string | null;
  status: string;
}

interface ExplorePost {
  id: string;
  author: ExplorePostAuthor;
  imageUrl: string | null;
  caption: string;
  likeCount: number;
  commentCount: number;
  createdAt: string;
}

interface PaginatedResponse<T> {
  data: T[];
  page: { nextCursor: string | null; limit: number };
}

const router = useRouter();
const appStore = useAppStore();
const { servers } = storeToRefs(appStore);

const posts = ref<ExplorePost[]>([]);
const searchQuery = ref('');
const loading = ref(false);
const currentServerIdx = ref(0);
const nextCursor = ref<string | null>(null);
const hasMore = ref(true);

const filteredPosts = computed(() => {
  const q = searchQuery.value.trim().toLowerCase();
  if (!q) return posts.value;
  return posts.value.filter(
    (p) =>
      p.author.nickname.toLowerCase().includes(q) ||
      p.caption.toLowerCase().includes(q)
  );
});

onMounted(async () => {
  // Make sure server list is hydrated.
  if (!appStore.isInitialized) {
    try {
      await appStore.fetchMyServers();
    } catch {
      // Continue anyway — page shows empty state.
    }
  }
  await loadFromCurrentServer();
});

async function loadFromCurrentServer() {
  if (loading.value) return;
  if (currentServerIdx.value >= servers.value.length) {
    hasMore.value = false;
    return;
  }

  loading.value = true;
  try {
    const serverId = servers.value[currentServerIdx.value]?.id;
    if (!serverId) {
      hasMore.value = false;
      return;
    }
    const params: Record<string, string | number> = { limit: 20 };
    if (nextCursor.value) params.cursor = nextCursor.value;
    const res = await api.get<PaginatedResponse<ExplorePost>>(
      `/servers/${serverId}/posts`,
      { params }
    );
    const list = res.data?.data ?? [];
    posts.value.push(...list);
    nextCursor.value = res.data?.page?.nextCursor ?? null;

    if (!nextCursor.value) {
      // Move to next server in the list.
      currentServerIdx.value += 1;
      hasMore.value = currentServerIdx.value < servers.value.length;
    } else {
      hasMore.value = true;
    }
  } catch {
    hasMore.value = false;
  } finally {
    loading.value = false;
  }
}

async function loadMore(_idx: number, done: (stop?: boolean) => void) {
  if (!hasMore.value) {
    done(true);
    return;
  }
  await loadFromCurrentServer();
  done(!hasMore.value);
}

async function openPost(post: ExplorePost) {
  await router.push({ name: 'post-detail', params: { postId: post.id } });
}

async function goCreatePost() {
  await router.push({ name: 'create-post' });
}
</script>

<style lang="scss" scoped>
.explore-page {
  min-height: 100dvh;
  background: #fff;
  padding-top: env(safe-area-inset-top, 0px);
  display: flex;
  flex-direction: column;
}

.search-wrap {
  margin: 12px 16px;
  position: relative;
}

.search-icon {
  position: absolute;
  left: 14px;
  top: 50%;
  transform: translateY(-50%);
  color: #ADB5BD;
}

.search-input {
  width: 100%;
  height: 40px;
  padding: 0 14px 0 40px;
  border: 0;
  background: #F1F3F5;
  border-radius: 12px;
  font-family: inherit;
  font-size: 14px;
  outline: none;
  color: #212529;

  &:focus {
    background: #fff;
    box-shadow: 0 0 0 1px #007BFF;
  }

  &::placeholder {
    color: #ADB5BD;
  }
}

.empty-section {
  flex: 1;
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  text-align: center;
  padding: 24px 24px 160px; /* extra bottom padding pushes cluster upward */
}

.empty-illustration {
  margin: 24px 0;
}

.empty-title {
  font-size: 18px;
  font-weight: 700;
  color: #0F172A;
}

.empty-help {
  font-size: 14px;
  color: #6C757D;
  line-height: 1.5;
  margin: 8px 0 24px;
  max-width: 280px;
}

.empty-cta {
  background: #007BFF;
  color: #fff;
  border: 0;
  border-radius: 14px;
  height: 48px;
  padding: 0 32px;
  font-family: inherit;
  font-size: 15px;
  font-weight: 600;
  cursor: pointer;
  width: 90%;
  max-width: 320px;

  &:hover {
    background: #0056CC;
  }
}

.post-grid {
  display: grid;
  grid-template-columns: repeat(3, 1fr);
  gap: 2px;
}

.post-tile {
  aspect-ratio: 1;
  background: #F1F3F5;
  border: 0;
  padding: 0;
  cursor: pointer;
  overflow: hidden;

  img {
    width: 100%;
    height: 100%;
    object-fit: cover;
  }
}

.state-block {
  display: flex;
  align-items: center;
  justify-content: center;
  padding: 32px 0;
}
</style>
