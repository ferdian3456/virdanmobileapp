<template>
  <q-page class="ns-page">
    <header class="ns-header">
      <button class="icon-btn" type="button" @click="goBack">
        <ChevronLeft :size="24" />
      </button>
      <h1 class="ns-title">Notification Settings</h1>
      <span class="icon-btn"></span>
    </header>

    <!-- Master push toggle (no section title) -->
    <section class="ns-section ns-section--first">
      <ToggleRow
        :icon="Bell"
        label="Push Notifications"
        subtitle="Enable to receive notifications on this device."
        :model-value="prefs.push"
        @update:model-value="(v: boolean) => (prefs.push = v)"
      />
    </section>

    <SectionTitle>ACTIVITY</SectionTitle>
    <section class="ns-section">
      <ToggleRow
        label="Like"
        subtitle="When someone likes your post"
        :disabled="!prefs.push"
        :model-value="prefs.like"
        @update:model-value="(v: boolean) => (prefs.like = v)"
      />
      <ToggleRow
        label="Comment"
        subtitle="When someone comments on your post"
        :disabled="!prefs.push"
        :model-value="prefs.comment"
        @update:model-value="(v: boolean) => (prefs.comment = v)"
      />
      <ToggleRow
        label="Reply"
        subtitle="When someone replies to your comment"
        :disabled="!prefs.push"
        :model-value="prefs.reply"
        @update:model-value="(v: boolean) => (prefs.reply = v)"
      />
      <ToggleRow
        label="Mention"
        subtitle="When you are tagged or mentioned"
        :disabled="!prefs.push"
        :model-value="prefs.mention"
        @update:model-value="(v: boolean) => (prefs.mention = v)"
      />
    </section>

    <SectionTitle>SOCIAL</SectionTitle>
    <section class="ns-section">
      <ToggleRow
        label="New Followers"
        subtitle="When someone starts following you"
        :disabled="!prefs.push"
        :model-value="prefs.follower"
        @update:model-value="(v: boolean) => (prefs.follower = v)"
      />
      <ToggleRow
        label="Messages"
        subtitle="Direct messages from other users"
        :disabled="!prefs.push"
        :model-value="prefs.message"
        @update:model-value="(v: boolean) => (prefs.message = v)"
      />
    </section>

    <SectionTitle>SERVER</SectionTitle>
    <section class="ns-section">
      <ToggleRow
        label="Server Invites"
        subtitle="When you are invited to a server"
        :disabled="!prefs.push"
        :model-value="prefs.invite"
        @update:model-value="(v: boolean) => (prefs.invite = v)"
      />
    </section>

    <SectionTitle>EMAIL &amp; SOUND</SectionTitle>
    <section class="ns-section">
      <ToggleRow
        :icon="FileText"
        label="Email"
        subtitle="Weekly digest & important updates via email"
        :model-value="prefs.email"
        @update:model-value="(v: boolean) => (prefs.email = v)"
      />
      <ToggleRow
        :icon="Volume2"
        label="Notification Sound"
        subtitle="Play sound when notifications arrive"
        :disabled="!prefs.push"
        :model-value="prefs.sound"
        @update:model-value="(v: boolean) => (prefs.sound = v)"
      />
    </section>
  </q-page>
</template>

<script setup lang="ts">
import { reactive, watch, defineComponent, h, type PropType, type Component } from 'vue';
import { useRouter } from 'vue-router';
import { ChevronLeft, Bell, FileText, Volume2 } from 'lucide-vue-next';

const router = useRouter();

const STORAGE_KEY = 'virdan.notification-prefs.v1';

interface Prefs {
  push: boolean;
  like: boolean;
  comment: boolean;
  reply: boolean;
  mention: boolean;
  follower: boolean;
  message: boolean;
  invite: boolean;
  email: boolean;
  sound: boolean;
}

const defaultPrefs: Prefs = {
  push: true,
  like: true,
  comment: true,
  reply: true,
  mention: true,
  follower: true,
  message: true,
  invite: true,
  email: false,
  sound: true,
};

function loadPrefs(): Prefs {
  try {
    const raw = localStorage.getItem(STORAGE_KEY);
    if (raw) return { ...defaultPrefs, ...(JSON.parse(raw) as Partial<Prefs>) };
  } catch {
    // ignore corrupt storage
  }
  return { ...defaultPrefs };
}

const prefs = reactive<Prefs>(loadPrefs());

watch(
  prefs,
  () => {
    try {
      localStorage.setItem(STORAGE_KEY, JSON.stringify(prefs));
    } catch {
      // ignore quota errors
    }
  },
  { deep: true }
);

function goBack() {
  if (window.history.length > 1) router.back();
  else void router.push({ name: 'settings' });
}

/* ─── Inline section title ──────────────────────────────── */
const SectionTitle = defineComponent({
  name: 'SectionTitle',
  setup(_, { slots }) {
    return () =>
      h('h2', { class: 'ns-section-title' }, slots.default ? slots.default() : []);
  },
});

/* ─── Inline toggle row ─────────────────────────────────── */
const ToggleRow = defineComponent({
  name: 'ToggleRow',
  props: {
    // Lucide icons are functional components (Function), not Object. Allow
    // both so Vue doesn't warn "Expected Object, got Function" on every row.
    icon: { type: [Object, Function] as PropType<Component | undefined>, default: undefined },
    label: { type: String, required: true },
    subtitle: { type: String as PropType<string | undefined>, default: undefined },
    modelValue: { type: Boolean, required: true },
    disabled: { type: Boolean, default: false },
  },
  emits: ['update:modelValue'],
  setup(p, { emit }) {
    return () =>
      h('div', { class: ['ns-row', p.disabled ? 'disabled' : ''] }, [
        p.icon
          ? h('span', { class: 'ns-row-icon' }, [
              h(p.icon, { size: 22, 'stroke-width': 1.8 }),
            ])
          : h('span', { class: 'ns-row-icon-spacer' }),
        h('div', { class: 'ns-row-meta' }, [
          h('div', { class: 'ns-row-label' }, p.label),
          p.subtitle ? h('div', { class: 'ns-row-subtitle' }, p.subtitle) : null,
        ]),
        h(
          'button',
          {
            class: ['ns-toggle', p.modelValue ? 'on' : 'off'],
            type: 'button',
            disabled: p.disabled,
            'aria-pressed': p.modelValue,
            onClick: () => {
              if (p.disabled) return;
              emit('update:modelValue', !p.modelValue);
            },
          },
          [h('span', { class: 'ns-toggle-knob' })]
        ),
      ]);
  },
});
</script>

<style lang="scss" scoped>
.ns-page {
  min-height: 100dvh;
  background: #fff;
  padding-bottom: 32px;
}

.ns-header {
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

.ns-title {
  flex: 1;
  text-align: center;
  font-size: 17px;
  font-weight: 600;
  letter-spacing: -0.01em;
  margin: 0;
  color: #0F172A;
}

/* Sections */
.ns-section {
  display: flex;
  flex-direction: column;
}

.ns-section--first {
  border-bottom: 1px solid #F1F3F5;
}

:deep(.ns-section-title) {
  font-size: 11px;
  font-weight: 600;
  letter-spacing: 0.08em;
  color: #ADB5BD;
  margin: 0;
  padding: 16px 16px 4px;
}

/* Rows */
:deep(.ns-row) {
  display: flex;
  align-items: center;
  gap: 14px;
  padding: 14px 16px;
  border-bottom: 1px solid #F8F9FA;

  &:last-child {
    border-bottom: 0;
  }

  &.disabled {
    opacity: 0.55;
  }
}

:deep(.ns-row-icon) {
  width: 28px;
  height: 28px;
  display: flex;
  align-items: center;
  justify-content: center;
  color: #495057;
  flex-shrink: 0;
}

:deep(.ns-row-icon-spacer) {
  width: 28px;
  height: 28px;
  flex-shrink: 0;
}

:deep(.ns-row-meta) {
  flex: 1;
  display: flex;
  flex-direction: column;
  gap: 2px;
  min-width: 0;
}

:deep(.ns-row-label) {
  font-size: 15px;
  font-weight: 600;
  color: #0F172A;
  letter-spacing: -0.01em;
}

:deep(.ns-row-subtitle) {
  font-size: 12px;
  color: #6C757D;
  line-height: 1.4;
}

/* Custom toggle (purple, pill) */
:deep(.ns-toggle) {
  position: relative;
  width: 44px;
  height: 24px;
  border: 0;
  border-radius: 999px;
  cursor: pointer;
  background: #DEE2E6;
  transition: background 0.15s ease;
  flex-shrink: 0;
  padding: 0;

  &:disabled {
    cursor: default;
  }

  &.on {
    background: #007BFF;
  }

  .ns-toggle-knob {
    position: absolute;
    top: 2px;
    left: 2px;
    width: 20px;
    height: 20px;
    border-radius: 50%;
    background: #fff;
    box-shadow: 0 1px 3px rgba(0, 0, 0, 0.15);
    transition: transform 0.15s ease;
  }

  &.on .ns-toggle-knob {
    transform: translateX(20px);
  }
}
</style>
