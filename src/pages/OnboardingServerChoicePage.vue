<template>
  <q-page class="onboarding-page">
    <!-- Hero -->
    <section class="ob-hero">
      <h1 class="ob-title">
        Get Started
        <span class="ob-title-accent">Find Your Community</span>
      </h1>
      <p class="ob-subtitle">
        Create your own server or join an existing community — pick what suits your interests.
      </p>
    </section>

    <!-- Create Your Server CTA card -->
    <button class="create-card" type="button" @click="goCreate">
      <div class="create-card-meta">
        <span class="create-card-eyebrow">GOT A COMMUNITY?</span>
        <span class="create-card-title">Create Your Server</span>
        <span class="create-card-help">Start a new community and invite your friends</span>
      </div>
      <div class="create-card-chev">
        <ChevronRight :size="20" :stroke-width="2.4" />
      </div>
    </button>

    <!-- Divider -->
    <div class="divider-row">
      <div class="divider-line"></div>
      <span class="divider-label">OR JOIN A COMMUNITY</span>
      <div class="divider-line"></div>
    </div>

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

    <!-- Popular servers list -->
    <div class="server-list-wrap">
      <div class="server-list-header">
        <h2 class="server-list-title">Popular Servers</h2>
        <span class="server-list-count">{{ filteredServers.length }} servers</span>
      </div>

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
            <!-- TODO: server verification badge — BE belum punya field verified -->
          </div>
          <div class="srv-desc">{{ srv.description || 'No description provided' }}</div>
          <div class="srv-stats">
            <span class="srv-stat">
              <Users :size="12" /> {{ formatStat(srv.memberCount) }}
            </span>
            <!-- TODO: online count — BE belum expose onlineCount (perlu presence tracking) -->
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

      <!-- Pagination: load-more spinner (not skeleton — list already filled) -->
      <div v-if="loadingMore" class="load-more">
        <q-spinner-dots color="primary" size="28px" />
      </div>

      <!-- Infinite-scroll trigger -->
      <div ref="sentinelEl" class="sls-sentinel" aria-hidden="true"></div>
    </div>

  </q-page>
</template>

<script setup lang="ts">
import { ref, computed, onMounted, onUnmounted } from 'vue';
import { useRouter } from 'vue-router';
import { ChevronRight, Search, Users } from 'lucide-vue-next';
import { api } from 'src/boot/axios';
import { useAppStore } from 'src/stores/app.store';
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
  // TODO: onlineCount — BE belum expose, perlu presence tracking (kompleks).
}

interface PaginatedResponse<T> {
  data: T[];
  page: { nextCursor: string | null; limit: number };
}

const router = useRouter();
const appStore = useAppStore();
const toast = useToast();

const categories = ref<CategoryItem[]>([]);
const categoriesLoading = ref(false);
const CHIP_SKELETON_WIDTHS = [56, 72, 60, 80, 64, 68];
const servers = ref<DiscoveryServer[]>([]);
const activeCategoryId = ref<number | null>(null);
const searchQuery = ref('');
const loading = ref(false);
const loadingMore = ref(false);
const nextCursor = ref<string | null>(null);
const sentinelEl = ref<HTMLElement | null>(null);
const joiningId = ref<string | null>(null);

const SERVERS_LIMIT = 20;

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

let scrollObserver: IntersectionObserver | null = null;

onMounted(async () => {
  await Promise.all([loadCategories(), loadServers(true)]);

  // Infinite scroll: load the next page when the bottom sentinel appears.
  scrollObserver = new IntersectionObserver((entries) => {
    if (entries[0]?.isIntersecting) void loadServers(false);
  });
  if (sentinelEl.value) scrollObserver.observe(sentinelEl.value);
});

onUnmounted(() => {
  scrollObserver?.disconnect();
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

async function loadServers(reset = true) {
  if (reset) {
    if (loading.value) return;
    loading.value = true;
    nextCursor.value = null;
    // Clear list so the skeleton (v-if loading && servers.length === 0)
    // takes over instead of stale rows from the previous category.
    servers.value = [];
  } else {
    if (loadingMore.value || nextCursor.value === null) return;
    loadingMore.value = true;
  }

  try {
    const params: Record<string, string | number> = { limit: SERVERS_LIMIT };
    if (activeCategoryId.value !== null) params.categoryId = activeCategoryId.value;
    if (!reset && nextCursor.value) params.cursor = nextCursor.value;
    const res = await api.get<PaginatedResponse<DiscoveryServer>>('/servers/', { params });
    const pageData = res.data?.data ?? [];
    // BE returns "" for "no more pages"; treat falsy as null so the
    // infinite-scroll guard (nextCursor === null) actually short-circuits.
    const pageCursor = res.data?.page?.nextCursor || null;

    servers.value = reset ? pageData : [...servers.value, ...pageData];
    nextCursor.value = pageCursor;
  } catch (err) {
    toast.error(apiErrorToast(err, () => void loadServers(reset)));
  } finally {
    if (reset) loading.value = false;
    else loadingMore.value = false;
  }
}

function setCategory(id: number | null) {
  activeCategoryId.value = id;
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

async function goCreate() {
  await router.push({ name: 'onboarding-create-server' });
}
</script>

<style lang="scss" scoped>
.onboarding-page {
  min-height: 100dvh;
  background: #fff;
  padding-bottom: env(safe-area-inset-bottom, 24px);
}

/* Hero */
.ob-hero {
  padding: 32px 20px 12px;
}

.ob-title {
  font-family: 'Inter', sans-serif;
  font-size: 34px;
  line-height: 1.1;
  font-weight: 800;
  letter-spacing: -0.02em;
  color: #0F172A;
  margin: 0;
}

.ob-title-accent {
  display: block;
  color: #007BFF;
}

.ob-subtitle {
  font-size: 14px;
  color: #6C757D;
  line-height: 1.5;
  margin: 12px 0 0;
}

/* Create card */
.create-card {
  width: calc(100% - 40px);
  margin: 20px 20px 0;
  background: linear-gradient(135deg, #007BFF, #0056CC);
  color: #fff;
  border: 0;
  border-radius: 18px;
  padding: 18px 18px;
  display: flex;
  align-items: center;
  gap: 16px;
  cursor: pointer;
  font-family: inherit;
  text-align: left;
  box-shadow: 0 8px 22px rgba(108, 99, 255, 0.25);
  transition: transform 0.05s ease;

  &:hover {
    box-shadow: 0 12px 28px rgba(108, 99, 255, 0.32);
  }

  &:active {
    transform: scale(0.99);
  }
}

.create-card-meta {
  flex: 1;
  display: flex;
  flex-direction: column;
  gap: 4px;
}

.create-card-eyebrow {
  font-size: 11px;
  font-weight: 600;
  letter-spacing: 0.08em;
  color: rgba(255, 255, 255, 0.7);
}

.create-card-title {
  font-size: 18px;
  font-weight: 700;
  letter-spacing: -0.01em;
}

.create-card-help {
  font-size: 13px;
  color: rgba(255, 255, 255, 0.85);
  line-height: 1.4;
}

.create-card-chev {
  width: 36px;
  height: 36px;
  border-radius: 50%;
  background: rgba(255, 255, 255, 0.18);
  display: flex;
  align-items: center;
  justify-content: center;
  flex-shrink: 0;
}

/* Divider */
.divider-row {
  display: flex;
  align-items: center;
  gap: 12px;
  margin: 24px 20px 16px;
}

.divider-line {
  flex: 1;
  height: 1px;
  background: #E9ECEF;
}

.divider-label {
  font-size: 11px;
  font-weight: 600;
  letter-spacing: 0.08em;
  color: #ADB5BD;
}

/* Search */
.search-wrap {
  position: relative;
  margin: 0 20px 12px;
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
  padding: 0 14px 0 40px;
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

/* Category strip */
.category-strip {
  display: flex;
  gap: 8px;
  padding: 0 20px 12px;
  overflow-x: auto;
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

/* Server list */
.server-list-wrap {
  padding: 0 20px;
}

.server-list-header {
  display: flex;
  justify-content: space-between;
  align-items: baseline;
  margin: 8px 0;
}

.server-list-title {
  font-size: 16px;
  font-weight: 700;
  color: #0F172A;
  letter-spacing: -0.01em;
  margin: 0;
}

.server-list-count {
  font-size: 12px;
  color: #6C757D;
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

/* Pagination */
.load-more {
  display: flex;
  justify-content: center;
  padding: 16px 0;
}

.sls-sentinel {
  height: 1px;
}

/* States */
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
