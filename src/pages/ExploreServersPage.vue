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
      <template v-if="categoriesLoading">
        <VSkeleton
          v-for="(w, i) in CHIP_SKELETON_WIDTHS"
          :key="i"
          variant="box"
          :width="`${w}px`"
          height="32px"
          radius="999px"
        />
      </template>
      <template v-else>
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
      </template>
    </div>

    <!-- Server list -->
    <div class="server-list">
      <ServerListSkeleton v-if="loading && servers.length === 0" />

      <div v-else-if="filteredServers.length === 0" class="empty-state">
        <img src="/assets/illustrator/empty.svg" alt="" class="empty-illustration" />
        <p class="empty-text">No servers match your search.</p>
      </div>

      <article
        v-for="srv in filteredServers"
        :key="srv.id"
        class="server-row"
      >
        <div class="srv-avatar" :style="{ background: srvAvatarColor(srv.shortName ?? srv.name) }">
          <img v-if="srv.avatarUrl" :src="srv.avatarUrl" :alt="srv.name" />
          <span v-else>{{ (srv.shortName ?? srv.name).charAt(0).toUpperCase() }}</span>
        </div>
        <div class="srv-meta">
          <div class="srv-name-row">
            <span class="srv-name">{{ srv.name }}</span>
          </div>
          <div class="srv-desc">{{ srv.description || 'No description provided' }}</div>
          <div class="srv-stats">
            <span class="srv-stat">
              <Users :size="12" /> {{ formatStat(srv.memberCount) }}
            </span>
          </div>
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
import { ref, computed, onMounted } from 'vue';
import { useRouter, useRoute } from 'vue-router';
import { ChevronLeft, Search, Users } from 'lucide-vue-next';
import { api } from 'src/boot/axios';
import { useServerCreateStore } from 'src/stores/server-create.store';
import { useToast } from 'src/composables/useToast';
import { apiErrorToast } from 'src/composables/useApiError';
import VSkeleton from 'src/components/feedback/VSkeleton.vue';
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
  memberCount: number;
}

interface PaginatedResponse<T> {
  data: T[];
  page: { nextCursor: string | null; limit: number };
}

const router = useRouter();
const route = useRoute();
const serverCreateStore = useServerCreateStore();
const toast = useToast();

const isOnboarding = computed(() => route.meta.onboardingFlow === true);

const categories = ref<CategoryItem[]>([]);
const categoriesLoading = ref(false);
const CHIP_SKELETON_WIDTHS = [56, 72, 60, 80, 64, 68];
const servers = ref<DiscoveryServer[]>([]);
const activeCategoryId = ref<number | null>(null);
const searchQuery = ref('');
const loading = ref(false);
const joiningId = ref<string | null>(null);
const nextCursor = ref<string | null>(null);
const hasMore = ref(true);

const AVATAR_COLORS = [
  '#8B5CF6', '#EC4899', '#F59E0B', '#10B981',
  '#06B6D4', '#3B82F6', '#EF4444', '#7C3AED',
];

function srvAvatarColor(seed: string): string {
  let hash = 0;
  for (let i = 0; i < seed.length; i++) {
    hash = (hash * 31 + seed.charCodeAt(i)) & 0x7fffffff;
  }
  return AVATAR_COLORS[hash % AVATAR_COLORS.length]!;
}

function formatStat(value: number | undefined): string {
  if (value === undefined || value === null) return '0';
  if (value >= 1_000_000) return `${(value / 1_000_000).toFixed(1)}M`;
  if (value >= 1_000) return `${(value / 1_000).toFixed(value >= 10_000 ? 0 : 1)}k`.replace('.0k', 'k');
  return String(value);
}

const filteredServers = computed(() => {
  const q = searchQuery.value.trim().toLowerCase();
  if (!q) return servers.value;
  return servers.value.filter(
    (s) =>
      s.name.toLowerCase().includes(q) ||
      (s.description ?? '').toLowerCase().includes(q)
  );
});

/* ─── Lifecycle ─────────────────────────────────────────────── */
onMounted(async () => {
  await Promise.all([loadCategories(), loadServers(true)]);
});

async function loadCategories() {
  categoriesLoading.value = true;
  try {
    const res = await api.get<PaginatedResponse<CategoryItem>>('/servers/categories', {
      params: { limit: 20 },
    });
    categories.value = res.data?.data ?? [];
  } catch {
    // Silent — chips simply won't render.
  } finally {
    categoriesLoading.value = false;
  }
}

async function loadServers(reset: boolean) {
  if (loading.value) return;
  loading.value = true;
  if (reset) {
    // Clear list so the skeleton (v-if loading && servers.length === 0)
    // takes over instead of stale rows from the previous category.
    servers.value = [];
    nextCursor.value = null;
  }
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
    // BE returns "" for "no more pages"; treat falsy as null so the
    // infinite-scroll guard short-circuits.
    nextCursor.value = res.data?.page?.nextCursor || null;
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
  // Join now requires a per-server profile (nickname + username + bio +
  // avatar). Stash the target and hand off to YourProfilePage.
  serverCreateStore.setJoinTarget({
    serverId: srv.id,
    serverName: srv.name,
    serverShortName: srv.shortName,
  });
  await router.push({ name: 'create-server-profile' });
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
  border: 1px solid #E9ECEF;
  color: #495057;
  font-size: 13px;
  font-weight: 500;
  cursor: pointer;
  font-family: inherit;
  transition: background 0.15s ease, color 0.15s ease, border-color 0.15s ease;

  &:hover {
    background: #F1F3F5;
  }

  &.active {
    background: #007BFF;
    color: #fff;
    border-color: #007BFF;
  }
}

.server-list {
  padding: 8px 20px 24px;
}

.server-row {
  display: flex;
  align-items: center;
  gap: 12px;
  padding: 12px 0;
  border-bottom: 1px solid #F1F3F5;

  &:last-child {
    border-bottom: 0;
  }
}

.srv-avatar {
  width: 44px;
  height: 44px;
  border-radius: 50%;
  flex-shrink: 0;
  display: flex;
  align-items: center;
  justify-content: center;
  color: #fff;
  font-weight: 700;
  font-size: 18px;
  letter-spacing: -0.02em;
  overflow: hidden;

  img {
    width: 100%;
    height: 100%;
    object-fit: cover;
  }
}

.srv-meta {
  flex: 1;
  min-width: 0;
}

.srv-name-row {
  display: inline-flex;
  align-items: center;
  gap: 4px;
}

.srv-name {
  font-size: 14px;
  font-weight: 600;
  color: #0F172A;
  letter-spacing: -0.01em;
}

.srv-desc {
  font-size: 12px;
  color: #6C757D;
  line-height: 1.4;
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
  margin-top: 2px;
}

.srv-stats {
  display: flex;
  gap: 12px;
  margin-top: 4px;
  font-size: 11px;
  color: #6C757D;
}

.srv-stat {
  display: inline-flex;
  align-items: center;
  gap: 4px;
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

.empty-state {
  display: flex;
  flex-direction: column;
  align-items: center;
  padding: 24px 0 32px;
}

.empty-illustration {
  width: 220px;
  max-width: 60%;
}

.empty-text {
  color: #6C757D;
  font-size: 14px;
  margin-top: 24px;
}
</style>
