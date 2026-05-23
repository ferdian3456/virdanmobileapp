import { defineStore } from 'pinia';
import { ref } from 'vue';

/**
 * In-progress Create Server draft.
 *
 * Held in memory only — File objects cannot be serialized to localStorage,
 * so navigating away from the create flow tree clears the draft.
 */
export interface CreateServerDraft {
  name: string;
  shortName: string;
  categoryId: number | null;
  description: string;
  isPrivate: boolean;
  serverAvatarFile: File | null;
  serverAvatarPreview: string | null;
}

/** Snapshot of the server a user is about to join, set on Join click. */
export interface JoinServerTarget {
  serverId: string;
  serverName: string;
  serverShortName: string;
}

export const useServerCreateStore = defineStore('server-create', () => {
  const draft = ref<CreateServerDraft | null>(null);
  const joinTarget = ref<JoinServerTarget | null>(null);

  function setDraft(value: CreateServerDraft) {
    draft.value = value;
    joinTarget.value = null;
  }

  function clearDraft() {
    draft.value = null;
  }

  function setJoinTarget(value: JoinServerTarget) {
    joinTarget.value = value;
    draft.value = null;
  }

  function clearJoinTarget() {
    joinTarget.value = null;
  }

  return { draft, joinTarget, setDraft, clearDraft, setJoinTarget, clearJoinTarget };
});
