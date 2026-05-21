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
      <button
        v-for="cat in categories"
        :key="cat.id"
        type="button"
        class="chip"
        :class="{ active: activeCategoryId === cat.id }"
        @click="setCategory(cat.id)"
      >
        {{ cat.name }}
      </button>
    </div>

    <!-- Popular servers list -->
    <div class="server-list-wrap">
      <div class="server-list-header">
        <h2 class="server-list-title">Popular Servers</h2>
        <span class="server-list-count">{{ filteredServers.length }} servers</span>
      </div>

      <div v-if="loading && servers.length === 0" class="state-block">
        <q-spinner-dots color="primary" size="36px" />
      </div>

      <div v-else-if="filteredServers.length === 0" class="state-block">
        <p class="empty-text">No servers match your search.</p>
      </div>

      <article
        v-for="srv in filteredServers"
        :key="srv.id"
        class="server-row"
      >
        <div class="srv-avatar" :style="{ background: srvAvatarColor(srv.shortName ?? srv.name) }">
          <img v-if="srv.avatarImageUrl" :src="srv.avatarImageUrl" :alt="srv.name" />
          <span v-else>{{ (srv.shortName ?? srv.name).charAt(0).toUpperCase() }}</span>
        </div>
        <div class="srv-meta">
          <div class="srv-name-row">
            <span class="srv-name">{{ srv.name }}</span>
            <BadgeCheck :size="14" class="srv-verified" />
          </div>
          <div class="srv-desc">{{ srv.description || 'No description provided' }}</div>
          <div class="srv-stats">
            <span class="srv-stat">
              <Users :size="12" /> {{ formatStat(srv.memberCount) }}
            </span>
            <span class="srv-online">
              <span class="online-dot"></span> {{ formatStat(srv.onlineCount) }} online
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
    </div>

  </q-page>
</template>

<script setup lang="ts">
import { ref, computed, onMounted } from 'vue';
import { useRouter } from 'vue-router';
import { ChevronRight, Search, BadgeCheck, Users } from 'lucide-vue-next';
import { api } from 'src/boot/axios';
import { useAppStore } from 'src/stores/app.store';
import { useToast } from 'src/composables/useToast';
import { normalizeError } from 'src/composables/useApiError';

interface CategoryItem {
  id: number;
  name: string;
}

interface DiscoveryServer {
  id: string;
  name: string;
  shortName: string;
  categoryName: string | null;
  avatarImageUrl: string | null;
  bannerImageUrl: string | null;
  description: string | null;
  createDatetime: string;
  // BE doesn't expose memberCount / onlineCount yet — mocked client-side.
  memberCount?: number;
  onlineCount?: number;
}

interface PaginatedResponse<T> {
  data: T[];
  page: { nextCursor: string | null; limit: number };
}

const router = useRouter();
const appStore = useAppStore();
const toast = useToast();

const categories = ref<CategoryItem[]>([]);
const servers = ref<DiscoveryServer[]>([]);
const activeCategoryId = ref<number | null>(null);
const searchQuery = ref('');
const loading = ref(false);
const joiningId = ref<string | null>(null);

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

onMounted(async () => {
  await Promise.all([loadCategories(), loadServers()]);
});

async function loadCategories() {
  try {
    const res = await api.get<PaginatedResponse<CategoryItem>>('/servers/categories', {
      params: { limit: 20 },
    });
    categories.value = res.data?.data ?? [];
  } catch {
    // Silent — chips simply won't render.
  }
}

async function loadServers() {
  if (loading.value) return;
  loading.value = true;
  try {
    const params: Record<string, string | number> = { limit: 20 };
    if (activeCategoryId.value !== null) params.categoryId = activeCategoryId.value;
    const res = await api.get<PaginatedResponse<DiscoveryServer>>('/servers/', { params });
    const list = (res.data?.data ?? []).map((s) => ({
      ...s,
      // Mock counts until BE exposes them.
      memberCount: deterministicCount(s.id, 200, 30000),
      onlineCount: deterministicCount(s.id + ':online', 5, 1500),
    }));
    servers.value = list;
  } catch (err) {
    const norm = normalizeError(err);
    toast.error({ title: norm.message });
  } finally {
    loading.value = false;
  }
}

function deterministicCount(seed: string, min: number, max: number): number {
  let hash = 0;
  for (let i = 0; i < seed.length; i++) {
    hash = (hash * 31 + seed.charCodeAt(i)) & 0x7fffffff;
  }
  return min + (hash % (max - min));
}

function setCategory(id: number | null) {
  activeCategoryId.value = id;
  void loadServers();
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
    const norm = normalizeError(err);
    toast.error({ title: norm.message });
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
  color: #6C63FF;
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
  background: linear-gradient(135deg, #6C63FF, #5046E5);
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
    border-color: #6C63FF;
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
    background: #6C63FF;
    color: #fff;
    border-color: #6C63FF;
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

.srv-verified {
  color: #6C63FF;
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

.srv-online {
  display: inline-flex;
  align-items: center;
  gap: 4px;
  color: #10B981;
  font-weight: 500;
}

.online-dot {
  width: 6px;
  height: 6px;
  border-radius: 50%;
  background: #10B981;
}

.join-btn {
  background: #6C63FF;
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
    background: #5046E5;
  }

  &:disabled {
    opacity: 0.6;
    cursor: default;
  }
}

/* States */
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
