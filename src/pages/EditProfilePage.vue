<template>
  <q-page class="ep-page">
    <header class="ep-header">
      <button class="icon-btn" type="button" @click="goBack">
        <ChevronLeft :size="24" />
      </button>
      <h1 class="ep-title">Edit Profile</h1>
      <span class="icon-btn"></span>
    </header>

    <SettingsFormSkeleton v-if="loading" />

    <template v-else>
      <!-- Avatar -->
      <section class="avatar-section">
        <button class="avatar-btn" type="button" @click="pickAvatar">
          <img v-if="avatarPreview" :src="avatarPreview" alt="" />
          <img v-else-if="user?.avatarImage" :src="user.avatarImage" alt="" />
          <span v-else class="avatar-fallback">{{ initial }}</span>
        </button>
        <input
          ref="avatarInput"
          type="file"
          :accept="ALLOWED_TYPES.join(',')"
          class="hidden-input"
          @change="onAvatarSelected"
        />
        <button class="change-photo-link" type="button" @click="pickAvatar">
          Change Profile Photo
        </button>
      </section>

      <!-- Display name -->
      <FieldRow label="Display name" :count="`${form.fullname.length}/30`">
        <q-input
          v-model="form.fullname"
          outlined
          dense
          maxlength="30"
          hide-bottom-space
          class="ep-input"
        />
      </FieldRow>

      <!-- Username -->
      <FieldRow label="Username">
        <q-input
          v-model="form.username"
          outlined
          dense
          maxlength="22"
          hide-bottom-space
          class="ep-input"
          prefix="@"
        />
        <p class="field-help">Unique across all servers</p>
      </FieldRow>

      <!-- Bio -->
      <FieldRow label="Bio" :count="`${form.bio.length}/150`">
        <q-input
          v-model="form.bio"
          outlined
          type="textarea"
          rows="3"
          maxlength="150"
          hide-bottom-space
          class="ep-input ep-textarea"
        />
      </FieldRow>

      <!-- Email (read-only — BE doesn't expose update endpoint yet) -->
      <FieldRow label="Email">
        <q-input
          v-model="form.email"
          outlined
          dense
          readonly
          hide-bottom-space
          class="ep-input ep-input-disabled"
        />
      </FieldRow>

      <!-- Phone number (mock — BE doesn't store phone) -->
      <FieldRow label="Phone number">
        <q-input
          v-model="form.phone"
          outlined
          dense
          readonly
          hide-bottom-space
          placeholder="—"
          class="ep-input ep-input-disabled"
        />
      </FieldRow>
    </template>

    <!-- Floating save button -->
    <footer v-if="!loading" class="ep-footer">
      <q-btn
        unelevated
        no-caps
        color="primary"
        label="Save"
        class="full-width ep-save-btn"
        :disable="!hasChanges"
        :loading="isSaving"
        @click="save"
      />
    </footer>
  </q-page>
</template>

<script setup lang="ts">
import { ref, computed, onMounted, defineComponent, h, type PropType } from 'vue';
import { useRouter } from 'vue-router';
import { ChevronLeft } from 'lucide-vue-next';
import { api } from 'src/boot/axios';
import { useAuthStore } from 'src/stores/auth.store';
import { useToast } from 'src/composables/useToast';
import { apiErrorToast } from 'src/composables/useApiError';
import SettingsFormSkeleton from 'src/components/feedback/skeletons/SettingsFormSkeleton.vue';

const ALLOWED_TYPES = ['image/jpeg', 'image/jpg', 'image/png', 'image/webp'];
const MAX_AVATAR_MB = 5;

const router = useRouter();
const authStore = useAuthStore();
const toast = useToast();

const user = computed(() => authStore.user);
const initial = computed(
  () => (user.value?.username ?? user.value?.fullname ?? '?').charAt(0).toUpperCase()
);

const loading = ref(false);
const isSaving = ref(false);

const form = ref({
  fullname: '',
  username: '',
  bio: '',
  email: '',
  phone: '',
});

const initial_state = ref({
  fullname: '',
  username: '',
  bio: '',
});

const avatarInput = ref<HTMLInputElement | null>(null);
const avatarFile = ref<File | null>(null);
const avatarPreview = ref<string | null>(null);

const hasChanges = computed(() => {
  if (avatarFile.value) return true;
  return (
    form.value.fullname.trim() !== initial_state.value.fullname ||
    form.value.username.trim() !== initial_state.value.username ||
    form.value.bio.trim() !== initial_state.value.bio
  );
});

onMounted(async () => {
  loading.value = true;
  try {
    if (!authStore.user) {
      await authStore.fetchUser();
    }
    if (authStore.user) {
      form.value.fullname = authStore.user.fullname ?? '';
      form.value.username = authStore.user.username ?? '';
      form.value.bio = authStore.user.bio ?? '';
      form.value.email = authStore.user.email ?? '';
      form.value.phone = '';
      initial_state.value = {
        fullname: form.value.fullname,
        username: form.value.username,
        bio: form.value.bio,
      };
    }
  } catch {
    toast.error({ title: 'Failed to load profile.' });
  } finally {
    loading.value = false;
  }
});

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
  if (sizeMB > MAX_AVATAR_MB) {
    toast.error({ title: `Avatar must be smaller than ${MAX_AVATAR_MB}MB.` });
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

    if (form.value.fullname.trim() !== initial_state.value.fullname) {
      tasks.push(api.put('/users/fullname', { fullname: form.value.fullname.trim() }));
    }
    if (form.value.username.trim() !== initial_state.value.username) {
      tasks.push(api.put('/users/username', { username: form.value.username.trim() }));
    }
    if (form.value.bio.trim() !== initial_state.value.bio) {
      tasks.push(api.put('/users/bio', { bio: form.value.bio.trim() }));
    }
    if (avatarFile.value) {
      const fd = new FormData();
      fd.append('avatar', avatarFile.value, avatarFile.value.name);
      tasks.push(
        api.put('/users/avatar', fd, {
          headers: { 'Content-Type': 'multipart/form-data' },
        })
      );
    }

    await Promise.all(tasks);
    await authStore.fetchUser();
    toast.success({ title: 'Profile updated.' });
    router.back();
  } catch (err) {
    toast.error(apiErrorToast(err));
  } finally {
    isSaving.value = false;
  }
}

function goBack() {
  if (window.history.length > 1) router.back();
  else void router.push({ name: 'settings' });
}

/* ─── Inline FieldRow component ────────────────────────── */
const FieldRow = defineComponent({
  name: 'FieldRow',
  props: {
    label: { type: String, required: true },
    count: { type: String as PropType<string | undefined>, default: undefined },
  },
  setup(p, { slots }) {
    return () =>
      h('div', { class: 'field-row' }, [
        h('div', { class: 'field-label-row' }, [
          h('label', { class: 'field-label' }, p.label.toUpperCase()),
          p.count ? h('span', { class: 'field-count' }, p.count) : null,
        ]),
        slots.default ? slots.default() : null,
      ]);
  },
});
</script>

<style lang="scss" scoped>
.ep-page {
  min-height: 100dvh;
  background: #fff;
  padding-bottom: 120px; /* room for floating save button */
}

.ep-header {
  position: sticky;
  top: 0;
  z-index: 5;
  background: #fff;
  height: 56px;
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding: 0 12px;
  border-bottom: 1px solid #F1F3F5;
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

.ep-title {
  flex: 1;
  text-align: center;
  font-size: 17px;
  font-weight: 600;
  letter-spacing: -0.01em;
  margin: 0;
  color: #0F172A;
}

.ep-footer {
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

.ep-save-btn {
  border-radius: 14px !important;
  min-height: 48px;
  font-weight: 600;
  letter-spacing: -0.01em;
}

/* Avatar */
.avatar-section {
  padding: 24px 0 16px;
  display: flex;
  flex-direction: column;
  align-items: center;
}

.avatar-btn {
  position: relative;
  width: 96px;
  height: 96px;
  border-radius: 50%;
  border: 0;
  background: #007BFF;
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
    color: #fff;
    letter-spacing: -0.02em;
  }

}

.hidden-input {
  display: none;
}

.change-photo-link {
  margin-top: 12px;
  background: transparent;
  border: 0;
  color: #007BFF;
  font-family: inherit;
  font-size: 14px;
  font-weight: 600;
  cursor: pointer;
}

/* Field rows */
:deep(.field-row) {
  padding: 12px 16px 4px;
}

:deep(.field-label-row) {
  display: flex;
  justify-content: space-between;
  align-items: baseline;
  margin-bottom: 6px;
}

:deep(.field-label) {
  font-size: 11px;
  font-weight: 600;
  letter-spacing: 0.08em;
  color: #6C757D;
}

:deep(.field-count) {
  font-size: 11px;
  color: #ADB5BD;
}

.field-help {
  font-size: 12px;
  color: #ADB5BD;
  margin: 4px 4px 0;
}

.ep-input :deep(.q-field__control) {
  border-radius: 12px;
  background: #fff;
  min-height: 44px;

  &::before {
    border-color: #DEE2E6;
  }
}

.ep-textarea :deep(textarea) {
  min-height: 80px;
}

.ep-input-disabled :deep(.q-field__control) {
  background: #F8F9FA;
  color: #6C757D;
}

.state-block {
  display: flex;
  align-items: center;
  justify-content: center;
  padding: 48px 0;
}
</style>
