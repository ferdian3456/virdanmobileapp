<template>
  <q-page class="post-detail-page">
    <!-- Top bar -->
    <header class="pd-header">
      <button class="icon-btn" type="button" @click="goBack">
        <ChevronLeft :size="24" />
      </button>
      <h1 class="pd-title">Post</h1>
      <span class="pd-spacer"></span>
    </header>

    <div v-if="loading" class="state-block">
      <q-spinner-dots color="primary" size="36px" />
    </div>

    <article v-else-if="post" class="post-card">
      <header class="post-header">
        <div class="post-avatar">
          <img v-if="post.ownerImageUrl" :src="post.ownerImageUrl" :alt="post.ownerName" />
          <span v-else>{{ post.ownerName.charAt(0).toUpperCase() }}</span>
        </div>
        <div class="post-meta">
          <div class="post-username">{{ post.ownerName }}</div>
          <div class="post-time">{{ formatDate(post.createDatetime) }}</div>
        </div>
        <button class="icon-btn" type="button" aria-label="More">
          <MoreHorizontal :size="20" />
        </button>
      </header>

      <div class="post-image-wrap">
        <img :src="post.postImageUrl" :alt="post.caption" class="post-image" />
      </div>

      <div class="post-actions">
        <div class="actions-left">
          <button class="action-btn" type="button" @click="toggleLike">
            <Heart
              :size="26"
              :stroke-width="post.liked ? 0 : 2"
              :class="post.liked ? 'icon-liked' : ''"
            />
          </button>
          <button class="action-btn" type="button" @click="openComments">
            <MessageCircle :size="26" :stroke-width="2" />
          </button>
          <button class="action-btn" type="button" aria-label="Share">
            <Send :size="24" :stroke-width="2" />
          </button>
        </div>
        <button class="action-btn" type="button" aria-label="Save">
          <Bookmark :size="24" :stroke-width="2" />
        </button>
      </div>

      <div v-if="post.likeCount > 0" class="post-likecount">
        {{ post.likeCount }} {{ post.likeCount === 1 ? 'like' : 'likes' }}
      </div>

      <div class="post-caption">
        <span class="caption-username">{{ post.ownerName }}</span>
        {{ post.caption }}
      </div>

      <button
        v-if="post.commentCount > 0"
        class="comments-link"
        type="button"
        @click="openComments"
      >
        View all {{ post.commentCount }} comments
      </button>
    </article>

    <div v-else class="state-block">
      <p class="empty-text">Post not found.</p>
    </div>
  </q-page>
</template>

<script setup lang="ts">
import { ref, onMounted } from 'vue';
import { useRouter } from 'vue-router';
import {
  ChevronLeft, MoreHorizontal, Heart, MessageCircle, Send, Bookmark,
} from 'lucide-vue-next';
import { api } from 'src/boot/axios';
import { useToast } from 'src/composables/useToast';
import { normalizeError } from 'src/composables/useApiError';

interface PostDetail {
  postId: string;
  ownerId: string;
  ownerName: string;
  ownerImageUrl: string | null;
  postImageUrl: string;
  caption: string;
  likeCount: number;
  commentCount: number;
  isLiked: boolean;
  liked?: boolean;
  createDatetime: string;
}

const props = defineProps<{ postId: string }>();

const router = useRouter();
const toast = useToast();

const post = ref<PostDetail | null>(null);
const loading = ref(true);

onMounted(loadPost);

async function loadPost() {
  loading.value = true;
  try {
    const res = await api.get<PostDetail>(`/posts/${props.postId}`);
    post.value = { ...res.data, liked: !!res.data.isLiked };
  } catch (err) {
    const norm = normalizeError(err);
    toast.error(norm.message);
  } finally {
    loading.value = false;
  }
}

async function toggleLike() {
  if (!post.value) return;
  const wasLiked = !!post.value.liked;
  post.value.liked = !wasLiked;
  post.value.likeCount = Math.max(0, post.value.likeCount + (wasLiked ? -1 : 1));

  try {
    const url = `/posts/${props.postId}/likes`;
    const res = wasLiked
      ? await api.delete<{ likeCount: number }>(url)
      : await api.post<{ likeCount: number }>(url, {});
    post.value.likeCount = res.data.likeCount;
  } catch {
    if (post.value) {
      post.value.liked = wasLiked;
      post.value.likeCount = Math.max(0, post.value.likeCount + (wasLiked ? 1 : -1));
    }
  }
}

async function openComments() {
  await router.push({ name: 'comments', params: { postId: props.postId } });
}

function goBack() {
  if (window.history.length > 1) router.back();
  else void router.push({ name: 'home' });
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
.post-detail-page {
  min-height: 100dvh;
  background: #fff;
  padding-bottom: 80px;
}

.pd-header {
  position: sticky;
  top: 0;
  z-index: 5;
  background: #fff;
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

.pd-title {
  flex: 1;
  text-align: center;
  font-size: 17px;
  font-weight: 600;
  letter-spacing: -0.01em;
  margin: 0;
  color: #0F172A;
}

.pd-spacer {
  width: 40px;
  height: 40px;
}

.post-card {
  display: flex;
  flex-direction: column;
}

.post-header {
  display: flex;
  align-items: center;
  gap: 12px;
  padding: 12px 16px 8px;
}

.post-avatar {
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

.post-meta {
  flex: 1;
  min-width: 0;
}

.post-username {
  font-size: 14px;
  font-weight: 600;
  color: #0F172A;
  letter-spacing: -0.01em;
}

.post-time {
  font-size: 12px;
  color: #6C757D;
}

.post-image-wrap {
  background: #F1F3F5;
  width: 100%;
  aspect-ratio: 1;
  overflow: hidden;
}

.post-image {
  width: 100%;
  height: 100%;
  object-fit: cover;
}

.post-actions {
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding: 8px 12px;
}

.actions-left {
  display: flex;
  gap: 4px;
}

.action-btn {
  background: transparent;
  border: 0;
  width: 40px;
  height: 40px;
  border-radius: 50%;
  display: flex;
  align-items: center;
  justify-content: center;
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

.post-likecount {
  padding: 0 16px 4px;
  font-size: 14px;
  font-weight: 600;
  color: #0F172A;
}

.post-caption {
  padding: 0 16px 8px;
  font-size: 14px;
  line-height: 1.5;
  color: #212529;

  .caption-username {
    font-weight: 600;
    margin-right: 6px;
  }
}

.comments-link {
  background: transparent;
  border: 0;
  font-family: inherit;
  text-align: left;
  padding: 4px 16px 16px;
  color: #6C757D;
  font-size: 14px;
  cursor: pointer;

  &:hover {
    color: #007BFF;
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
