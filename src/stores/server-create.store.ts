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

export const useServerCreateStore = defineStore('server-create', () => {
  const draft = ref<CreateServerDraft | null>(null);

  function setDraft(value: CreateServerDraft) {
    draft.value = value;
  }

  function clearDraft() {
    draft.value = null;
  }

  return { draft, setDraft, clearDraft };
});
