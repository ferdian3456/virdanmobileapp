<template>
  <q-page class="your-profile-page">
    <!-- Top bar -->
    <header class="yp-header">
      <button class="icon-btn" type="button" @click="goBack">
        <ChevronLeft :size="24" />
      </button>
      <h1 class="yp-title">Your Profile</h1>
      <span class="yp-spacer"></span>
    </header>

    <q-form class="yp-form" @submit.prevent="submit">
      <!-- Avatar uploader -->
      <div class="avatar-section">
        <button class="avatar-uploader" type="button" @click="pickAvatar">
          <img v-if="profileAvatarPreview" :src="profileAvatarPreview" alt="" class="avatar-preview" />
          <span v-else class="avatar-letter">{{ avatarLetter }}</span>
        </button>
        <input
          ref="avatarInput"
          type="file"
          :accept="ALLOWED_TYPES.join(',')"
          class="hidden-input"
          @change="onAvatarSelected"
        />
        <div class="avatar-meta">
          <span class="meta-title">Profile Photo</span>
          <span class="meta-help">PNG / JPG, max 5MB</span>
        </div>
      </div>

      <!-- Profile picker (hidden if no history) -->
      <template v-if="profileHistory.length > 0">
        <FieldLabel label="Profile" optional-tag />
        <q-select
          outlined
          dense
          emit-value
          map-options
          :options="pickerOptions"
          :loading="isLoadingHistory"
          :model-value="pickedProfileId"
          placeholder="Choose profile..."
          class="yp-input"
          hide-bottom-space
          @update:model-value="(val: string) => {
            const opt = pickerOptions.find((o) => o.value === val);
            if (opt) onPickerChange(opt);
          }"
        >
          <template #option="scope">
            <q-item v-bind="scope.itemProps">
              <q-item-section avatar v-if="scope.opt.raw?.avatarImageUrl">
                <q-avatar size="32px">
                  <img :src="scope.opt.raw.avatarImageUrl" alt="" />
                </q-avatar>
              </q-item-section>
              <q-item-section>
                <q-item-label>{{ scope.opt.label }}</q-item-label>
                <q-item-label caption>{{ scope.opt.sublabel }}</q-item-label>
              </q-item-section>
            </q-item>
          </template>
        </q-select>
        <p class="field-help">Pick a profile from another server to copy</p>
      </template>

      <!-- Nickname -->
      <FieldLabel label="Nickname" required :count="`${form.nickname.length}/50`" />
      <q-input
        v-model="form.nickname"
        outlined
        dense
        maxlength="50"
        placeholder="How you appear on this server"
        class="yp-input"
        hide-bottom-space
      />
      <p class="field-help">How other members see you</p>

      <!-- Bio -->
      <FieldLabel label="Bio" optional-tag :count="`${form.bio.length}/150`" />
      <q-input
        v-model="form.bio"
        outlined
        type="textarea"
        rows="3"
        maxlength="150"
        placeholder="Tell us a bit about yourself..."
        class="yp-input yp-textarea"
        hide-bottom-space
      />
      <p class="field-help">Shown on your profile card and member list</p>
    </q-form>

    <!-- Floating submit button -->
    <footer class="yp-footer">
      <VButton
        type="button"
        label="Save Profile"
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
import { ChevronLeft } from 'lucide-vue-next';
import { api } from 'src/boot/axios';
import { AxiosError } from 'axios';
import { useServerCreateStore } from 'src/stores/server-create.store';
import { useToast } from 'src/composables/useToast';
import { normalizeError } from 'src/composables/useApiError';
import { useAppStore } from 'src/stores/app.store';
import VButton from 'src/components/VButton.vue';

const ALLOWED_TYPES = ['image/jpeg', 'image/jpg', 'image/png', 'image/webp'];
const MAX_FILE_SIZE_MB = 5;

interface ProfileHistoryItem {
  profileId: string;
  serverId: string;
  serverName: string;
  nickname: string;
  bio: string | null;
  avatarImageId: string | null;
  avatarImageUrl: string | null;
  isStillMember: boolean;
}

interface ProfileHistoryResponse {
  data: ProfileHistoryItem[];
}

const router = useRouter();
const route = useRoute();
const serverCreateStore = useServerCreateStore();
const appStore = useAppStore();
const toast = useToast();

const isOnboarding = computed(() => route.meta.onboardingFlow === true);

const avatarInput = ref<HTMLInputElement | null>(null);
const profileAvatarFile = ref<File | null>(null);
const profileAvatarPreview = ref<string | null>(null);
const isSubmitting = ref(false);

const form = ref({
  nickname: '',
  bio: '',
});

const profileHistory = ref<ProfileHistoryItem[]>([]);
const isLoadingHistory = ref(false);
const pickedAvatarImageId = ref<string | null>(null);
const pickedProfileId = ref<string | null>(null);

const avatarLetter = computed(() => {
  const ch = form.value.nickname.trim().charAt(0);
  return ch ? ch.toUpperCase() : 'A';
});

const canSubmit = computed(() => {
  const n = form.value.nickname.trim();
  return n.length >= 3 && n.length <= 50;
});

const pickerOptions = computed(() => {
  const items = profileHistory.value.map((p) => ({
    label: `${p.serverName} — ${p.nickname}`,
    sublabel: p.isStillMember ? 'Active member' : 'Left server',
    value: p.profileId,
    raw: p,
  }));
  return [
    { label: 'Clear selection', sublabel: '', value: '__clear__', raw: null },
    ...items,
  ];
});

function onPickerChange(opt: { value: string; raw: ProfileHistoryItem | null }) {
  if (opt.value === '__clear__' || !opt.raw) {
    pickedAvatarImageId.value = null;
    pickedProfileId.value = null;
    profileAvatarPreview.value = null;
    return;
  }
  const item = opt.raw;
  pickedProfileId.value = item.profileId;
  pickedAvatarImageId.value = item.avatarImageId;
  profileAvatarPreview.value = item.avatarImageUrl;
  profileAvatarFile.value = null;
  form.value.nickname = item.nickname;
  form.value.bio = item.bio ?? '';
}

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
onMounted(() => {
  if (!serverCreateStore.draft) {
    toast.error({ title: 'Missing server data. Please restart.' });
    void router.replace({
      name: isOnboarding.value ? 'onboarding-create-server' : 'create-server',
    });
    return;
  }
  void loadProfileHistory();
});

async function loadProfileHistory() {
  isLoadingHistory.value = true;
  try {
    const res = await api.get<ProfileHistoryResponse>('/profiles/history');
    profileHistory.value = res.data?.data ?? [];
  } catch {
    profileHistory.value = [];
  } finally {
    isLoadingHistory.value = false;
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
    toast.error({ title: `Avatar must be smaller than ${MAX_FILE_SIZE_MB}MB.` });
    return;
  }

  profileAvatarFile.value = file;
  pickedAvatarImageId.value = null;
  pickedProfileId.value = null;
  const reader = new FileReader();
  reader.onload = (e) => {
    profileAvatarPreview.value = (e.target?.result as string) ?? null;
  };
  reader.readAsDataURL(file);
}

async function submit() {
  if (!canSubmit.value || isSubmitting.value) return;
  const draft = serverCreateStore.draft;
  if (!draft) {
    toast.error({ title: 'Missing server data. Please restart create flow.' });
    void router.replace({
      name: isOnboarding.value ? 'onboarding-create-server' : 'create-server',
    });
    return;
  }

  isSubmitting.value = true;
  try {
    const fd = new FormData();
    fd.append('name', draft.name);
    fd.append('shortName', draft.shortName);
    fd.append('categoryId', String(draft.categoryId));
    fd.append('description', draft.description);
    fd.append('isPrivate', String(draft.isPrivate));
    if (draft.serverAvatarFile) {
      fd.append('serverAvatar', draft.serverAvatarFile, draft.serverAvatarFile.name);
    }
    fd.append('nickname', form.value.nickname.trim());
    fd.append('bio', form.value.bio.trim());
    if (profileAvatarFile.value) {
      fd.append('profileAvatar', profileAvatarFile.value, profileAvatarFile.value.name);
    } else if (pickedAvatarImageId.value) {
      fd.append('avatarImageId', pickedAvatarImageId.value);
    }

    await api.post('/servers/create', fd, {
      headers: { 'Content-Type': 'multipart/form-data' },
    });

    toast.success({ title: 'Server created successfully.' });
    serverCreateStore.clearDraft();
    await appStore.fetchMyServers(true);
    await router.push({ name: 'home' });
  } catch (err) {
    if (err instanceof AxiosError || err instanceof Error) {
      const norm = normalizeError(err);
      toast.error({ title: norm.message });
    }
  } finally {
    isSubmitting.value = false;
  }
}

function goBack() {
  router.back();
}
</script>

<style lang="scss" scoped>
.your-profile-page {
  min-height: 100dvh;
  background: #F8F9FA;
  padding-bottom: 88px;
}

.yp-header {
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

  &:hover { background: #F1F3F5; }
}

.yp-title {
  flex: 1;
  text-align: center;
  font-size: 17px;
  font-weight: 600;
  letter-spacing: -0.01em;
  margin: 0;
  color: #212529;
}

.yp-spacer { width: 40px; height: 40px; }

.yp-form {
  padding: 24px 20px 120px;
  display: flex;
  flex-direction: column;
}

.yp-footer {
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
  border-radius: 50%;
  border: 1.5px dashed #ADB5BD;
  background: #fff;
  display: flex;
  align-items: center;
  justify-content: center;
  cursor: pointer;
  overflow: hidden;
  padding: 0;

  &:hover { border-color: #007BFF; }
}

.avatar-preview {
  width: 100%;
  height: 100%;
  object-fit: cover;
}

.avatar-letter {
  font-size: 40px;
  font-weight: 700;
  color: #007BFF;
}

.hidden-input { display: none; }

.avatar-meta {
  text-align: center;
  margin-top: 12px;

  .meta-title {
    display: block;
    font-size: 14px;
    font-weight: 600;
    color: #212529;
  }
  .meta-help {
    display: block;
    font-size: 12px;
    color: #ADB5BD;
    margin-top: 2px;
  }
}

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
:deep(.field-required) { color: #DC3545; }
:deep(.field-count) { font-size: 11px; color: #ADB5BD; }
:deep(.field-optional) { color: #ADB5BD; font-weight: 500; }

.field-help {
  font-size: 12px;
  color: #ADB5BD;
  margin: 4px 4px 0;
}

.yp-input :deep(.q-field__control) {
  border-radius: 12px;
  background: #fff;
  min-height: 48px;

  &::before { border-color: #E9ECEF; }
}

.yp-textarea :deep(textarea) {
  padding: 4px 0;
  min-height: 84px;
  resize: vertical;
}
</style>
