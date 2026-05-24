<template>
  <q-page class="notif-page">
    <header class="nf-header">
      <h1 class="nf-title">Notifications</h1>
    </header>

    <!-- Tabs -->
    <div class="tab-strip">
      <button
        v-for="t in tabs"
        :key="t.id"
        class="tab-pill"
        :class="{ active: activeTab === t.id }"
        type="button"
        @click="activeTab = t.id"
      >
        {{ t.label }}
      </button>
    </div>

    <!-- Empty state -->
    <div v-if="filteredItems.length === 0" class="empty-section">
      <img src="/assets/illustrator/notification.svg" alt="" style="width: 240px" class="empty-illustration" />
      <div class="empty-title">No notifications yet</div>
      <p class="empty-help">When someone likes or comments on your post, you'll see it here.</p>
    </div>

    <!-- Sections -->
    <template v-else>
      <NotifSection title="New" :items="grouped.new" @follow="toggleFollow" />
      <NotifSection title="Today" :items="grouped.today" @follow="toggleFollow" />
      <NotifSection title="Earlier" :items="grouped.earlier" @follow="toggleFollow" />
    </template>
  </q-page>
</template>

<script setup lang="ts">
import { ref, computed, defineComponent, h, type PropType } from 'vue';
import { Heart, MessageCircle, AtSign, UserPlus } from 'lucide-vue-next';
import { NOTIFICATIONS, type NotificationItem, type NotificationKind } from 'src/mocks/notifications';

type TabId = 'all' | 'mentions';

const tabs: { id: TabId; label: string }[] = [
  { id: 'all', label: 'All' },
  { id: 'mentions', label: 'Mentions' },
];

const activeTab = ref<TabId>('all');
const items = ref<NotificationItem[]>(NOTIFICATIONS);

const filteredItems = computed(() =>
  activeTab.value === 'mentions'
    ? items.value.filter((n) => n.kind === 'mention')
    : items.value
);

const grouped = computed(() => {
  const result = { new: [] as NotificationItem[], today: [] as NotificationItem[], earlier: [] as NotificationItem[] };
  for (const n of filteredItems.value) {
    result[n.group].push(n);
  }
  return result;
});

function toggleFollow(item: NotificationItem) {
  item.isFollowing = !item.isFollowing;
}

/* ─── Inline section + row components ─────────────────────── */
const NotifSection = defineComponent({
  name: 'NotifSection',
  props: {
    title: { type: String, required: true },
    items: { type: Array as PropType<NotificationItem[]>, required: true },
  },
  emits: ['follow'],
  setup(p, { emit }) {
    return () =>
      p.items.length === 0
        ? null
        : h('section', { class: 'notif-section' }, [
            h('h2', { class: 'section-title' }, p.title),
            ...p.items.map((n) =>
              h(NotifRow, {
                item: n,
                onFollow: () => emit('follow', n),
              })
            ),
          ]);
  },
});

function kindIcon(kind: NotificationKind) {
  if (kind === 'like') return Heart;
  if (kind === 'comment') return MessageCircle;
  if (kind === 'mention') return AtSign;
  return UserPlus;
}

function kindBadgeColor(kind: NotificationKind): string {
  if (kind === 'like') return '#DC3545';
  if (kind === 'comment') return '#007BFF';
  if (kind === 'mention') return '#10B981';
  return '#007BFF';
}

const NotifRow = defineComponent({
  name: 'NotifRow',
  props: {
    item: { type: Object as PropType<NotificationItem>, required: true },
  },
  emits: ['follow'],
  setup(p, { emit }) {
    return () => {
      const it = p.item;
      const initial = (it.actor.username || '?').charAt(0).toUpperCase();
      const Icon = kindIcon(it.kind);
      return h('div', { class: 'notif-row' }, [
        h('div', { class: 'notif-avatar-wrap' }, [
          h(
            'div',
            { class: 'notif-avatar' },
            it.actor.avatarUrl
              ? h('img', { src: it.actor.avatarUrl, alt: it.actor.username })
              : h('span', initial)
          ),
          h(
            'span',
            {
              class: 'notif-badge',
              style: { background: kindBadgeColor(it.kind) },
            },
            [h(Icon, { size: 11, 'stroke-width': 2.4 })]
          ),
        ]),
        h('div', { class: 'notif-content' }, [
          h('p', { class: 'notif-text' }, [
            h('span', { class: 'notif-username' }, it.actor.username),
            ' ',
            it.text,
          ]),
          h('span', { class: 'notif-time' }, it.timeLabel),
        ]),
        it.showFollowAction
          ? h(
              'button',
              {
                class: ['notif-follow-btn', it.isFollowing ? 'following' : ''],
                type: 'button',
                onClick: () => emit('follow'),
              },
              it.isFollowing ? 'Following' : 'Follow'
            )
          : it.thumbnailUrl
            ? h('div', { class: 'notif-thumb' }, [
                h('img', { src: it.thumbnailUrl, alt: '' }),
              ])
            : null,
      ]);
    };
  },
});
</script>

<style lang="scss" scoped>
.notif-page {
  min-height: 100dvh;
  background: #fff;
  padding-bottom: 80px;
  padding-top: env(safe-area-inset-top, 0px);
}

.nf-header {
  height: 56px;
  display: flex;
  align-items: center;
  justify-content: center;
  padding: 0 16px;
  border-bottom: 1px solid #F1F3F5;
}

.nf-title {
  font-size: 17px;
  font-weight: 700;
  letter-spacing: -0.01em;
  color: #0F172A;
  margin: 0;
}

/* Tabs */
.tab-strip {
  display: flex;
  gap: 8px;
  padding: 12px 16px;
  border-bottom: 1px solid #F1F3F5;
}

.tab-pill {
  flex: 1;
  background: #F1F3F5;
  border: 0;
  border-radius: 999px;
  height: 36px;
  font-family: inherit;
  font-size: 13px;
  font-weight: 600;
  color: #495057;
  cursor: pointer;

  &.active {
    background: #E7F1FF;
    color: #007BFF;
  }
}

/* Empty */
.empty-section {
  display: flex;
  flex-direction: column;
  align-items: center;
  text-align: center;
  padding: 32px 24px;
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
  margin: 8px 0 0;
  max-width: 280px;
}

/* Sections */
:deep(.notif-section) {
  padding: 16px 16px 8px;
}

:deep(.section-title) {
  font-size: 15px;
  font-weight: 700;
  color: #0F172A;
  margin: 0 0 8px;
  letter-spacing: -0.01em;
}

:deep(.notif-row) {
  display: flex;
  align-items: center;
  gap: 12px;
  padding: 8px 0;
}

:deep(.notif-avatar-wrap) {
  position: relative;
  flex-shrink: 0;
}

:deep(.notif-avatar) {
  width: 40px;
  height: 40px;
  border-radius: 50%;
  background: #007BFF;
  color: #fff;
  font-weight: 700;
  font-size: 14px;
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

:deep(.notif-badge) {
  position: absolute;
  right: -2px;
  bottom: -2px;
  width: 18px;
  height: 18px;
  border-radius: 50%;
  border: 2px solid #fff;
  display: flex;
  align-items: center;
  justify-content: center;
  color: #fff;
}

:deep(.notif-content) {
  flex: 1;
  min-width: 0;
}

:deep(.notif-text) {
  margin: 0;
  font-size: 14px;
  line-height: 1.4;
  color: #212529;
}

:deep(.notif-username) {
  font-weight: 600;
}

:deep(.notif-time) {
  font-size: 12px;
  color: #ADB5BD;
  margin-top: 2px;
  display: block;
}

:deep(.notif-follow-btn) {
  background: #007BFF;
  color: #fff;
  border: 0;
  border-radius: 8px;
  height: 32px;
  padding: 0 14px;
  font-size: 13px;
  font-weight: 600;
  cursor: pointer;
  font-family: inherit;
  flex-shrink: 0;

  &.following {
    background: #F1F3F5;
    color: #495057;
  }
}

:deep(.notif-thumb) {
  width: 40px;
  height: 40px;
  border-radius: 8px;
  background: #F1F3F5;
  overflow: hidden;
  flex-shrink: 0;

  img {
    width: 100%;
    height: 100%;
    object-fit: cover;
  }
}
</style>
