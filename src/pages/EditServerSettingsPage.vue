<template>
  <q-page class="settings-page">
    <!-- Top bar -->
    <header class="ess-header">
      <button class="header-link" type="button" @click="cancel">Cancel</button>
      <h1 class="ess-title">Server Settings</h1>
      <button
        class="header-link primary"
        type="button"
        :disabled="!hasChanges || isSaving"
        @click="save"
      >
        {{ isSaving ? 'Saving…' : 'Save' }}
      </button>
    </header>

    <SettingsFormSkeleton v-if="loading" />

    <template v-else-if="server">
      <!-- Avatar -->
      <section class="avatar-section">
        <button class="avatar-btn" type="button" @click="pickAvatar">
          <img v-if="avatarPreview" :src="avatarPreview" alt="" />
          <img v-else-if="server.avatarUrl" :src="server.avatarUrl" alt="" />
          <span v-else class="avatar-fallback">{{ server.shortName?.charAt(0)?.toUpperCase() }}</span>
          <span class="avatar-edit">
            <Pencil :size="14" :stroke-width="2.2" />
          </span>
        </button>
        <input
          ref="avatarInput"
          type="file"
          :accept="ALLOWED_TYPES.join(',')"
          class="hidden-input"
          @change="onAvatarSelected"
        />
        <button class="change-icon-link" type="button" @click="pickAvatar">Change Icon</button>
      </section>

      <!-- Server name -->
      <section class="settings-section">
        <h2 class="section-label">SERVER NAME</h2>
        <q-input
          v-model="form.name"
          outlined
          dense
          maxlength="40"
          class="ess-input"
          hide-bottom-space
        />
      </section>

      <!-- Description -->
      <section class="settings-section">
        <h2 class="section-label">DESCRIPTION</h2>
        <q-input
          v-model="form.description"
          outlined
          type="textarea"
          rows="4"
          maxlength="150"
          class="ess-input ess-textarea"
          hide-bottom-space
        />
      </section>

      <!-- Privacy & Access -->
      <section class="settings-section">
        <h2 class="section-label">PRIVACY &amp; ACCESS</h2>

        <div class="toggle-row">
          <div class="toggle-text">
            <div class="toggle-title">Private Server</div>
            <div class="toggle-help">Only invited members can join</div>
          </div>
          <q-toggle v-model="form.isPrivate" color="primary" />
        </div>

        <div class="toggle-row" :class="{ disabled: true }">
          <div class="toggle-text">
            <div class="toggle-title">Allow Direct Messages</div>
            <div class="toggle-help">Members can message each other (coming soon)</div>
          </div>
          <q-toggle v-model="form.allowDM" color="primary" disable />
        </div>
      </section>

      <!-- Management -->
      <section class="settings-section">
        <h2 class="section-label">MANAGEMENT</h2>
        <button class="mgmt-row" type="button" disabled>
          <span class="mgmt-icon" style="background:#FFF1F2; color:#EC4899">
            <Shield :size="20" />
          </span>
          <span class="mgmt-text">
            <span class="mgmt-title">Roles &amp; Permissions</span>
            <span class="mgmt-help">Coming soon</span>
          </span>
          <ChevronRight :size="18" class="mgmt-chevron" />
        </button>

        <button class="mgmt-row" type="button" disabled>
          <span class="mgmt-icon" style="background:#FEF3C7; color:#F59E0B">
            <Smile :size="20" />
          </span>
          <span class="mgmt-text">
            <span class="mgmt-title">Emoji Management</span>
            <span class="mgmt-help">Coming soon</span>
          </span>
          <ChevronRight :size="18" class="mgmt-chevron" />
        </button>
      </section>

      <!-- Danger zone -->
      <section class="settings-section danger">
        <button class="danger-btn" type="button" @click="confirmDelete">
          <Trash2 :size="18" />
          Delete Server
        </button>
      </section>
    </template>

    <div v-else class="state-block">
      <p class="empty-text">Server not found.</p>
    </div>
  </q-page>
</template>

<script setup lang="ts">
import { ref, computed, onMounted } from 'vue';
import { useRouter } from 'vue-router';
import { useQuasar } from 'quasar';
import {
  Pencil, Shield, Smile, ChevronRight, Trash2,
} from 'lucide-vue-next';
import { api } from 'src/boot/axios';
import { useAppStore } from 'src/stores/app.store';
import { useToast } from 'src/composables/useToast';
import { apiErrorToast } from 'src/composables/useApiError';
import SettingsFormSkeleton from 'src/components/feedback/skeletons/SettingsFormSkeleton.vue';

interface ServerDetail {
  id: string;
  name: string;
  shortName: string;
  categoryName?: string | null;
  avatarUrl: string | null;
  bannerUrl: string | null;
  description: string | null;
  isPrivate?: boolean | null;
}

const props = defineProps<{ id: string }>();

const router = useRouter();
const $q = useQuasar();
const appStore = useAppStore();
const toast = useToast();

const ALLOWED_TYPES = ['image/jpeg', 'image/jpg', 'image/png', 'image/webp'];
const MAX_FILE_SIZE_MB = 5;

const loading = ref(false);
const isSaving = ref(false);

const server = ref<ServerDetail | null>(null);

const form = ref({
  name: '',
  description: '',
  isPrivate: false,
  allowDM: false, // BE not supported — UI placeholder only.
});

const initial = ref({
  name: '',
  description: '',
  isPrivate: false,
});

const avatarInput = ref<HTMLInputElement | null>(null);
const avatarFile = ref<File | null>(null);
const avatarPreview = ref<string | null>(null);

const hasChanges = computed(() => {
  if (avatarFile.value) return true;
  return (
    form.value.name.trim() !== initial.value.name ||
    form.value.description.trim() !== initial.value.description ||
    form.value.isPrivate !== initial.value.isPrivate
  );
});

onMounted(loadServer);

async function loadServer() {
  loading.value = true;
  try {
    const res = await api.get<ServerDetail>(`/servers/${props.id}`);
    server.value = res.data;
    form.value.name = res.data.name ?? '';
    form.value.description = res.data.description ?? '';
    form.value.isPrivate = !!res.data.isPrivate;
    initial.value = {
      name: form.value.name,
      description: form.value.description,
      isPrivate: form.value.isPrivate,
    };
  } catch (err) {
    toast.error(apiErrorToast(err, () => void loadServer()));
  } finally {
    loading.value = false;
  }
}

function pickAvatar() {
  avatarInput.value?.click();
}

function onAvatarSelected(event: Event) {
  const input = event.target as HTMLInputElement;
  const file = input.files?.[0];
  if (!file) return;

  if (!ALLOWED_TYPES.includes(file.type)) {
    toast.error({ title: 'Unsupported format. Use JPEG, PNG, or WebP.' });
    return;
  }
  const sizeMB = file.size / (1024 * 1024);
  if (sizeMB > MAX_FILE_SIZE_MB) {
    toast.error({ title: `Icon must be smaller than ${MAX_FILE_SIZE_MB}MB.` });
    return;
  }

  avatarFile.value = file;
  const reader = new FileReader();
  reader.onload = (e) => {
    avatarPreview.value = (e.target?.result as string) ?? null;
  };
  reader.readAsDataURL(file);
}

async function save() {
  if (!hasChanges.value || isSaving.value) return;
  isSaving.value = true;
  try {
    const tasks: Promise<unknown>[] = [];
    const trimmedName = form.value.name.trim();
    const trimmedDesc = form.value.description.trim();

    if (trimmedName !== initial.value.name) {
      tasks.push(api.put(`/servers/${props.id}/name`, { name: trimmedName }));
    }
    if (trimmedDesc !== initial.value.description) {
      tasks.push(api.put(`/servers/${props.id}/description`, { description: trimmedDesc }));
    }
    if (form.value.isPrivate !== initial.value.isPrivate) {
      tasks.push(
        api.put(`/servers/${props.id}/settings`, { isPrivate: form.value.isPrivate })
      );
    }
    if (avatarFile.value) {
      const fd = new FormData();
      fd.append('avatar', avatarFile.value, avatarFile.value.name);
      tasks.push(
        api.put(`/servers/${props.id}/avatar`, fd, {
          headers: { 'Content-Type': 'multipart/form-data' },
        })
      );
    }

    await Promise.all(tasks);
    toast.success({ title: 'Server settings updated.' });
    await appStore.fetchMyServers(true);
    router.back();
  } catch (err) {
    toast.error(apiErrorToast(err));
  } finally {
    isSaving.value = false;
  }
}

function cancel() {
  if (window.history.length > 1) router.back();
  else void router.push({ name: 'home' });
}

function confirmDelete() {
  $q.dialog({
    title: 'Delete server?',
    message: 'This will permanently delete the server, all its posts, comments, and members. This cannot be undone.',
    cancel: true,
    persistent: true,
    ok: { label: 'Delete', color: 'negative', flat: false, unelevated: true, noCaps: true },
  }).onOk(() => {
    void (async () => {
      try {
        await api.delete(`/servers/${props.id}`);
        toast.success({ title: 'Server deleted.' });
        await appStore.fetchMyServers(true);
        await router.push({ name: 'home' });
      } catch (err) {
        toast.error(apiErrorToast(err));
      }
    })();
  });
}
</script>

<style lang="scss" scoped>
.settings-page {
  min-height: 100dvh;
  background: #F8F9FA;
  padding-bottom: 88px; /* clear bottom tab nav */
}

.ess-header {
  position: sticky;
  top: 0;
  z-index: 5;
  background: #fff;
  height: 56px;
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding: 0 16px;
  border-bottom: 1px solid #E9ECEF;
  padding-top: env(safe-area-inset-top, 0px);
}

.header-link {
  background: transparent;
  border: 0;
  font-family: inherit;
  font-size: 15px;
  font-weight: 500;
  color: #495057;
  cursor: pointer;
  padding: 8px 0;

  &.primary {
    color: #007BFF;
    font-weight: 600;

    &:disabled {
      color: #ADB5BD;
      cursor: default;
    }
  }
}

.ess-title {
  font-size: 16px;
  font-weight: 600;
  letter-spacing: -0.01em;
  margin: 0;
  color: #212529;
}

/* Avatar */
.avatar-section {
  background: #fff;
  padding: 24px 0 20px;
  display: flex;
  flex-direction: column;
  align-items: center;
  border-bottom: 1px solid #F1F3F5;
}

.avatar-btn {
  position: relative;
  width: 96px;
  height: 96px;
  border-radius: 50%;
  border: 0;
  background: #F1F3F5;
  cursor: pointer;
  overflow: hidden;
  padding: 0;

  img {
    width: 100%;
    height: 100%;
    object-fit: cover;
  }

  .avatar-fallback {
    width: 100%;
    height: 100%;
    display: flex;
    align-items: center;
    justify-content: center;
    font-size: 36px;
    font-weight: 800;
    color: #007BFF;
    background: #E7F1FF;
  }

  .avatar-edit {
    position: absolute;
    right: 4px;
    bottom: 4px;
    width: 28px;
    height: 28px;
    border-radius: 50%;
    background: #007BFF;
    color: #fff;
    display: flex;
    align-items: center;
    justify-content: center;
    border: 2px solid #fff;
  }
}

.change-icon-link {
  margin-top: 12px;
  background: transparent;
  border: 0;
  color: #007BFF;
  font-size: 14px;
  font-weight: 500;
  cursor: pointer;
  font-family: inherit;
}

.hidden-input {
  display: none;
}

/* Sections */
.settings-section {
  padding: 20px;
  background: transparent;
}

.section-label {
  font-size: 11px;
  font-weight: 600;
  letter-spacing: 0.08em;
  color: #6C757D;
  margin: 0 4px 8px;
}

.ess-input :deep(.q-field__control) {
  border-radius: 12px;
  background: #fff;
  min-height: 48px;

  &::before {
    border-color: #E9ECEF;
  }
}

.ess-textarea :deep(textarea) {
  min-height: 96px;
}

.toggle-row {
  background: #fff;
  border-radius: 12px;
  padding: 14px 16px;
  display: flex;
  align-items: center;
  gap: 16px;
  border: 1px solid #F1F3F5;
  margin-bottom: 8px;

  &.disabled {
    opacity: 0.7;
  }
}

.toggle-text {
  flex: 1;
  min-width: 0;
}

.toggle-title {
  font-size: 15px;
  font-weight: 600;
  color: #212529;
  letter-spacing: -0.01em;
}

.toggle-help {
  font-size: 12px;
  color: #6C757D;
  margin-top: 2px;
}

.mgmt-row {
  width: 100%;
  background: #fff;
  border: 1px solid #F1F3F5;
  border-radius: 12px;
  padding: 12px 14px;
  display: flex;
  align-items: center;
  gap: 12px;
  cursor: pointer;
  font-family: inherit;
  margin-bottom: 8px;
  text-align: left;

  &:disabled {
    cursor: default;
    opacity: 0.7;
  }
}

.mgmt-icon {
  width: 36px;
  height: 36px;
  border-radius: 10px;
  display: flex;
  align-items: center;
  justify-content: center;
  flex-shrink: 0;
}

.mgmt-text {
  flex: 1;
  display: flex;
  flex-direction: column;
}

.mgmt-title {
  font-size: 14px;
  font-weight: 600;
  color: #212529;
}

.mgmt-help {
  font-size: 12px;
  color: #6C757D;
  margin-top: 2px;
}

.mgmt-chevron {
  color: #ADB5BD;
}

.danger {
  display: flex;
  flex-direction: column;
  align-items: center;
}

.danger-btn {
  background: transparent;
  border: 1px solid #FECACA;
  color: #DC3545;
  border-radius: 12px;
  padding: 12px 20px;
  font-size: 14px;
  font-weight: 600;
  cursor: pointer;
  font-family: inherit;
  display: inline-flex;
  align-items: center;
  gap: 8px;

  &:hover {
    background: #FEF2F2;
  }
}

.state-block {
  display: flex;
  align-items: center;
  justify-content: center;
  padding: 48px 0;
}

.empty-text {
  color: #6C757D;
  font-size: 14px;
}
</style>
