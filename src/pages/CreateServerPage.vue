<template>
  <q-page class="create-server-page">
    <!-- Top bar -->
    <header class="cs-header">
      <button class="icon-btn" type="button" @click="goBack">
        <ChevronLeft :size="24" />
      </button>
      <h1 class="cs-title">Create Server</h1>
      <span class="cs-spacer"></span>
    </header>

    <q-form class="cs-form" @submit.prevent="submit">
      <!-- Avatar uploader -->
      <div class="avatar-section">
        <button class="avatar-uploader" type="button" @click="pickAvatar">
          <img v-if="avatarPreview" :src="avatarPreview" alt="" class="avatar-preview" />
          <ImageIcon v-else :size="36" :stroke-width="1.6" class="avatar-placeholder-icon" />
        </button>
        <input
          ref="avatarInput"
          type="file"
          :accept="ALLOWED_TYPES.join(',')"
          class="hidden-input"
          @change="onAvatarSelected"
        />
        <div class="avatar-meta">
          <span class="meta-title">Server Icon <span class="meta-optional">(optional)</span></span>
          <span class="meta-help">PNG, JPG min 512px</span>
        </div>
      </div>

      <!-- Server name -->
      <FieldLabel label="Server name" required :count="`${form.name.length}/40`" />
      <q-input
        v-model="form.name"
        outlined
        dense
        maxlength="40"
        placeholder="Enter server name…"
        class="cs-input"
        :rules="[(v: string) => !!v?.trim() || 'Server name is required']"
        lazy-rules="ondemand"
        hide-bottom-space
      />

      <!-- Short name -->
      <FieldLabel label="Short name" required :count="`${form.shortName.length}/10`" />
      <q-input
        v-model="form.shortName"
        outlined
        dense
        maxlength="10"
        placeholder="Server abbreviation"
        class="cs-input"
        :rules="[(v: string) => !!v?.trim() || 'Short name is required']"
        lazy-rules="ondemand"
        hide-bottom-space
      />
      <p class="field-help">Server abbreviation for display</p>

      <!-- Category -->
      <FieldLabel label="Category" required />
      <q-select
        v-model="form.categoryId"
        outlined
        dense
        emit-value
        map-options
        :options="categoryOptions"
        :loading="isLoadingCategories"
        placeholder="Select category…"
        class="cs-input"
        :rules="[(v: number | null) => (!!v && v > 0) || 'Category is required']"
        lazy-rules="ondemand"
        hide-bottom-space
      />

      <!-- Description -->
      <FieldLabel label="Description" optional-tag :count="`${form.description.length}/150`" />
      <q-input
        v-model="form.description"
        outlined
        type="textarea"
        rows="3"
        maxlength="150"
        placeholder="Tell us a bit about this server…"
        class="cs-input cs-textarea"
        hide-bottom-space
      />

      <!-- Privacy -->
      <FieldLabel label="Privacy" />
      <div class="privacy-grid">
        <button
          type="button"
          class="privacy-card"
          :class="{ active: !form.isPrivate }"
          @click="form.isPrivate = false"
        >
          <span class="privacy-radio" :class="{ checked: !form.isPrivate }">
            <Check v-if="!form.isPrivate" :size="12" :stroke-width="3" />
          </span>
          <Globe :size="22" class="privacy-icon" />
          <div class="privacy-name">Public</div>
          <div class="privacy-help">Visible in global search</div>
        </button>

        <button
          type="button"
          class="privacy-card"
          :class="{ active: form.isPrivate }"
          @click="form.isPrivate = true"
        >
          <span class="privacy-radio" :class="{ checked: form.isPrivate }">
            <Check v-if="form.isPrivate" :size="12" :stroke-width="3" />
          </span>
          <Lock :size="22" class="privacy-icon" />
          <div class="privacy-name">Private</div>
          <div class="privacy-help">Invite only</div>
        </button>
      </div>

    </q-form>

    <!-- Floating submit button -->
    <footer class="cs-footer">
      <VButton
        type="button"
        label="Create Server"
        color="primary"
        class="full-width text-subtitle1"
        :disable="!canSubmit"
        :loading="isSubmitting"
        @click="submit"
      />
    </footer>
  </q-page>
</template>

<script setup lang="ts">
import { ref, computed, onMounted, h, defineComponent } from 'vue';
import type { PropType } from 'vue';
import { useRouter, useRoute } from 'vue-router';
import { AxiosError } from 'axios';
import {
  ChevronLeft, Image as ImageIcon, Globe, Lock, Check,
} from 'lucide-vue-next';
import { api } from 'src/boot/axios';
import { useAppStore } from 'src/stores/app.store';
import { useToast } from 'src/composables/useToast';
import { normalizeError } from 'src/composables/useApiError';
import VButton from 'src/components/VButton.vue';

interface ServerCategory {
  id: number;
  categoryName: string;
}

interface CategoriesResponse {
  data: ServerCategory[];
  page: { nextCursor: string | null; limit: number };
}

const ALLOWED_TYPES = ['image/jpeg', 'image/jpg', 'image/png', 'image/webp'];
const MAX_FILE_SIZE_MB = 5;

const router = useRouter();
const route = useRoute();
const appStore = useAppStore();
const toast = useToast();

const isOnboarding = computed(() => route.meta.onboardingFlow === true);

const avatarInput = ref<HTMLInputElement | null>(null);
const avatarPreview = ref<string | null>(null);
const avatarFile = ref<File | null>(null);
const isSubmitting = ref(false);
const isLoadingCategories = ref(false);

const categories = ref<ServerCategory[]>([]);

const form = ref({
  name: '',
  shortName: '',
  categoryId: null as number | null,
  description: '',
  isPrivate: false,
});

const categoryOptions = computed(() =>
  categories.value.map((c) => ({ label: c.categoryName, value: c.id }))
);

const canSubmit = computed(() => {
  return (
    form.value.name.trim().length > 0 &&
    form.value.shortName.trim().length > 0 &&
    !!form.value.categoryId &&
    form.value.categoryId > 0
  );
});

/* ─── Inline mini-component for field label + counter ──────────── */
const FieldLabel = defineComponent({
  name: 'FieldLabel',
  props: {
    label: { type: String, required: true },
    required: { type: Boolean, default: false },
    optionalTag: { type: Boolean, default: false },
    count: { type: String as PropType<string | undefined>, default: undefined },
  },
  setup(props) {
    return () =>
      h('div', { class: 'field-label-row' }, [
        h('span', { class: 'field-label' }, [
          props.label.toUpperCase(),
          props.required ? h('span', { class: 'field-required' }, ' *') : null,
          props.optionalTag ? h('span', { class: 'field-optional' }, ' (OPTIONAL)') : null,
        ]),
        props.count ? h('span', { class: 'field-count' }, props.count) : null,
      ]);
  },
});

/* ─── Lifecycle ─────────────────────────────────────────────── */
onMounted(loadCategories);

async function loadCategories() {
  isLoadingCategories.value = true;
  try {
    const res = await api.get<CategoriesResponse>('/servers/categories', {
      params: { limit: 20 },
    });
    categories.value = res.data?.data ?? [];
  } catch {
    toast.error('Failed to load categories.');
  } finally {
    isLoadingCategories.value = false;
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
    toast.error('Unsupported format. Use JPEG, PNG, or WebP.');
    return;
  }

  const sizeMB = file.size / (1024 * 1024);
  if (sizeMB > MAX_FILE_SIZE_MB) {
    toast.error(`Icon must be smaller than ${MAX_FILE_SIZE_MB}MB.`);
    return;
  }

  avatarFile.value = file;

  const reader = new FileReader();
  reader.onload = (e) => {
    avatarPreview.value = (e.target?.result as string) ?? null;
  };
  reader.readAsDataURL(file);
}

async function submit() {
  if (!canSubmit.value || isSubmitting.value) return;

  isSubmitting.value = true;
  try {
    const fd = new FormData();
    fd.append('name', form.value.name.trim());
    fd.append('shortName', form.value.shortName.trim());
    fd.append('categoryId', String(form.value.categoryId));
    fd.append('description', form.value.description.trim());
    fd.append('isPrivate', String(form.value.isPrivate));
    if (avatarFile.value) {
      fd.append('avatar', avatarFile.value, avatarFile.value.name);
    }

    await api.post('/servers/create', fd, {
      headers: { 'Content-Type': 'multipart/form-data' },
    });

    toast.success('Server created successfully.');

    // Refresh server list so the new server is selectable / guard passes.
    await appStore.fetchMyServers(true);

    await router.push({ name: 'home' });
  } catch (err) {
    if (err instanceof AxiosError || err instanceof Error) {
      const norm = normalizeError(err);
      toast.error(norm.message);
    }
  } finally {
    isSubmitting.value = false;
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
.create-server-page {
  min-height: 100dvh;
  background: #F8F9FA;
  padding-bottom: 88px; /* clear bottom tab nav */
}

.cs-header {
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

.cs-title {
  flex: 1;
  text-align: center;
  font-size: 17px;
  font-weight: 600;
  letter-spacing: -0.01em;
  margin: 0;
  color: #212529;
}

.cs-spacer {
  width: 40px;
  height: 40px;
}

.cs-form {
  padding: 24px 20px 120px; /* room for floating submit */
  display: flex;
  flex-direction: column;
}

.cs-footer {
  position: fixed;
  bottom: 0;
  left: 50%;
  transform: translateX(-50%);
  width: 100%;
  max-width: 480px;
  background: rgba(255, 255, 255, 0.96);
  backdrop-filter: blur(8px);
  border-top: 1px solid #F1F3F5;
  padding: 12px 20px calc(env(safe-area-inset-bottom, 0px) + 16px);
  z-index: 10;
}

/* Avatar */
.avatar-section {
  display: flex;
  flex-direction: column;
  align-items: center;
  margin-bottom: 28px;
}

.avatar-uploader {
  position: relative;
  width: 96px;
  height: 96px;
  border-radius: 18px;
  border: 1.5px dashed #ADB5BD;
  background: #fff;
  display: flex;
  align-items: center;
  justify-content: center;
  cursor: pointer;
  overflow: hidden;
  padding: 0;

  &:hover {
    border-color: #007BFF;
  }
}

.avatar-preview {
  width: 100%;
  height: 100%;
  object-fit: cover;
}

.avatar-placeholder-icon {
  color: #ADB5BD;
}

.hidden-input {
  display: none;
}

.avatar-meta {
  text-align: center;
  margin-top: 12px;

  .meta-title {
    display: block;
    font-size: 14px;
    font-weight: 600;
    color: #212529;
  }

  .meta-optional {
    color: #6C757D;
    font-weight: 400;
  }

  .meta-help {
    display: block;
    font-size: 12px;
    color: #ADB5BD;
    margin-top: 2px;
  }
}

/* Field label rows */
:deep(.field-label-row) {
  display: flex;
  justify-content: space-between;
  align-items: baseline;
  margin: 16px 0 6px;
}

:deep(.field-label) {
  font-size: 12px;
  font-weight: 600;
  letter-spacing: 0.06em;
  color: #495057;
}

:deep(.field-required) {
  color: #DC3545;
}

:deep(.field-count) {
  font-size: 11px;
  color: #ADB5BD;
}

:deep(.field-optional) {
  color: #ADB5BD;
  font-weight: 500;
}

.field-help {
  font-size: 12px;
  color: #ADB5BD;
  margin: 4px 4px 0;
}

.cs-input :deep(.q-field__control) {
  border-radius: 12px;
  background: #fff;
  min-height: 48px;

  &::before {
    border-color: #E9ECEF;
  }
}

.cs-textarea :deep(textarea) {
  padding: 4px 0;
  min-height: 84px;
  resize: vertical;
}

/* Privacy */
.privacy-grid {
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: 12px;
}

.privacy-card {
  position: relative;
  background: #fff;
  border: 1.5px solid #E9ECEF;
  border-radius: 14px;
  padding: 18px 14px 14px;
  text-align: left;
  cursor: pointer;
  font-family: inherit;
  display: flex;
  flex-direction: column;
  gap: 4px;
  transition: border-color 0.15s ease, background 0.15s ease;

  &:hover {
    border-color: #6C63FF;
  }

  &.active {
    border-color: #6C63FF;
    background: #EEF0FF;

    .privacy-icon,
    .privacy-name {
      color: #6C63FF;
    }
  }
}

.privacy-radio {
  position: absolute;
  top: 12px;
  right: 12px;
  width: 18px;
  height: 18px;
  border-radius: 50%;
  border: 1.5px solid #DEE2E6;
  display: flex;
  align-items: center;
  justify-content: center;
  background: #fff;

  &.checked {
    background: #6C63FF;
    border-color: #6C63FF;
    color: #fff;
  }
}

.privacy-icon {
  color: #495057;
}

.privacy-name {
  font-size: 15px;
  font-weight: 600;
  color: #212529;
}

.privacy-help {
  font-size: 12px;
  color: #6C757D;
}
</style>
