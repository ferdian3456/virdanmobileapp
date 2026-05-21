<template>
  <q-page class="comments-page">
    <!-- Header -->
    <header class="cm-header">
      <button class="icon-btn" type="button" @click="goBack">
        <ChevronLeft :size="24" />
      </button>
      <h1 class="cm-title">
        Comments
        <span v-if="totalCount !== null" class="cm-count">· {{ totalCount }}</span>
      </h1>
      <span class="icon-btn"></span>
    </header>

    <!-- Post context snippet -->
    <div v-if="post" class="post-context">
      <div class="post-context-thumb">
        <img v-if="post.postImageUrl" :src="post.postImageUrl" alt="" />
      </div>
      <div class="post-context-meta">
        <div class="post-context-line1">
          <span class="post-context-author">{{ post.ownerName }}</span>
          <span class="post-context-caption">{{ post.caption }}</span>
        </div>
        <div class="post-context-line2">
          <span>{{ formatRelative(post.createdAt) }}</span>
          <span v-if="post.likeCount > 0" class="dot">·</span>
          <span v-if="post.likeCount > 0">{{ post.likeCount }} likes</span>
        </div>
      </div>
    </div>

    <!-- Sort row -->
    <div class="sort-row">
      <button class="sort-trigger" type="button" @click="cycleSort">
        {{ activeSortLabel }}
        <ChevronDown :size="14" />
      </button>
      <span class="sort-count">{{ totalCount ?? 0 }} comments</span>
    </div>

    <!-- Comments list -->
    <div class="cm-list">
      <div v-if="loading && comments.length === 0" class="state-block">
        <q-spinner-dots color="primary" size="32px" />
      </div>

      <div v-else-if="visibleComments.length === 0" class="empty-block">
        <p class="empty-text">No comments yet. Be the first to share your thoughts.</p>
      </div>

      <CommentNode
        v-for="root in visibleComments"
        :key="root.id"
        :node="root"
        :current-user-id="currentUserId"
        :deleting-id="deletingId"
        @reply="setReplyTo"
        @delete="deleteComment"
      />

      <q-infinite-scroll
        v-if="hasMore"
        :disable="loading || !hasMore"
        @load="loadMore"
      >
        <template #loading>
          <div class="state-block">
            <q-spinner-dots color="primary" size="28px" />
          </div>
        </template>
      </q-infinite-scroll>
    </div>

    <!-- Reply hint -->
    <div v-if="replyingTo" class="reply-hint">
      <span>Replying to <strong>{{ replyingTo.authorName }}</strong></span>
      <button class="hint-cancel" type="button" @click="replyingTo = null">
        <X :size="16" />
      </button>
    </div>

    <!-- Quick emoji bar -->
    <div class="emoji-bar">
      <button
        v-for="emoji in QUICK_EMOJI"
        :key="emoji"
        class="emoji-chip"
        type="button"
        @click="insertEmoji(emoji)"
      >
        {{ emoji }}
      </button>
    </div>

    <!-- Composer -->
    <footer class="composer">
      <div
        class="composer-avatar"
        :style="{ background: avatarColor(currentUserName) }"
      >
        <img v-if="meAvatar" :src="meAvatar" alt="" />
        <span v-else>{{ meInitial }}</span>
      </div>
      <div class="composer-input-wrap">
        <textarea
          ref="textareaRef"
          v-model="draft"
          class="composer-input"
          placeholder="Add a comment…"
          rows="1"
          @input="autoResize"
          @keydown.enter.exact.prevent="sendComment"
        ></textarea>
        <button class="composer-emoji-btn" type="button" @click="insertEmoji('😊')" aria-label="Emoji">
          <Smile :size="18" />
        </button>
      </div>
      <button
        class="composer-send"
        type="button"
        :disabled="!canSend || isSubmitting"
        @click="sendComment"
      >
        {{ isSubmitting ? '…' : 'Send' }}
      </button>
    </footer>
  </q-page>
</template>

<script setup lang="ts">
import {
  ref, computed, onMounted, h, defineComponent, markRaw,
  type PropType, type Component,
} from 'vue';
import { useRouter } from 'vue-router';
import {
  ChevronLeft, ChevronDown, X, Trash2, Heart, Smile,
} from 'lucide-vue-next';
import { useQuasar } from 'quasar';
import { api } from 'src/boot/axios';
import { useAuthStore } from 'src/stores/auth.store';
import { useToast } from 'src/composables/useToast';
import { apiErrorToast } from 'src/composables/useApiError';

interface CommentItem {
  id: string;
  authorId: string;
  authorName: string;
  authorAvatar: string | null;
  parentId: string | null;
  content: string;
  createdAt: string;
  updatedAt: string;
}

interface CommentTreeNode extends CommentItem {
  replies: CommentTreeNode[];
}

interface PostContext {
  postId: string;
  ownerName: string;
  postImageUrl: string;
  caption: string;
  likeCount: number;
  commentCount: number;
  createdAt: string;
}

interface PaginatedResponse<T> {
  data: T[];
  page: { nextCursor: string | null; limit: number };
}

type SortId = 'relevant' | 'recent' | 'liked';

const SORT_LABELS: Record<SortId, string> = {
  relevant: 'Most relevant',
  recent: 'Newest first',
  liked: 'Most liked',
};

const QUICK_EMOJI = ['❤️', '🔥', '😂', '😮', '🥺', '👏', '🙏', '💯'];

const AVATAR_COLORS = [
  '#007BFF', '#EC4899', '#F59E0B', '#10B981',
  '#06B6D4', '#8B5CF6', '#EF4444', '#7C3AED',
];

const props = defineProps<{ postId: string }>();

const router = useRouter();
const $q = useQuasar();
const authStore = useAuthStore();
const toast = useToast();

const sort = ref<SortId>('relevant');
const post = ref<PostContext | null>(null);
const totalCount = ref<number | null>(null);

const comments = ref<CommentItem[]>([]);
const nextCursor = ref<string | null>(null);
const hasMore = ref(true);
const loading = ref(false);

const draft = ref('');
const isSubmitting = ref(false);
const replyingTo = ref<CommentItem | null>(null);
const deletingId = ref<string | null>(null);
const textareaRef = ref<HTMLTextAreaElement | null>(null);

const currentUserId = computed(() => authStore.user?.id ?? '');
const currentUserName = computed(() => authStore.user?.username ?? authStore.user?.fullname ?? '');
const meAvatar = computed(() => authStore.user?.avatarImage ?? null);
const meInitial = computed(
  () => (currentUserName.value || '?').charAt(0).toUpperCase()
);

const canSend = computed(() => draft.value.trim().length > 0);
const activeSortLabel = computed(() => SORT_LABELS[sort.value]);

/* ─── Avatar color (deterministic hash → palette) ───────── */
function avatarColor(name: string): string {
  if (!name) return AVATAR_COLORS[0]!;
  let hash = 0;
  for (let i = 0; i < name.length; i++) {
    hash = (hash * 31 + name.charCodeAt(i)) & 0x7fffffff;
  }
  return AVATAR_COLORS[hash % AVATAR_COLORS.length]!;
}

/* ─── Build tree from flat list ────────────────────────────── */
const tree = computed<CommentTreeNode[]>(() => {
  const byId = new Map<string, CommentTreeNode>();
  comments.value.forEach((c) => {
    byId.set(c.id, { ...c, replies: [] });
  });
  const roots: CommentTreeNode[] = [];
  byId.forEach((node) => {
    if (node.parentId && byId.has(node.parentId)) {
      byId.get(node.parentId)!.replies.push(node);
    } else {
      roots.push(node);
    }
  });
  return roots;
});

const visibleComments = computed(() => {
  const arr = [...tree.value];
  if (sort.value === 'recent') {
    arr.sort(
      (a, b) =>
        new Date(b.createdAt).getTime() - new Date(a.createdAt).getTime()
    );
  }
  // 'relevant' / 'liked' fall back to API order — BE has no like-per-comment yet.
  return arr;
});

function cycleSort() {
  const order: SortId[] = ['relevant', 'recent', 'liked'];
  const idx = order.indexOf(sort.value);
  sort.value = order[(idx + 1) % order.length]!;
}

function formatRelative(ts: string): string {
  const d = new Date(ts);
  const diff = Math.floor((Date.now() - d.getTime()) / 1000);
  if (diff < 60) return 'just now';
  if (diff < 3600) return `${Math.floor(diff / 60)}m ago`;
  if (diff < 86400) return `${Math.floor(diff / 3600)}h ago`;
  if (diff < 604800) return `${Math.floor(diff / 86400)}d ago`;
  return d.toLocaleDateString(undefined, { month: 'short', day: 'numeric' });
}

/* ─── Inline tree node component ─────────────────────────── */
const CommentNode: Component = markRaw(defineComponent({
  name: 'CommentNode',
  props: {
    node: { type: Object as PropType<CommentTreeNode>, required: true },
    currentUserId: { type: String, required: true },
    deletingId: { type: String as PropType<string | null>, default: null },
    depth: { type: Number, default: 0 },
  },
  emits: ['reply', 'delete'],
  setup(p: { node: CommentTreeNode; currentUserId: string; deletingId: string | null; depth: number }, { emit }) {
    const isOwn = computed(() => p.node.authorId === p.currentUserId);
    const liked = ref(false);

    function fmt(ts: string) {
      const d = new Date(ts);
      const diff = Math.floor((Date.now() - d.getTime()) / 1000);
      if (diff < 60) return 'now';
      if (diff < 3600) return `${Math.floor(diff / 60)}m`;
      if (diff < 86400) return `${Math.floor(diff / 3600)}h`;
      if (diff < 604800) return `${Math.floor(diff / 86400)}d`;
      return d.toLocaleDateString(undefined, { month: 'short', day: 'numeric' });
    }

    return () => {
      const node = p.node;
      const initial = (node.authorName || '?').charAt(0).toUpperCase();
      return h(
        'div',
        { class: ['cm-node', p.depth > 0 ? 'cm-node-reply' : ''] },
        [
          h('div', { class: 'cm-row' }, [
            h(
              'div',
              { class: 'cm-avatar', style: { background: avatarColor(node.authorName) } },
              node.authorAvatar
                ? h('img', { src: node.authorAvatar, alt: node.authorName })
                : h('span', initial)
            ),
            h('div', { class: 'cm-body' }, [
              h('div', { class: 'cm-line1' }, [
                h('span', { class: 'cm-author' }, node.authorName),
                ' ',
                h('span', { class: 'cm-content' }, node.content),
              ]),
              h('div', { class: 'cm-line2' }, [
                h('span', { class: 'cm-time' }, fmt(node.createdAt)),
                h(
                  'button',
                  {
                    class: 'cm-text-btn',
                    type: 'button',
                    onClick: () => emit('reply', node),
                  },
                  'Reply'
                ),
                isOwn.value
                  ? h(
                      'button',
                      {
                        class: 'cm-text-btn cm-text-btn-danger',
                        type: 'button',
                        disabled: p.deletingId === node.id,
                        onClick: () => emit('delete', node),
                      },
                      [h(Trash2, { size: 13 }), ' Delete']
                    )
                  : null,
              ]),
            ]),
            h(
              'button',
              {
                class: ['cm-like', liked.value ? 'liked' : ''],
                type: 'button',
                'aria-label': 'Like comment',
                onClick: () => (liked.value = !liked.value),
              },
              [h(Heart, { size: 18, 'stroke-width': liked.value ? 0 : 2 })]
            ),
          ]),
          // Replies
          node.replies.length > 0
            ? h('div', { class: 'cm-replies' }, [
                ...node.replies.map((reply) =>
                  h(CommentNode, {
                    node: reply,
                    currentUserId: p.currentUserId,
                    deletingId: p.deletingId,
                    depth: p.depth + 1,
                    onReply: (n: CommentItem) => emit('reply', n),
                    onDelete: (n: CommentItem) => emit('delete', n),
                  })
                ),
              ])
            : null,
        ]
      );
    };
  },
}));

/* ─── Lifecycle ─────────────────────────────────────────── */
onMounted(async () => {
  if (!authStore.user) {
    try {
      await authStore.fetchUser();
    } catch {
      // continue
    }
  }
  await Promise.all([loadPost(), loadComments(true)]);
});

async function loadPost() {
  try {
    const res = await api.get<PostContext>(`/posts/${props.postId}`);
    post.value = res.data;
    totalCount.value = res.data.commentCount;
  } catch {
    // Post snippet is optional context; silently skip on failure.
  }
}

async function loadComments(reset: boolean) {
  if (loading.value) return;
  loading.value = true;
  try {
    const params: Record<string, string | number> = { limit: 20 };
    if (!reset && nextCursor.value) params.cursor = nextCursor.value;
    const res = await api.get<PaginatedResponse<CommentItem>>(
      `/posts/${props.postId}/comments`,
      { params }
    );
    const list = res.data?.data ?? [];
    if (reset) comments.value = list;
    else comments.value.push(...list);
    nextCursor.value = res.data?.page?.nextCursor ?? null;
    hasMore.value = !!nextCursor.value;
    if (totalCount.value === null) totalCount.value = comments.value.length;
  } catch (err) {
    toast.error(apiErrorToast(err, () => void loadComments(reset)));
  } finally {
    loading.value = false;
  }
}

async function loadMore(_idx: number, done: (stop?: boolean) => void) {
  if (!hasMore.value) {
    done(true);
    return;
  }
  await loadComments(false);
  done(!hasMore.value);
}

function setReplyTo(c: CommentItem) {
  replyingTo.value = c;
  textareaRef.value?.focus();
}

function insertEmoji(emoji: string) {
  draft.value = draft.value + emoji;
  textareaRef.value?.focus();
}

async function sendComment() {
  if (!canSend.value || isSubmitting.value) return;
  isSubmitting.value = true;
  try {
    const body: { content: string; parentId: string | null } = {
      content: draft.value.trim(),
      parentId: replyingTo.value?.id ?? null,
    };
    const res = await api.post<CommentItem>(`/posts/${props.postId}/comments`, body);
    comments.value.push(res.data);
    if (totalCount.value !== null) totalCount.value += 1;
    draft.value = '';
    replyingTo.value = null;
    autoResize();
  } catch (err) {
    toast.error(apiErrorToast(err));
  } finally {
    isSubmitting.value = false;
  }
}

function deleteComment(c: CommentItem) {
  $q.dialog({
    title: 'Delete comment?',
    message: 'This cannot be undone.',
    cancel: true,
    persistent: true,
    ok: { label: 'Delete', color: 'negative', noCaps: true, unelevated: true },
  }).onOk(() => {
    void (async () => {
      deletingId.value = c.id;
      const prev = comments.value;
      comments.value = comments.value.filter((x) => x.id !== c.id);
      if (totalCount.value !== null) totalCount.value = Math.max(0, totalCount.value - 1);
      try {
        await api.delete(`/posts/${props.postId}/comments/${c.id}`);
      } catch (err) {
        comments.value = prev;
        toast.error(apiErrorToast(err));
      } finally {
        deletingId.value = null;
      }
    })();
  });
}

function autoResize() {
  const el = textareaRef.value;
  if (!el) return;
  el.style.height = 'auto';
  el.style.height = `${Math.min(el.scrollHeight, 120)}px`;
}

function goBack() {
  if (window.history.length > 1) router.back();
  else void router.push({ name: 'home' });
}
</script>

<style lang="scss" scoped>
.comments-page {
  min-height: 100dvh;
  background: #fff;
  display: flex;
  flex-direction: column;
  padding-bottom: env(safe-area-inset-bottom, 0px);
}

.cm-header {
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

.cm-title {
  flex: 1;
  text-align: center;
  font-size: 17px;
  font-weight: 600;
  letter-spacing: -0.01em;
  margin: 0;
  color: #0F172A;
}

.cm-count {
  color: #6C757D;
  font-weight: 500;
  margin-left: 4px;
}

/* ─── Post context snippet ──────────────────────────────── */
.post-context {
  display: flex;
  gap: 12px;
  padding: 10px 16px;
  background: #F8F9FA;
  border-bottom: 1px solid #F1F3F5;
}

.post-context-thumb {
  width: 36px;
  height: 36px;
  border-radius: 8px;
  background: #DEE2E6;
  overflow: hidden;
  flex-shrink: 0;

  img {
    width: 100%;
    height: 100%;
    object-fit: cover;
  }
}

.post-context-meta {
  flex: 1;
  min-width: 0;
}

.post-context-line1 {
  font-size: 13px;
  line-height: 1.4;
  color: #212529;
  display: -webkit-box;
  -webkit-line-clamp: 2;
  -webkit-box-orient: vertical;
  overflow: hidden;
}

.post-context-author {
  font-weight: 600;
  margin-right: 6px;
}

.post-context-line2 {
  font-size: 11px;
  color: #6C757D;
  margin-top: 2px;
  display: flex;
  gap: 6px;
  align-items: center;

  .dot {
    color: #DEE2E6;
  }
}

/* ─── Sort row ──────────────────────────────────────────── */
.sort-row {
  display: flex;
  justify-content: space-between;
  align-items: center;
  padding: 10px 16px;
  border-bottom: 1px solid #F1F3F5;
}

.sort-trigger {
  background: transparent;
  border: 0;
  font-family: inherit;
  font-size: 13px;
  font-weight: 600;
  color: #212529;
  cursor: pointer;
  display: inline-flex;
  align-items: center;
  gap: 4px;
  padding: 4px 0;
}

.sort-count {
  font-size: 12px;
  color: #6C757D;
}

/* ─── Comment list ──────────────────────────────────────── */
.cm-list {
  flex: 1;
  overflow-y: auto;
  padding-bottom: 12px;
}

.empty-block {
  padding: 80px 24px 32px;
  text-align: center;
}

.empty-text {
  color: #6C757D;
  font-size: 14px;
  margin: 0;
}

:deep(.cm-node) {
  padding: 12px 16px;
}

:deep(.cm-node-reply) {
  padding-left: 60px;
}

:deep(.cm-row) {
  display: flex;
  gap: 12px;
  align-items: flex-start;
}

:deep(.cm-avatar) {
  width: 36px;
  height: 36px;
  border-radius: 50%;
  color: #fff;
  font-weight: 700;
  font-size: 14px;
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

:deep(.cm-body) {
  flex: 1;
  min-width: 0;
}

:deep(.cm-line1) {
  font-size: 14px;
  line-height: 1.4;
  color: #212529;
}

:deep(.cm-author) {
  font-weight: 600;
}

:deep(.cm-content) {
  white-space: pre-wrap;
}

:deep(.cm-line2) {
  display: flex;
  gap: 14px;
  align-items: center;
  margin-top: 6px;
  font-size: 12px;
  color: #6C757D;
}

:deep(.cm-time) {
  font-weight: 500;
}

:deep(.cm-text-btn) {
  background: transparent;
  border: 0;
  cursor: pointer;
  font-family: inherit;
  font-size: 12px;
  color: #6C757D;
  font-weight: 600;
  padding: 0;
  display: inline-flex;
  align-items: center;
  gap: 4px;

  &:hover {
    color: #212529;
  }
}

:deep(.cm-text-btn-danger:hover) {
  color: #DC3545;
}

:deep(.cm-like) {
  background: transparent;
  border: 0;
  width: 28px;
  height: 28px;
  border-radius: 50%;
  color: #495057;
  display: flex;
  align-items: center;
  justify-content: center;
  cursor: pointer;
  flex-shrink: 0;

  &:hover {
    background: #F1F3F5;
  }

  &.liked {
    color: #DC3545;

    svg {
      fill: #DC3545;
    }
  }
}

:deep(.cm-replies) {
  margin-top: 4px;
}

/* ─── Reply hint ────────────────────────────────────────── */
.reply-hint {
  background: #E7F1FF;
  color: #007BFF;
  font-size: 13px;
  padding: 8px 16px;
  display: flex;
  justify-content: space-between;
  align-items: center;
}

.hint-cancel {
  background: transparent;
  border: 0;
  color: #007BFF;
  cursor: pointer;
  display: flex;
  align-items: center;
  justify-content: center;
}

/* ─── Quick emoji bar ───────────────────────────────────── */
.emoji-bar {
  display: flex;
  justify-content: space-around;
  align-items: center;
  width: 100%;
  padding: 12px 12px;
  border-top: 1px solid #F1F3F5;
}

.emoji-chip {
  background: transparent;
  border: 0;
  font-size: 22px;
  width: 36px;
  height: 36px;
  border-radius: 50%;
  cursor: pointer;
  display: inline-flex;
  align-items: center;
  justify-content: center;
  flex-shrink: 0;

  &:hover {
    background: #F1F3F5;
  }
}

/* ─── Composer ──────────────────────────────────────────── */
.composer {
  display: flex;
  align-items: flex-end;
  gap: 12px;
  width: 100%;
  padding: 10px 16px;
  padding-bottom: calc(env(safe-area-inset-bottom, 0px) + 24px);
  border-top: 1px solid #F1F3F5;
  background: #fff;
}

.composer-avatar {
  width: 32px;
  height: 32px;
  border-radius: 50%;
  color: #fff;
  font-weight: 700;
  font-size: 13px;
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

.composer-input-wrap {
  flex: 1;
  position: relative;
  display: flex;
  align-items: center;
  background: #F1F3F5;
  border-radius: 18px;
  padding: 0 8px 0 14px;

  &:focus-within {
    background: #fff;
    box-shadow: 0 0 0 1px #007BFF;
  }
}

.composer-input {
  flex: 1;
  border: 0;
  background: transparent;
  padding: 8px 0;
  font-family: inherit;
  font-size: 14px;
  resize: none;
  outline: none;
  max-height: 120px;
  line-height: 1.4;

  &::placeholder {
    color: #ADB5BD;
  }
}

.composer-emoji-btn {
  background: transparent;
  border: 0;
  color: #6C757D;
  cursor: pointer;
  width: 28px;
  height: 28px;
  display: inline-flex;
  align-items: center;
  justify-content: center;
  border-radius: 50%;

  &:hover {
    color: #212529;
  }
}

.composer-send {
  background: transparent;
  border: 0;
  color: #007BFF;
  font-weight: 600;
  font-size: 14px;
  cursor: pointer;
  font-family: inherit;
  padding: 8px 4px;

  &:disabled {
    color: #ADB5BD;
    cursor: default;
  }
}

.state-block {
  display: flex;
  align-items: center;
  justify-content: center;
  padding: 32px 16px;
}
</style>
