<template>
  <q-page class="chat-page">
    <header class="ch-header">
      <button class="icon-btn" type="button" @click="goBack">
        <ChevronLeft :size="24" />
      </button>
      <h1 class="ch-title">Messages</h1>
      <span class="icon-btn"></span>
    </header>

    <!-- Search -->
    <div class="search-wrap">
      <Search :size="18" class="search-icon" />
      <input
        v-model="searchQuery"
        type="search"
        placeholder="Search messages…"
        class="search-input"
      />
    </div>

    <!-- Filter chips -->
    <div class="filter-strip">
      <button
        v-for="f in filters"
        :key="f.id"
        class="filter-chip"
        :class="{ active: activeFilter === f.id }"
        type="button"
        @click="activeFilter = f.id"
      >
        {{ f.label }}
        <span v-if="f.count" class="filter-count">{{ f.count }}</span>
      </button>
    </div>

    <!-- Threads -->
    <div v-if="visibleThreads.length === 0" class="empty">
      No conversations yet.
    </div>

    <div v-else class="thread-list">
      <button
        v-for="t in visibleThreads"
        :key="t.id"
        class="thread-row"
        type="button"
      >
        <div class="thread-avatar">
          <img v-if="t.avatarUrl" :src="t.avatarUrl" :alt="t.username" />
          <span v-else>{{ t.username.charAt(0).toUpperCase() }}</span>
        </div>

        <div class="thread-meta">
          <div class="thread-line1">
            <span class="thread-name">{{ t.fullname || t.username }}</span>
            <span class="thread-time">{{ t.timeLabel }}</span>
          </div>
          <div class="thread-line2">
            <span class="thread-snippet" :class="{ unread: t.unread }">
              <span v-if="t.typing" class="typing">typing…</span>
              <template v-else>{{ t.lastMessage }}</template>
            </span>
            <span v-if="t.unread" class="unread-dot"></span>
          </div>
        </div>
      </button>
    </div>

    <!-- Mock data disclaimer -->
    <p class="mock-note">
      Messages backend isn't built yet — these conversations are placeholder data.
    </p>
  </q-page>
</template>

<script setup lang="ts">
import { ref, computed } from 'vue';
import { useRouter } from 'vue-router';
import { ChevronLeft, Search } from 'lucide-vue-next';
import { CHAT_THREADS, type ChatFilter } from 'src/mocks/chat';

const router = useRouter();

const searchQuery = ref('');
const activeFilter = ref<ChatFilter>('all');

const filters = computed(() => {
  const unreadCount = CHAT_THREADS.filter((t) => t.unread).length;
  const requestCount = CHAT_THREADS.filter((t) => t.isRequest).length;
  return [
    { id: 'all' as const, label: 'All', count: 0 },
    { id: 'unread' as const, label: 'Unread', count: unreadCount },
    { id: 'requests' as const, label: 'Requests', count: requestCount },
  ];
});

const visibleThreads = computed(() => {
  const q = searchQuery.value.trim().toLowerCase();
  let list = CHAT_THREADS;
  if (activeFilter.value === 'unread') list = list.filter((t) => t.unread);
  if (activeFilter.value === 'requests') list = list.filter((t) => t.isRequest);
  if (!q) return list;
  return list.filter(
    (t) =>
      t.username.toLowerCase().includes(q) ||
      (t.fullname ?? '').toLowerCase().includes(q) ||
      t.lastMessage.toLowerCase().includes(q)
  );
});

function goBack() {
  if (window.history.length > 1) router.back();
  else void router.push({ name: 'home' });
}
</script>

<style lang="scss" scoped>
.chat-page {
  min-height: 100dvh;
  background: #fff;
  padding-bottom: 88px; /* clear bottom tab nav */
}

.ch-header {
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

.ch-title {
  flex: 1;
  text-align: center;
  font-size: 17px;
  font-weight: 600;
  letter-spacing: -0.01em;
  margin: 0;
  color: #0F172A;
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

.filter-strip {
  display: flex;
  gap: 8px;
  padding: 0 16px 12px;
  overflow-x: auto;
  scrollbar-width: none;

  &::-webkit-scrollbar {
    display: none;
  }
}

.filter-chip {
  flex-shrink: 0;
  background: #F1F3F5;
  border: 0;
  border-radius: 999px;
  height: 32px;
  padding: 0 12px;
  font-family: inherit;
  font-size: 13px;
  font-weight: 500;
  color: #495057;
  cursor: pointer;
  display: inline-flex;
  align-items: center;
  gap: 6px;

  &.active {
    background: #007BFF;
    color: #fff;

    .filter-count {
      background: rgba(255, 255, 255, 0.25);
    }
  }
}

.filter-count {
  background: rgba(0, 0, 0, 0.08);
  border-radius: 999px;
  font-size: 11px;
  font-weight: 700;
  padding: 1px 6px;
  min-width: 18px;
  text-align: center;
}

.thread-list {
  display: flex;
  flex-direction: column;
}

.thread-row {
  background: transparent;
  border: 0;
  border-bottom: 1px solid #F8F9FA;
  padding: 12px 16px;
  display: flex;
  align-items: center;
  gap: 12px;
  text-align: left;
  cursor: pointer;
  font-family: inherit;

  &:hover {
    background: #F8F9FA;
  }
}

.thread-avatar {
  width: 48px;
  height: 48px;
  border-radius: 50%;
  background: #007BFF;
  color: #fff;
  font-size: 17px;
  font-weight: 700;
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

.thread-meta {
  flex: 1;
  min-width: 0;
}

.thread-line1 {
  display: flex;
  justify-content: space-between;
  gap: 8px;
}

.thread-name {
  font-size: 14px;
  font-weight: 600;
  color: #0F172A;
  letter-spacing: -0.01em;
}

.thread-time {
  font-size: 12px;
  color: #ADB5BD;
  white-space: nowrap;
}

.thread-line2 {
  display: flex;
  justify-content: space-between;
  align-items: center;
  margin-top: 2px;
  gap: 8px;
}

.thread-snippet {
  font-size: 13px;
  color: #6C757D;
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
  flex: 1;

  &.unread {
    color: #212529;
    font-weight: 600;
  }
}

.typing {
  color: #007BFF;
  font-style: italic;
  font-weight: 500;
}

.unread-dot {
  width: 8px;
  height: 8px;
  border-radius: 50%;
  background: #007BFF;
  flex-shrink: 0;
}

.empty {
  text-align: center;
  color: #6C757D;
  padding: 32px;
  font-size: 14px;
}

.mock-note {
  margin: 24px 16px 0;
  text-align: center;
  font-size: 12px;
  color: #ADB5BD;
  font-style: italic;
}
</style>
