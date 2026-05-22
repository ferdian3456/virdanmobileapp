<template>
  <q-page class="explore-servers-page">
    <!-- Top bar -->
    <header class="es-header">
      <button class="icon-btn" type="button" @click="goBack">
        <ChevronLeft :size="24" />
      </button>
      <h1 class="es-title">Join Servers</h1>
      <span class="es-spacer"></span>
    </header>

    <!-- Hero -->
    <section class="es-hero">
      <h2 class="hero-title">
        Find <span class="hero-accent">Your Community</span>
      </h2>
      <p class="hero-subtitle">
        Discover servers that match your interests — gaming, study, music, tech, and more.
      </p>
    </section>

    <!-- Search -->
    <div class="search-wrap">
      <Search :size="18" class="search-icon" />
      <input
        v-model="searchQuery"
        type="search"
        placeholder="Search servers…"
        class="search-input"
      />
    </div>

    <!-- Category chips -->
    <div class="category-strip">
      <button
        type="button"
        class="chip"
        :class="{ active: activeCategoryId === null }"
        @click="setCategory(null)"
      >
        All
      </button>
      <button
        v-for="cat in categories"
        :key="cat.id"
        type="button"
        class="chip"
        :class="{ active: activeCategoryId === cat.id }"
        @click="setCategory(cat.id)"
      >
        {{ cat.categoryName }}
      </button>
    </div>

    <!-- Server list -->
    <div class="server-list">
      <ServerListSkeleton v-if="loading && servers.length === 0" />

      <div v-else-if="filteredServers.length === 0" class="state-block">
        <p class="empty-text">No servers match your search.</p>
      </div>

      <article
        v-for="srv in filteredServers"
        :key="srv.id"
        class="server-card"
      >
        <ServerAvatar :name="srv.name" :short="srv.shortName" :url="srv.avatarUrl" />

        <div class="server-meta">
          <div class="server-name">{{ srv.name }}</div>
          <div class="server-desc">{{ srv.description || 'No description provided' }}</div>
        </div>

        <button
          class="join-btn"
          type="button"
          :disabled="joiningId === srv.id"
          @click="join(srv)"
        >
          {{ joiningId === srv.id ? '…' : 'Join' }}
        </button>
      </article>

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
    </div>
  </q-page>
</template>

<script setup lang="ts">
import { ref, computed, onMounted, h, defineComponent } from 'vue';
import type { PropType } from 'vue';
import { useRouter, useRoute } from 'vue-router';
import { ChevronLeft, Search } from 'lucide-vue-next';
import { api } from 'src/boot/axios';
import { useAppStore } from 'src/stores/app.store';
import { useToast } from 'src/composables/useToast';
import { apiErrorToast } from 'src/composables/useApiError';
import ServerListSkeleton from 'src/components/feedback/skeletons/ServerListSkeleton.vue';

interface CategoryItem {
  id: number;
  categoryName: string;
}

interface DiscoveryServer {
  id: string;
  name: string;
  shortName: string;
  categoryName: string | null;
  avatarUrl: string | null;
  bannerUrl: string | null;
  description: string | null;
  createdAt: string;
}

interface PaginatedResponse<T> {
  data: T[];
  page: { nextCursor: string | null; limit: number };
}

const router = useRouter();
const route = useRoute();
const appStore = useAppStore();
const toast = useToast();

const isOnboarding = computed(() => route.meta.onboardingFlow === true);

const categories = ref<CategoryItem[]>([]);
const servers = ref<DiscoveryServer[]>([]);
const activeCategoryId = ref<number | null>(null);
const searchQuery = ref('');
const loading = ref(false);
const joiningId = ref<string | null>(null);
const nextCursor = ref<string | null>(null);
const hasMore = ref(true);

const filteredServers = computed(() => {
  const q = searchQuery.value.trim().toLowerCase();
  if (!q) return servers.value;
  return servers.value.filter(
    (s) =>
      s.name.toLowerCase().includes(q) ||
      (s.description ?? '').toLowerCase().includes(q)
  );
});

/* ─── Mini avatar component ─────────────────────────────────── */
const ServerAvatar = defineComponent({
  name: 'ServerAvatar',
  props: {
    name: { type: String, required: true },
    short: { type: String, required: true },
    url: { type: String as PropType<string | null>, default: null },
  },
  setup(props) {
    return () => {
      if (props.url) {
        return h('div', { class: 'srv-avatar' }, [
          h('img', { src: props.url, alt: props.name, class: 'srv-avatar-img' }),
        ]);
      }
      const initial = (props.short || props.name || '?').slice(0, 1).toUpperCase();
      return h('div', { class: 'srv-avatar srv-avatar-fallback' }, initial);
    };
  },
});

/* ─── Lifecycle ─────────────────────────────────────────────── */
onMounted(async () => {
  await Promise.all([loadCategories(), loadServers(true)]);
});

async function loadCategories() {
  try {
    const res = await api.get<PaginatedResponse<CategoryItem>>('/servers/categories', {
      params: { limit: 20 },
    });
    categories.value = res.data?.data ?? [];
  } catch {
    // Keep silent — chips simply won't render.
  }
}

async function loadServers(reset: boolean) {
  if (loading.value) return;
  loading.value = true;
  try {
    const params: Record<string, string | number> = { limit: 12 };
    if (activeCategoryId.value !== null) params.categoryId = activeCategoryId.value;
    if (!reset && nextCursor.value) params.cursor = nextCursor.value;

    const res = await api.get<PaginatedResponse<DiscoveryServer>>('/servers/', { params });
    const list = res.data?.data ?? [];
    if (reset) {
      servers.value = list;
    } else {
      servers.value.push(...list);
    }
    nextCursor.value = res.data?.page?.nextCursor ?? null;
    hasMore.value = !!nextCursor.value;
  } catch (err) {
    toast.error(apiErrorToast(err, () => void loadServers(reset)));
  } finally {
    loading.value = false;
  }
}

async function loadMore(_idx: number, done: (stop?: boolean) => void) {
  if (!hasMore.value) {
    done(true);
    return;
  }
  await loadServers(false);
  done(!hasMore.value);
}

function setCategory(id: number | null) {
  activeCategoryId.value = id;
  nextCursor.value = null;
  hasMore.value = true;
  void loadServers(true);
}

async function join(srv: DiscoveryServer) {
  if (joiningId.value) return;
  joiningId.value = srv.id;
  try {
    await api.post(`/servers/${srv.id}/join`);
    toast.success({ title: `Joined ${srv.name}.` });

    await appStore.fetchMyServers(true);
    appStore.setActiveServer(srv.id);

    await router.push({ name: 'home' });
  } catch (err) {
    toast.error(apiErrorToast(err));
  } finally {
    joiningId.value = null;
  }
}

function goBack() {
  if (isOnboarding.value) {
    void router.push({ name: 'onboarding-server-choice' });
    return;
  }
  if (window.history.length > 1) {
    router.back();
  } else {
    void router.push({ name: 'home' });
  }
}
</script>

<style lang="scss" scoped>
.explore-servers-page {
  min-height: 100dvh;
  background: #fff;
  padding-bottom: 88px; /* clear bottom tab nav */
}

.es-header {
  position: sticky;
  top: 0;
  z-index: 5;
  background: #fff;
  height: 56px;
  display: flex;
  align-items: center;
  padding: 0 12px;
  border-bottom: 1px solid #E9ECEF;
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

.es-title {
  flex: 1;
  text-align: center;
  font-size: 17px;
  font-weight: 600;
  letter-spacing: -0.01em;
  margin: 0;
  color: #212529;
}

.es-spacer {
  width: 40px;
  height: 40px;
}

.es-hero {
  padding: 24px 20px 16px;
}

.hero-title {
  font-family: 'Inter', sans-serif;
  font-size: 30px;
  line-height: 1.15;
  font-weight: 800;
  letter-spacing: -0.02em;
  color: #0F172A;
  margin: 0;
}

.hero-accent {
  display: block;
  color: #007BFF;
}

.hero-subtitle {
  font-size: 14px;
  color: #6C757D;
  line-height: 1.5;
  margin: 12px 0 0;
}

.search-wrap {
  margin: 0 20px 16px;
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
  height: 44px;
  padding: 0 16px 0 40px;
  border-radius: 12px;
  border: 1px solid transparent;
  background: #F1F3F5;
  font-size: 14px;
  font-family: inherit;
  color: #212529;
  outline: none;

  &:focus {
    background: #fff;
    border-color: #007BFF;
  }

  &::placeholder {
    color: #ADB5BD;
  }
}

.category-strip {
  display: flex;
  gap: 8px;
  padding: 0 20px 12px;
  overflow-x: auto;
  border-bottom: 1px solid #F1F3F5;
  -webkit-overflow-scrolling: touch;
  scrollbar-width: none;

  &::-webkit-scrollbar {
    display: none;
  }
}

.chip {
  flex-shrink: 0;
  height: 32px;
  padding: 0 14px;
  border-radius: 999px;
  background: transparent;
  color: #495057;
  font-size: 13px;
  font-weight: 500;
  border: 0;
  cursor: pointer;
  font-family: inherit;
  transition: background 0.15s ease, color 0.15s ease;

  &:hover {
    background: #F1F3F5;
  }

  &.active {
    background: #007BFF;
    color: #fff;
  }
}

.server-list {
  padding: 8px 20px 24px;
}

.server-card {
  display: flex;
  align-items: center;
  gap: 12px;
  padding: 12px 0;
  border-bottom: 1px solid #F1F3F5;
}

:deep(.srv-avatar) {
  width: 44px;
  height: 44px;
  border-radius: 12px;
  flex-shrink: 0;
  overflow: hidden;
  display: flex;
  align-items: center;
  justify-content: center;
}

:deep(.srv-avatar-img) {
  width: 100%;
  height: 100%;
  object-fit: cover;
}

:deep(.srv-avatar-fallback) {
  background: #E7F1FF;
  color: #007BFF;
  font-weight: 700;
  font-size: 18px;
  letter-spacing: -0.02em;
}

.server-meta {
  flex: 1;
  min-width: 0;
}

.server-name {
  font-size: 15px;
  font-weight: 600;
  color: #212529;
  letter-spacing: -0.01em;
}

.server-desc {
  font-size: 13px;
  color: #6C757D;
  line-height: 1.4;
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
  margin-top: 2px;
}

.join-btn {
  background: #007BFF;
  color: #fff;
  border: 0;
  border-radius: 999px;
  height: 32px;
  padding: 0 18px;
  font-size: 13px;
  font-weight: 600;
  cursor: pointer;
  font-family: inherit;
  flex-shrink: 0;

  &:hover {
    background: #0056CC;
  }

  &:disabled {
    opacity: 0.6;
    cursor: default;
  }
}

.state-block {
  display: flex;
  align-items: center;
  justify-content: center;
  padding: 32px 0;
}

.empty-text {
  color: #6C757D;
  font-size: 14px;
}
</style>
