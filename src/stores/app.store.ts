import { defineStore } from 'pinia';
import { ref, computed } from 'vue';
import { api } from 'src/boot/axios';

/**
 * Server entry as returned by GET /api/servers/me.
 * Minimal fields — for full server detail use ServerDetail (fetched on demand).
 */
export interface Server {
  id: string;
  name: string;
  shortName: string;
  avatarImageUrl: string | null;
  joinedAt?: string;
}

export interface ServersMeResponse {
  data: Server[];
  page: { nextCursor: string | null; limit: number };
}

export const useAppStore = defineStore('app', () => {
  /* ─── State ────────────────────────────────────────────────── */
  const servers = ref<Server[]>([]);
  const activeServerId = ref<string | null>(null);
  const isInitialized = ref(false);
  const isLoading = ref(false);

  /* ─── Computed ─────────────────────────────────────────────── */
  const activeServer = computed(
    () => servers.value.find((s) => s.id === activeServerId.value) ?? null
  );
  const hasServers = computed(() => servers.value.length > 0);

  /* ─── Mutations ────────────────────────────────────────────── */
  function setServers(newServers: Server[]) {
    servers.value = newServers;
  }

  function setActiveServer(serverId: string) {
    activeServerId.value = serverId;
  }

  function reset() {
    servers.value = [];
    activeServerId.value = null;
    isInitialized.value = false;
  }

  /* ─── Actions ──────────────────────────────────────────────── */

  /**
   * Fetch the current user's joined servers.
   * Call after login, after creating/joining a server, or when stale.
   * Auto-selects the first server as active if none is selected.
   */
  async function fetchMyServers(force = false): Promise<Server[]> {
    if (isInitialized.value && !force) return servers.value;

    isLoading.value = true;
    try {
      const res = await api.get<ServersMeResponse>('/servers/me');
      const list = Array.isArray(res.data?.data) ? res.data.data : [];
      servers.value = list;

      if (list.length > 0 && !activeServerId.value) {
        activeServerId.value = list[0]!.id;
      } else if (
        activeServerId.value &&
        !list.some((s) => s.id === activeServerId.value)
      ) {
        activeServerId.value = list[0]?.id ?? null;
      }

      isInitialized.value = true;
      return list;
    } finally {
      isLoading.value = false;
    }
  }

  return {
    // state
    servers,
    activeServerId,
    isInitialized,
    isLoading,
    // computed
    activeServer,
    hasServers,
    // actions
    setServers,
    setActiveServer,
    fetchMyServers,
    reset,
  };
});
