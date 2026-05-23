<template>
  <q-page class="profile-page">
    <!-- Header -->
    <header class="pf-header">
      <button class="username-trigger" type="button">
        <span class="username">{{ profile?.nickname || user?.email || '—' }}</span>
        <ChevronDown :size="18" class="dropdown-chevron" />
      </button>
      <button class="icon-btn" type="button" @click="goSettings" aria-label="Settings">
        <Menu :size="22" />
      </button>
    </header>

    <ProfileHeaderSkeleton v-if="loadingProfile" />

    <template v-else>
      <!-- Identity row: avatar + name + handle (per-server profile) -->
      <section class="identity-row">
        <div class="pf-avatar">
          <img v-if="profile?.avatarUrl" :src="profile.avatarUrl" :alt="profile.nickname" />
          <span v-else>{{ identityInitial }}</span>
        </div>

        <div class="identity-meta">
          <div class="identity-name">{{ profile?.nickname || user?.email || '—' }}</div>
          <!-- TODO Step 3: render @{{ profile.username }} once per-server username column lands -->
        </div>
      </section>

      <p v-if="profile?.bio" class="bio">{{ profile.bio }}</p>

      <button class="edit-btn" type="button" @click="onEditProfile">
        Edit Profile
      </button>

      <!-- Tabs -->
      <div class="pf-tabs">
        <button
          v-for="t in tabs"
          :key="t.id"
          class="pf-tab"
          :class="{ active: activeTab === t.id }"
          type="button"
          @click="activeTab = t.id"
        >
          <component :is="t.icon" :size="20" />
        </button>
      </div>

      <!-- Tab content -->
      <div class="pf-content">
        <template v-if="activeTab === 'grid'">
          <PostGridSkeleton v-if="loadingPosts && posts.length === 0" />

          <div v-else-if="posts.length === 0" class="empty-grid">
            <div class="empty-icon">
              <ImageIcon :size="40" :stroke-width="1.6" />
            </div>
            <div class="empty-title">No posts yet</div>
            <p class="empty-help">Share your first post to fill up your profile grid.</p>
          </div>

          <div v-else class="post-grid">
            <button
              v-for="post in posts"
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
            <p class="empty-text">Coming soon.</p>
          </div>
        </template>
      </div>
    </template>
  </q-page>
</template>

<script setup lang="ts">
import { ref, onMounted, computed, watch } from 'vue';
import { useRouter } from 'vue-router';
import {
  ChevronDown, Menu, Image as ImageIcon,
  Grid3x3, Video, Bookmark,
} from 'lucide-vue-next';
import { storeToRefs } from 'pinia';
import { api } from 'src/boot/axios';
import { useAuthStore } from 'src/stores/auth.store';
import { useAppStore } from 'src/stores/app.store';
import ProfileHeaderSkeleton from 'src/components/feedback/skeletons/ProfileHeaderSkeleton.vue';
import PostGridSkeleton from 'src/components/feedback/skeletons/PostGridSkeleton.vue';
import { useToast } from 'src/composables/useToast';

interface ProfilePost {
  id: string;
  imageUrl: string | null;
  createdAt: string;
}

interface PaginatedResponse<T> {
  data: T[];
  page: { nextCursor: string | null; limit: number };
}

const router = useRouter();
const authStore = useAuthStore();
const appStore = useAppStore();
const toast = useToast();

const { activeServerId } = storeToRefs(appStore);

interface ServerProfileMeResponse {
  profileId: string;
  serverId: string;
  nickname: string;
  bio: string | null;
  avatarImageId: string | null;
  avatarUrl: string | null;
  createdAt: string;
  updatedAt: string;
}

const user = computed(() => authStore.user);
const profile = ref<ServerProfileMeResponse | null>(null);
const loadingProfile = ref(false);
const loadingPosts = ref(false);
const posts = ref<ProfilePost[]>([]);
const nextCursor = ref<string | null>(null);
const hasMore = ref(true);

const identityInitial = computed(() => {
  const src = profile.value?.nickname || user.value?.email || '?';
  return src.charAt(0).toUpperCase();
});

type TabId = 'grid' | 'reels' | 'saved';
const activeTab = ref<TabId>('grid');
const tabs = [
  { id: 'grid' as const, icon: Grid3x3 },
  { id: 'reels' as const, icon: Video },
  { id: 'saved' as const, icon: Bookmark },
];

onMounted(async () => {
  await loadProfile();
  if (activeServerId.value) {
    await loadPosts(true);
  }
});

watch(activeServerId, () => {
  posts.value = [];
  nextCursor.value = null;
  hasMore.value = true;
  void loadProfile();
  if (activeServerId.value) void loadPosts(true);
});

async function loadProfile() {
  const sid = activeServerId.value;
  if (!sid) {
    profile.value = null;
    return;
  }
  loadingProfile.value = true;
  try {
    const res = await api.get<ServerProfileMeResponse>(
      `/servers/${sid}/profile/me`
    );
    profile.value = res.data;
  } catch {
    profile.value = null;
    toast.error({ title: 'Failed to load profile.' });
  } finally {
    loadingProfile.value = false;
  }
}

async function loadPosts(reset: boolean) {
  if (!activeServerId.value || loadingPosts.value) return;
  loadingPosts.value = true;
  try {
    const params: Record<string, string | number> = { limit: 20 };
    if (!reset && nextCursor.value) params.cursor = nextCursor.value;
    const res = await api.get<PaginatedResponse<ProfilePost>>(
      `/servers/${activeServerId.value}/posts/me`,
      { params }
    );
    const list = res.data?.data ?? [];
    if (reset) posts.value = list;
    else posts.value.push(...list);
    nextCursor.value = res.data?.page?.nextCursor ?? null;
    hasMore.value = !!nextCursor.value;
  } catch {
    // Quiet fail; empty state handles it.
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

async function openPost(post: ProfilePost) {
  await router.push({ name: 'post-detail', params: { postId: post.id } });
}

async function goSettings() {
  await router.push({ name: 'settings' });
}

function onEditProfile() {
  void router.push({ name: 'edit-profile' });
}
</script>

<style lang="scss" scoped>
.profile-page {
  min-height: 100dvh;
  background: #fff;
  padding-bottom: 80px;
}

.pf-header {
  position: sticky;
  top: 0;
  z-index: 10;
  background: #fff;
  height: 56px;
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding: 0 12px 0 16px;
  border-bottom: 1px solid #F1F3F5;
  padding-top: env(safe-area-inset-top, 0px);
}

.username-trigger {
  background: transparent;
  border: 0;
  display: flex;
  align-items: center;
  gap: 4px;
  font-family: inherit;
  cursor: pointer;
  padding: 6px 0;
  color: #0F172A;
}

.username {
  font-size: 16px;
  font-weight: 700;
  letter-spacing: -0.01em;
}

.dropdown-chevron {
  color: #6C757D;
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

/* Identity row */
.identity-row {
  display: flex;
  align-items: center;
  gap: 16px;
  padding: 16px 24px 8px;
}

.pf-avatar {
  width: 72px;
  height: 72px;
  border-radius: 50%;
  background: #007BFF;
  color: #fff;
  font-weight: 700;
  font-size: 28px;
  display: flex;
  align-items: center;
  justify-content: center;
  flex-shrink: 0;
  overflow: hidden;

  img {
    width: 100%;
    height: 100%;
    object-fit: cover;
  }
}

.identity-meta {
  flex: 1;
  min-width: 0;
  display: flex;
  flex-direction: column;
  gap: 2px;
}

.identity-name {
  font-size: 20px;
  font-weight: 700;
  color: #0F172A;
  letter-spacing: -0.02em;
  line-height: 1.2;
}

.identity-handle {
  font-size: 14px;
  color: #6C757D;
}

.bio {
  padding: 8px 24px 0;
  margin: 0;
  font-size: 14px;
  color: #212529;
  line-height: 1.5;
  white-space: pre-line;
}

.edit-btn {
  margin: 16px 24px;
  width: calc(100% - 48px);
  background: #F1F3F5;
  border: 0;
  border-radius: 12px;
  height: 40px;
  font-family: inherit;
  font-size: 14px;
  font-weight: 600;
  color: #212529;
  cursor: pointer;

  &:hover {
    background: #E9ECEF;
  }
}

.pf-tabs {
  display: flex;
  border-top: 1px solid #F1F3F5;
  border-bottom: 1px solid #F1F3F5;
}

.pf-tab {
  flex: 1;
  background: transparent;
  border: 0;
  padding: 12px 0;
  cursor: pointer;
  color: #ADB5BD;
  display: flex;
  align-items: center;
  justify-content: center;
  position: relative;

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

.pf-content {
  min-height: 240px;
}

.empty-grid {
  display: flex;
  flex-direction: column;
  align-items: center;
  text-align: center;
  padding: 40px 24px;
}

.empty-icon {
  width: 72px;
  height: 72px;
  border-radius: 16px;
  background: #F1F3F5;
  color: #ADB5BD;
  display: flex;
  align-items: center;
  justify-content: center;
  margin-bottom: 16px;
}

.empty-title {
  font-size: 18px;
  font-weight: 700;
  color: #0F172A;
  letter-spacing: -0.01em;
}

.empty-help {
  font-size: 14px;
  color: #6C757D;
  line-height: 1.5;
  margin: 8px 0 0;
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
  padding: 48px 0;
}

.empty-text {
  color: #6C757D;
  font-size: 14px;
}
</style>
