<template>
  <q-page class="bg-grey-1 home-page">
    <!-- Loading servers -->
    <FeedSkeleton v-if="loadingServers" />

    <!-- No servers state — fallback (guard normally redirects to onboarding) -->
    <div
      v-else-if="servers.length === 0"
      class="empty-servers"
    >
      <img src="/assets/illustrator/community.svg" alt="" style="width: 240px" class="q-mb-lg" />
      <div class="empty-title">No servers yet</div>
      <p class="empty-help">
        Join a community or create your own to start seeing posts here.
      </p>
      <VButton
        color="primary"
        unelevated
        class="full-width q-mt-lg"
        label="Explore Servers"
        @click="goExploreServers"
      />
      <VButton
        outline
        color="primary"
        class="full-width q-mt-md bg-white"
        label="Create a Server"
        @click="goCreateServer"
      />
    </div>

    <!-- Active server feed -->
    <template v-else>
      <!-- Header -->
      <header class="home-header">
        <div
          class="server-dropdown-trigger"
          role="button"
          tabindex="0"
          aria-haspopup="true"
        >
          <span class="server-name">{{ activeServer?.name?.toUpperCase() ?? 'SELECT SERVER' }}</span>
          <ChevronDown :size="20" class="dropdown-chevron" />

          <q-menu
            anchor="bottom left"
            self="top left"
            class="server-menu"
          >
            <q-list class="server-menu-list">
              <q-item
                v-for="srv in servers"
                :key="srv.id"
                clickable
                v-close-popup
                :active="activeServerId === srv.id"
                active-class="server-menu-item-active"
                @click="switchServer(srv.id)"
              >
                <q-item-section>{{ srv.name }}</q-item-section>
                <q-item-section v-if="activeServerId === srv.id" side>
                  <Check :size="18" class="text-primary" />
                </q-item-section>
              </q-item>

              <q-separator spaced />

              <q-item clickable v-close-popup @click="goCreateServer">
                <q-item-section avatar>
                  <span class="menu-icon menu-icon-primary">
                    <Plus :size="18" />
                  </span>
                </q-item-section>
                <q-item-section class="text-primary text-weight-medium">
                  Create a server
                </q-item-section>
              </q-item>

              <q-item clickable v-close-popup @click="goExploreServers">
                <q-item-section avatar>
                  <span class="menu-icon menu-icon-soft">
                    <Compass :size="18" />
                  </span>
                </q-item-section>
                <q-item-section class="text-grey-8 text-weight-medium">
                  Explore servers
                </q-item-section>
              </q-item>
            </q-list>
          </q-menu>
        </div>

        <button class="header-icon-btn" type="button" aria-label="Messages" @click="goMessages">
          <Send :size="22" :stroke-width="2" />
        </button>
      </header>

      <!-- Empty feed state — kept OUTSIDE q-pull-to-refresh so the
           "Create a Post" tap event isn't swallowed by the gesture overlay. -->
      <div
        v-if="posts.length === 0 && !loadingPosts"
        class="empty-feed"
      >
        <img src="/assets/illustrator/posting_photo.svg" alt="" style="width: 320px" class="q-mt-xl q-mb-lg" />
        <div class="empty-title">No posts yet</div>
        <p class="empty-help">Be the first to share something in this server.</p>
        <VButton
          color="primary"
          unelevated
          label="Create a Post"
          class="empty-cta"
          @click="goCreatePost"
        />
      </div>

      <!-- Pull-to-refresh feed (only when posts exist) -->
      <q-pull-to-refresh v-else @refresh="onRefresh">
        <div class="feed">
          <article
            v-for="post in posts"
            :key="post.id"
            class="feed-card"
          >
            <header class="feed-card-header">
              <div class="feed-avatar">
                <img v-if="post.author.avatarUrl" :src="post.author.avatarUrl" :alt="post.author.nickname" />
                <span v-else>{{ post.author.nickname.charAt(0).toUpperCase() }}</span>
              </div>
              <div class="feed-meta">
                <div class="feed-username">{{ post.author.nickname }}</div>
                <div class="feed-time">{{ formatDate(post.createdAt) }}</div>
              </div>
              <button class="header-icon-btn" type="button" aria-label="More">
                <MoreHorizontal :size="20" />
              </button>
            </header>

            <div class="feed-image-wrap">
              <img v-if="post.imageUrl" :src="post.imageUrl" :alt="post.caption" class="feed-image" />
            </div>

            <div class="feed-actions">
              <div class="feed-actions-left">
                <button
                  class="feed-action-btn"
                  :class="{ 'feed-action-with-count': post.likeCount > 0 }"
                  type="button"
                  aria-label="Like"
                  @click="toggleLike(post)"
                >
                  <Heart
                    :size="24"
                    :stroke-width="post.liked ? 0 : 2"
                    :class="post.liked ? 'icon-liked' : ''"
                  />
                  <span v-if="post.likeCount > 0" class="action-count">{{ post.likeCount }}</span>
                </button>
                <button
                  class="feed-action-btn"
                  :class="{ 'feed-action-with-count': post.commentCount > 0 }"
                  type="button"
                  aria-label="Comment"
                  @click="openComments(post)"
                >
                  <MessageCircle :size="24" :stroke-width="2" />
                  <span v-if="post.commentCount > 0" class="action-count">{{ post.commentCount }}</span>
                </button>
                <button class="feed-action-btn" type="button" aria-label="Share">
                  <Send :size="24" :stroke-width="2" />
                </button>
              </div>
              <button class="feed-action-btn" type="button" aria-label="Save">
                <Bookmark :size="22" :stroke-width="2" />
              </button>
            </div>

            <div class="feed-caption">
              <span class="caption-username">{{ post.author.nickname }}</span>
              {{ post.caption }}
            </div>
          </article>

          <q-infinite-scroll
            v-if="hasMore"
            :disable="loadingPosts || !hasMore"
            @load="onLoadMore"
          >
            <template #loading>
              <div class="state-block">
                <q-spinner-dots color="primary" size="32px" />
              </div>
            </template>
          </q-infinite-scroll>
          <div class="bottom-spacer"></div>
        </div>
      </q-pull-to-refresh>
    </template>
  </q-page>
</template>

<script setup lang="ts">
import { ref, onMounted } from 'vue';
import { useRouter } from 'vue-router';
import { storeToRefs } from 'pinia';
import {
  ChevronDown, Check, Plus, Compass, Send,
  MoreHorizontal, Heart, MessageCircle, Bookmark,
} from 'lucide-vue-next';
import { api } from 'boot/axios';
import { useAppStore } from 'stores/app.store';
import VButton from 'src/components/VButton.vue';
import FeedSkeleton from 'src/components/feedback/skeletons/FeedSkeleton.vue';

interface PostAuthor {
  userId: string;
  nickname: string;
  avatarUrl: string | null;
  status: string;
}

interface Post {
  id: string;
  serverId: string;
  author: PostAuthor;
  imageUrl: string | null;
  caption: string;
  likeCount: number;
  commentCount: number;
  userLiked: boolean;
  isOwner: boolean;
  liked?: boolean;
  createdAt: string;
  updatedAt: string;
}

interface PostsResponse {
  data: Post[];
  page: { nextCursor: string | null; limit: number };
}

const router = useRouter();
const appStore = useAppStore();
const { activeServerId, servers, activeServer } = storeToRefs(appStore);

const posts = ref<Post[]>([]);
const nextCursor = ref<string | null>(null);
const hasMore = ref(true);
const loadingServers = ref(true);
const loadingPosts = ref(false);

onMounted(async () => {
  await loadServers();
});

async function loadServers() {
  loadingServers.value = true;
  try {
    await appStore.fetchMyServers();
    if (activeServerId.value) {
      await loadPosts();
    }
  } catch (error) {
    console.error('Failed to load servers:', error);
  } finally {
    loadingServers.value = false;
  }
}

async function switchServer(serverId: string) {
  appStore.setActiveServer(serverId);
  posts.value = [];
  nextCursor.value = null;
  hasMore.value = true;
  await loadPosts();
}

async function loadPosts(cursor: string | null = null) {
  if (loadingPosts.value || !activeServerId.value) return;
  loadingPosts.value = true;
  try {
    const params: Record<string, string | number> = { limit: 12 };
    if (cursor) params.cursor = cursor;
    const res = await api.get<PostsResponse>(
      `/servers/${activeServerId.value}/posts`,
      { params }
    );
    const newPosts = (res.data?.data ?? []).map((p) => ({ ...p, liked: !!p.userLiked }));
    if (cursor) posts.value.push(...newPosts);
    else posts.value = newPosts;
    nextCursor.value = res.data?.page?.nextCursor ?? null;
    hasMore.value = !!nextCursor.value;
  } catch (error) {
    console.error('Failed to load posts:', error);
  } finally {
    loadingPosts.value = false;
  }
}

async function onRefresh(done: () => void) {
  nextCursor.value = null;
  hasMore.value = true;
  await loadPosts();
  done();
}

async function onLoadMore(_idx: number, done: (stop?: boolean) => void) {
  if (!hasMore.value) {
    done(true);
    return;
  }
  await loadPosts(nextCursor.value);
  done(!hasMore.value);
}

async function toggleLike(post: Post) {
  const wasLiked = !!post.liked;
  // Optimistic UI
  post.liked = !wasLiked;
  post.likeCount = Math.max(0, post.likeCount + (wasLiked ? -1 : 1));

  try {
    const url = `/posts/${post.id}/likes`;
    const res = wasLiked
      ? await api.delete<{ likeCount: number }>(url)
      : await api.post<{ likeCount: number }>(url, {});
    post.likeCount = res.data.likeCount;
  } catch {
    // Revert
    post.liked = wasLiked;
    post.likeCount = Math.max(0, post.likeCount + (wasLiked ? 1 : -1));
  }
}

async function openComments(post: Post) {
  await router.push({ name: 'comments', params: { postId: post.id } });
}

async function goCreatePost() {
  await router.push({ name: 'create-post' });
}

async function goCreateServer() {
  await router.push({ name: 'create-server' });
}

async function goExploreServers() {
  await router.push({ name: 'explore-servers' });
}

async function goMessages() {
  await router.push({ name: 'messages' });
}

function formatDate(dateStr: string): string {
  const d = new Date(dateStr);
  const now = Date.now();
  const diffSec = Math.floor((now - d.getTime()) / 1000);
  if (diffSec < 60) return 'Just now';
  const diffMin = Math.floor(diffSec / 60);
  if (diffMin < 60) return `${diffMin}m`;
  const diffHr = Math.floor(diffMin / 60);
  if (diffHr < 24) return `${diffHr}h`;
  const diffDay = Math.floor(diffHr / 24);
  if (diffDay < 7) return `${diffDay}d`;
  return d.toLocaleDateString(undefined, { month: 'short', day: 'numeric' });
}
</script>

<style lang="scss" scoped>
.home-page {
  min-height: 100dvh;
  display: flex;
  flex-direction: column;
}

/* States */
.state-block {
  display: flex;
  align-items: center;
  justify-content: center;
  padding: 48px 0;
}

.empty-servers,
.empty-feed {
  flex: 1;
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  text-align: center;
  padding: 24px 24px 160px; /* extra bottom padding pushes cluster upward */
}

.empty-title {
  font-size: 18px;
  font-weight: 700;
  letter-spacing: -0.02em;
  color: #0F172A;
}

.empty-help {
  font-size: 14px;
  color: #6C757D;
  line-height: 1.5;
  margin: 8px 0 0;
  max-width: 280px;
}

.empty-cta {
  margin-top: 24px;
  width: 90%;
  max-width: 320px;
}

/* Header */
.home-header {
  position: sticky;
  top: 0;
  z-index: 10;
  background: #fff;
  height: 56px;
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding: 0 12px 0 16px;
  border-bottom: 1px solid #E9ECEF;
  padding-top: env(safe-area-inset-top, 0px);
}

.server-dropdown-trigger {
  background: transparent;
  border: 0;
  display: flex;
  align-items: center;
  gap: 4px;
  padding: 8px 4px;
  font-family: inherit;
  cursor: pointer;
  color: #0F172A;
}

.server-name {
  font-size: 17px;
  font-weight: 800;
  letter-spacing: -0.02em;
}

.dropdown-chevron {
  color: #6C757D;
}

.header-icon-btn {
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

/* QMenu portal styles handled via global block below (teleported to body). */

/* Feed */
.feed {
  background: #fff;
}

.feed-card {
  border-bottom: 1px solid #F1F3F5;
  padding-bottom: 8px;
}

.feed-card-header {
  display: flex;
  align-items: center;
  gap: 12px;
  padding: 12px 16px 8px;
}

.feed-avatar {
  width: 36px;
  height: 36px;
  border-radius: 50%;
  background: #007BFF;
  color: #fff;
  font-weight: 700;
  font-size: 15px;
  display: flex;
  align-items: center;
  justify-content: center;
  overflow: hidden;
  flex-shrink: 0;

  img {
    width: 100%;
    height: 100%;
    object-fit: cover;
  }
}

.feed-meta {
  flex: 1;
  min-width: 0;
}

.feed-username {
  font-size: 14px;
  font-weight: 600;
  color: #0F172A;
  letter-spacing: -0.01em;
}

.feed-time {
  font-size: 12px;
  color: #6C757D;
}

.feed-image-wrap {
  background: #F1F3F5;
  width: 100%;
  aspect-ratio: 1;
  overflow: hidden;
}

.feed-image {
  width: 100%;
  height: 100%;
  object-fit: cover;
}

.feed-actions {
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding: 4px 8px;
}

.feed-actions-left {
  display: flex;
  align-items: center;
  gap: 0;
}

.feed-action-btn {
  background: transparent;
  border: 0;
  height: 40px;
  width: auto;
  // Reserve space for icon + single-digit count so the icon doesn't
  // shift when likeCount/commentCount transitions between 0 and 1.
  min-width: 48px;
  padding: 0 6px;
  border-radius: 12px;
  display: inline-flex;
  align-items: center;
  justify-content: center;
  gap: 4px;
  cursor: pointer;
  color: #212529;

  &:hover {
    background: #F1F3F5;
  }

  .icon-liked {
    color: #DC3545;
    fill: #DC3545;
  }
}

.action-count {
  font-size: 14px;
  font-weight: 600;
  color: #0F172A;
  letter-spacing: -0.01em;
}

.feed-caption {
  padding: 0 16px 12px;
  font-size: 14px;
  line-height: 1.4;
  color: #212529;

  .caption-username {
    font-weight: 600;
    margin-right: 6px;
  }
}

.bottom-spacer {
  height: 24px;
}
</style>

<!-- Global (unscoped) styles for teleported QMenu — scoped rules cannot
     reach Quasar's body-portal output. -->
<style lang="scss">
.server-menu {
  border-radius: 16px !important;
  box-shadow: 0 12px 32px rgba(15, 23, 42, 0.14) !important;
  overflow: hidden;
}

.server-menu-list {
  min-width: 280px;
  width: calc(100vw - 32px);
  max-width: 420px;
  padding: 6px 0;
}

.server-menu-item-active {
  color: var(--q-primary);
  font-weight: 600;
}

.menu-icon {
  width: 32px;
  height: 32px;
  border-radius: 10px;
  display: flex;
  align-items: center;
  justify-content: center;
}

.menu-icon-primary {
  background: #E7F1FF;
  color: var(--q-primary);
}

.menu-icon-soft {
  background: #F1F3F5;
  color: #495057;
}
</style>
