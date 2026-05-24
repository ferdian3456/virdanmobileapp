<template>
  <q-page class="settings-page">
    <header class="st-header">
      <button class="icon-btn" type="button" @click="goBack">
        <ChevronLeft :size="24" />
      </button>
      <h1 class="st-title">Settings</h1>
      <span class="icon-btn"></span>
    </header>

    <!-- Profile summary (per-server identity) -->
    <section class="profile-summary">
      <div class="ps-avatar">
        <img v-if="profile?.avatarUrl" :src="profile.avatarUrl" :alt="profile.nickname" />
        <span v-else>{{ summaryInitial }}</span>
      </div>
      <div class="ps-meta">
        <div class="ps-name">{{ profile?.nickname || user?.email || '—' }}</div>
        <div v-if="profile?.username" class="ps-handle">@{{ profile.username }}</div>
      </div>
    </section>

    <SettingsSection title="ACCOUNT">
      <SettingsRow icon="user" label="Edit Profile" @click="goEditProfile" />
      <SettingsRow icon="mail" label="Change Email" @click="goChangeEmail" />
      <SettingsRow icon="lock" label="Change Password" @click="goChangePassword" />
      <SettingsRow icon="shield" label="Privacy &amp; Security" @click="goPrivacySecurity" />
      <SettingsRow icon="ban" label="Blocked Users" badge="3" disabled />
    </SettingsSection>

    <SettingsSection title="PREFERENCES">
      <SettingsRow icon="globe" label="Language" value="English" disabled />
      <SettingsRow icon="sun" label="Theme" value="Light" disabled />
    </SettingsSection>

    <SettingsSection title="NOTIFICATIONS">
      <SettingsRow icon="bell" label="Notification Settings" @click="goNotificationSettings" />
    </SettingsSection>

    <SettingsSection title="ABOUT &amp; SUPPORT">
      <SettingsRow icon="help" label="Help Center" @click="goHelpCenter" />
      <SettingsRow icon="file" label="Terms of Service" @click="goTermsOfService" />
      <SettingsRow icon="shield-check" label="Privacy Policy" @click="goPrivacyPolicy" />
    </SettingsSection>

    <!-- Logout -->
    <section class="logout-section">
      <button class="logout-btn" type="button" :disabled="isLoggingOut" @click="logout">
        <LogOut :size="18" />
        {{ isLoggingOut ? 'Signing out…' : 'Sign Out' }}
      </button>
    </section>

  </q-page>
</template>

<script setup lang="ts">
import { ref, computed, onMounted, watch, defineComponent, h, type PropType } from 'vue';
import { useRouter } from 'vue-router';
import {
  ChevronLeft, ChevronRight, LogOut,
  User, Mail, Lock, Shield, Ban, Globe, Sun, Bell, CircleHelp, FileText, ShieldCheck,
} from 'lucide-vue-next';
import { storeToRefs } from 'pinia';
import { api } from 'src/boot/axios';
import { useAuthStore } from 'src/stores/auth.store';
import { useAppStore } from 'src/stores/app.store';
import { useToast } from 'src/composables/useToast';

interface ServerProfileMeResponse {
  profileId: string;
  serverId: string;
  nickname: string;
  username: string;
  bio: string | null;
  avatarImageId: string | null;
  avatarUrl: string | null;
  createdAt: string;
  updatedAt: string;
}

const router = useRouter();
const authStore = useAuthStore();
const appStore = useAppStore();
const { activeServerId } = storeToRefs(appStore);
const toast = useToast();

const user = computed(() => authStore.user);
const profile = ref<ServerProfileMeResponse | null>(null);
const isLoggingOut = ref(false);

const summaryInitial = computed(() => {
  const src = profile.value?.nickname || user.value?.email || '?';
  return src.charAt(0).toUpperCase();
});

onMounted(async () => {
  await loadProfile();
});

watch(activeServerId, () => {
  void loadProfile();
});

async function loadProfile() {
  const sid = activeServerId.value;
  if (!sid) {
    profile.value = null;
    return;
  }
  try {
    const res = await api.get<ServerProfileMeResponse>(`/servers/${sid}/profile/me`);
    profile.value = res.data;
  } catch {
    profile.value = null;
  }
}

function goEditProfile() {
  void router.push({ name: 'edit-profile' });
}

function goChangePassword() {
  void router.push({ name: 'change-password' });
}

function goChangeEmail() {
  void router.push({ name: 'change-email' });
}

function goPrivacySecurity() {
  void router.push({ name: 'privacy-security' });
}

function goHelpCenter() {
  void router.push({ name: 'help-center' });
}

function goTermsOfService() {
  void router.push({ name: 'terms-of-service' });
}

function goPrivacyPolicy() {
  void router.push({ name: 'privacy-policy' });
}

function goNotificationSettings() {
  void router.push({ name: 'notification-settings' });
}

async function logout() {
  if (isLoggingOut.value) return;
  isLoggingOut.value = true;
  try {
    await authStore.logout();
    appStore.reset();
    await router.push({ name: 'login' });
  } catch {
    toast.error({ title: 'Failed to sign out. Please try again.' });
  } finally {
    isLoggingOut.value = false;
  }
}

function goBack() {
  if (window.history.length > 1) router.back();
  else void router.push({ name: 'home' });
}

/* ─── Inline section + row + label components ──────────── */
const SettingsSection = defineComponent({
  name: 'SettingsSection',
  props: { title: { type: String, required: true } },
  setup(p, { slots }) {
    return () =>
      h('section', { class: 'st-section' }, [
        h('h2', { class: 'st-section-title' }, p.title),
        h('div', { class: 'st-list' }, slots.default ? slots.default() : []),
      ]);
  },
});

const ICON_MAP = {
  user: User,
  mail: Mail,
  lock: Lock,
  shield: Shield,
  ban: Ban,
  globe: Globe,
  sun: Sun,
  bell: Bell,
  help: CircleHelp,
  file: FileText,
  'shield-check': ShieldCheck,
} as const;

type IconName = keyof typeof ICON_MAP;

const SettingsRow = defineComponent({
  name: 'SettingsRow',
  props: {
    icon: { type: String as PropType<IconName>, required: true },
    label: { type: String, required: true },
    value: { type: String as PropType<string | undefined>, default: undefined },
    badge: { type: String as PropType<string | undefined>, default: undefined },
    disabled: { type: Boolean, default: false },
  },
  emits: ['click'],
  setup(p, { emit }) {
    return () => {
      const Icon = ICON_MAP[p.icon];
      return h(
        'button',
        {
          class: ['st-row', p.disabled ? 'disabled' : ''],
          type: 'button',
          onClick: () => {
            if (!p.disabled) emit('click');
          },
        },
        [
          h('span', { class: 'st-row-icon' }, [
            h(Icon, { size: 20, 'stroke-width': 1.8 }),
          ]),
          h('span', { class: 'st-row-label' }, p.label),
          p.value
            ? h('span', { class: 'st-row-value' }, p.value)
            : p.badge
              ? h('span', { class: 'st-row-badge' }, p.badge)
              : null,
          h(ChevronRight, { size: 18, class: 'st-row-chevron' }),
        ]
      );
    };
  },
});

</script>

<style lang="scss" scoped>
.settings-page {
  min-height: 100dvh;
  background: #fff;
  padding-bottom: 32px;
}

.st-header {
  position: sticky;
  top: 0;
  z-index: 5;
  background: #fff;
  height: 56px;
  display: flex;
  align-items: center;
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

.st-title {
  flex: 1;
  text-align: center;
  font-size: 17px;
  font-weight: 600;
  letter-spacing: -0.01em;
  margin: 0;
  color: #0F172A;
}

/* Profile summary */
.profile-summary {
  padding: 16px 16px 12px;
  display: flex;
  align-items: center;
  gap: 14px;
  border-bottom: 1px solid #F1F3F5;
}

.ps-avatar {
  width: 52px;
  height: 52px;
  border-radius: 50%;
  background: #007BFF;
  color: #fff;
  font-weight: 700;
  font-size: 19px;
  display: flex;
  align-items: center;
  justify-content: center;
  overflow: hidden;
  flex-shrink: 0;

  img {
    width: 100%;
    height: 100%;
    object-fit: cover;
  }
}

.ps-meta {
  flex: 1;
  min-width: 0;
}

.ps-name {
  font-size: 15px;
  font-weight: 700;
  color: #0F172A;
  letter-spacing: -0.01em;
}

.ps-handle {
  font-size: 13px;
  color: #6C757D;
  margin-top: 2px;
}

/* Sections */
:deep(.st-section) {
  padding-top: 16px;
}

:deep(.st-section-title) {
  font-size: 11px;
  font-weight: 600;
  letter-spacing: 0.08em;
  color: #ADB5BD;
  margin: 0 16px 4px;
}

:deep(.st-list) {
  display: flex;
  flex-direction: column;
}

:deep(.st-row) {
  width: 100%;
  background: transparent;
  border: 0;
  padding: 12px 16px;
  display: flex;
  align-items: center;
  gap: 14px;
  font-family: inherit;
  cursor: pointer;
  text-align: left;
  color: inherit;
  /* Override browser default disabled-opacity so labels stay full-contrast. */
  opacity: 1 !important;

  &:disabled,
  &.disabled {
    cursor: default;

    .st-row-icon,
    .st-row-chevron {
      opacity: 0.7;
    }
  }

  &:hover:not(:disabled):not(.disabled) {
    background: #F8F9FA;
  }
}

:deep(.st-row-icon) {
  width: 24px;
  height: 24px;
  display: flex;
  align-items: center;
  justify-content: center;
  flex-shrink: 0;
  color: #495057;
}

:deep(.st-row-label) {
  flex: 1;
  font-size: 15px;
  font-weight: 500;
  color: #0F172A;
  letter-spacing: -0.01em;
}

:deep(.st-row-value) {
  font-size: 14px;
  color: #6C757D;
  margin-right: 4px;
}

:deep(.st-row-badge) {
  font-size: 13px;
  color: #6C757D;
  margin-right: 4px;
  font-weight: 500;
}

:deep(.st-row-chevron) {
  color: #ADB5BD;
}

/* Logout */
.logout-section {
  padding: 32px 16px;
  display: flex;
  justify-content: center;
}

.logout-btn {
  background: #fff;
  border: 1px solid #FECACA;
  color: #DC3545;
  border-radius: 12px;
  padding: 12px 24px;
  font-size: 14px;
  font-weight: 600;
  cursor: pointer;
  font-family: inherit;
  display: inline-flex;
  align-items: center;
  gap: 8px;

  &:hover:not(:disabled) {
    background: #FEF2F2;
  }

  &:disabled {
    opacity: 0.6;
    cursor: default;
  }
}

</style>
