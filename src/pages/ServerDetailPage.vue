<template>
  <q-page class="server-detail-page">
    <!-- Top bar -->
    <header class="sd-header">
      <button class="icon-btn" type="button" @click="goBack">
        <ChevronLeft :size="24" />
      </button>
      <h1 class="sd-title">{{ server?.name ?? 'Server' }}</h1>
      <button
        v-if="isOwner"
        class="icon-btn"
        type="button"
        @click="openSettings"
        aria-label="Server settings"
      >
        <Settings :size="22" />
      </button>
      <span v-else class="sd-spacer"></span>
    </header>

    <ServerHeaderSkeleton v-if="loadingServer" />

    <template v-else-if="server">
      <!-- Banner + avatar -->
      <div class="sd-banner-wrap">
        <div class="sd-banner" :style="bannerStyle"></div>
        <div class="sd-avatar-row">
          <div class="sd-avatar">
            <img v-if="server.avatarUrl" :src="server.avatarUrl" alt="" />
            <span v-else>{{ server.shortName?.charAt(0).toUpperCase() }}</span>
          </div>
        </div>
      </div>

      <!-- Server info -->
      <div class="sd-info">
        <h2 class="sd-name">{{ server.name }}</h2>
        <div class="sd-meta">
          <span class="sd-shortname">@{{ server.shortName }}</span>
          <span class="sd-divider">·</span>
          <span>{{ server.categoryName ?? 'Uncategorized' }}</span>
        </div>
        <p v-if="server.description" class="sd-description">{{ server.description }}</p>
      </div>

      <!-- Tabs -->
      <div class="sd-tabs">
        <button
          v-for="t in tabs"
          :key="t.id"
          type="button"
          class="sd-tab"
          :class="{ active: activeTab === t.id }"
          @click="activeTab = t.id"
        >
          {{ t.label }}
        </button>
      </div>

      <!-- Tab content -->
      <div class="sd-content">
        <template v-if="activeTab === 'posts'">
          <PostGridSkeleton v-if="loadingPosts && posts.length === 0" />
          <div v-else-if="posts.length === 0" class="state-block">
            <p class="empty-text">No posts in this server yet.</p>
          </div>

          <div v-else class="post-grid">
            <button
              v-for="post in posts"
              :key="post.postId"
              class="post-tile"
              type="button"
              @click="openPost(post)"
            >
              <img :src="post.postImageUrl" :alt="post.caption" />
            </button>
          </div>

          <q-infinite-scroll
            v-if="hasMore"
            :disable="loadingPosts || !hasMore"
            @load="loadMore"
          >
            <template #loading>
              <div class="state-block">
                <q-spinner-dots color="primary" size="32px" />
              </div>
            </template>
          </q-infinite-scroll>
        </template>

        <template v-else>
          <div class="state-block">
            <p class="empty-text">Members view coming soon.</p>
          </div>
        </template>
      </div>
    </template>

    <div v-else class="state-block">
      <p class="empty-text">Server not found.</p>
    </div>
  </q-page>
</template>

<script setup lang="ts">
import { ref, computed, onMounted } from 'vue';
import { useRouter } from 'vue-router';
import { ChevronLeft, Settings } from 'lucide-vue-next';
import { api } from 'src/boot/axios';
import { useAuthStore } from 'src/stores/auth.store';
import { useToast } from 'src/composables/useToast';
import { apiErrorToast } from 'src/composables/useApiError';
import ServerHeaderSkeleton from 'src/components/feedback/skeletons/ServerHeaderSkeleton.vue';
import PostGridSkeleton from 'src/components/feedback/skeletons/PostGridSkeleton.vue';

interface ServerDetail {
  id: string;
  name: string;
  shortName: string;
  categoryName: string | null;
  avatarUrl: string | null;
  bannerUrl: string | null;
  description: string | null;
  createdAt: string;
  createdBy?: string;
}

interface PostItem {
  postId: string;
  ownerId: string;
  ownerName: string;
  ownerImageUrl: string | null;
  postImageUrl: string;
  caption: string;
  likeCount: number;
  commentCount: number;
  isLiked: boolean;
  createdAt: string;
}

interface PaginatedResponse<T> {
  data: T[];
  page: { nextCursor: string | null; limit: number };
}

const props = defineProps<{ id: string }>();

const router = useRouter();
const authStore = useAuthStore();
const toast = useToast();

const server = ref<ServerDetail | null>(null);
const posts = ref<PostItem[]>([]);
const activeTab = ref<'posts' | 'members'>('posts');
const loadingServer = ref(false);
const loadingPosts = ref(false);
const nextCursor = ref<string | null>(null);
const hasMore = ref(true);

const tabs = [
  { id: 'posts' as const, label: 'Posts' },
  { id: 'members' as const, label: 'Members' },
];

const isOwner = computed(
  () => !!server.value?.createdBy && server.value.createdBy === authStore.user?.id
);

const bannerStyle = computed(() => {
  if (server.value?.bannerUrl) {
    return { backgroundImage: `url(${server.value.bannerUrl})` };
  }
  return { background: 'linear-gradient(135deg, #007BFF, #007BFF)' };
});

onMounted(async () => {
  await Promise.all([loadServer(), loadPosts(true)]);
});

async function loadServer() {
  loadingServer.value = true;
  try {
    const res = await api.get<ServerDetail>(`/servers/${props.id}`);
    server.value = res.data;
  } catch (err) {
    toast.error(apiErrorToast(err, () => void loadServer()));
  } finally {
    loadingServer.value = false;
  }
}

async function loadPosts(reset: boolean) {
  if (loadingPosts.value) return;
  loadingPosts.value = true;
  try {
    const params: Record<string, string | number> = { limit: 12 };
    if (!reset && nextCursor.value) params.cursor = nextCursor.value;
    const res = await api.get<PaginatedResponse<PostItem>>(
      `/servers/${props.id}/posts`,
      { params }
    );
    const list = res.data?.data ?? [];
    if (reset) posts.value = list;
    else posts.value.push(...list);
    nextCursor.value = res.data?.page?.nextCursor ?? null;
    hasMore.value = !!nextCursor.value;
  } catch {
    // Quiet fail — empty state shown instead.
  } finally {
    loadingPosts.value = false;
  }
}

async function loadMore(_idx: number, done: (stop?: boolean) => void) {
  if (!hasMore.value) {
    done(true);
    return;
  }
  await loadPosts(false);
  done(!hasMore.value);
}

async function openPost(post: PostItem) {
  await router.push({ name: 'post-detail', params: { postId: post.postId } });
}

async function openSettings() {
  await router.push({ name: 'server-settings', params: { id: props.id } });
}

function goBack() {
  if (window.history.length > 1) {
    router.back();
  } else {
    void router.push({ name: 'home' });
  }
}
</script>

<style lang="scss" scoped>
.server-detail-page {
  min-height: 100dvh;
  background: #fff;
  padding-bottom: 88px; /* clear bottom tab nav */
}

.sd-header {
  position: sticky;
  top: 0;
  z-index: 10;
  background: rgba(255, 255, 255, 0.95);
  backdrop-filter: blur(8px);
  height: 56px;
  display: flex;
  align-items: center;
  padding: 0 12px;
  border-bottom: 1px solid #F1F3F5;
  padding-top: env(safe-area-inset-top, 0px);
}

.icon-btn {
  width: 40px;
  height: 40px;
  border-radius: 50%;
  border: 0;
  background: transparent;
  display: flex;
  align-items: center;
  justify-content: center;
  cursor: pointer;
  color: #212529;

  &:hover {
    background: #F1F3F5;
  }
}

.sd-title {
  flex: 1;
  text-align: center;
  font-size: 17px;
  font-weight: 600;
  letter-spacing: -0.01em;
  margin: 0;
  color: #212529;
}

.sd-spacer {
  width: 40px;
  height: 40px;
}

.sd-banner-wrap {
  position: relative;
  margin-bottom: 56px;
}

.sd-banner {
  width: 100%;
  height: 140px;
  background-size: cover;
  background-position: center;
  background-color: #007BFF;
}

.sd-avatar-row {
  position: absolute;
  left: 20px;
  bottom: -40px;
}

.sd-avatar {
  width: 88px;
  height: 88px;
  border-radius: 22px;
  border: 4px solid #fff;
  background: #007BFF;
  color: #fff;
  font-size: 34px;
  font-weight: 800;
  letter-spacing: -0.02em;
  display: flex;
  align-items: center;
  justify-content: center;
  overflow: hidden;

  img {
    width: 100%;
    height: 100%;
    object-fit: cover;
  }
}

.sd-info {
  padding: 0 20px 20px;
}

.sd-name {
  font-size: 22px;
  font-weight: 700;
  letter-spacing: -0.02em;
  margin: 0;
  color: #0F172A;
}

.sd-meta {
  display: flex;
  gap: 6px;
  align-items: center;
  font-size: 13px;
  color: #6C757D;
  margin-top: 4px;
}

.sd-divider {
  color: #DEE2E6;
}

.sd-shortname {
  font-weight: 500;
}

.sd-description {
  margin: 12px 0 0;
  font-size: 14px;
  line-height: 1.5;
  color: #495057;
}

.sd-tabs {
  display: flex;
  border-top: 1px solid #F1F3F5;
  border-bottom: 1px solid #F1F3F5;
}

.sd-tab {
  flex: 1;
  background: transparent;
  border: 0;
  font-family: inherit;
  font-size: 14px;
  font-weight: 600;
  color: #6C757D;
  padding: 14px 0;
  position: relative;
  cursor: pointer;

  &.active {
    color: #212529;

    &::after {
      content: '';
      position: absolute;
      left: 50%;
      bottom: -1px;
      transform: translateX(-50%);
      width: 32px;
      height: 2px;
      background: #007BFF;
      border-radius: 2px;
    }
  }
}

.sd-content {
  min-height: 240px;
}

.post-grid {
  display: grid;
  grid-template-columns: repeat(3, 1fr);
  gap: 2px;
}

.post-tile {
  position: relative;
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
  padding: 48px 0;
}

.empty-text {
  color: #6C757D;
  font-size: 14px;
}
</style>
