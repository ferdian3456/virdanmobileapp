<template>
  <q-page class="cp-page">
    <header class="cp-header">
      <button class="icon-btn" type="button" @click="onBack">
        <ChevronLeft :size="24" />
      </button>
      <h1 class="cp-title">Change Password</h1>
      <span class="icon-btn"></span>
    </header>

    <!-- ─── Step 1: verify current password ────────────────── -->
    <section v-if="step === 'verify'" class="cp-section">
      <div class="cp-hero">
        <p class="cp-section-help">
          For your security, please confirm your current password before setting a new one.
        </p>
      </div>

      <q-form class="cp-form" @submit.prevent="verifyCurrent">
        <FieldLabel label="Current password" />
        <q-input
          v-model="currentPassword"
          outlined
          dense
          :type="showCurrent ? 'text' : 'password'"
          placeholder="••••••••"
          class="cp-input"
          hide-bottom-space
          :error="!!errors.current"
          @keyup.enter="verifyCurrent"
        >
          <template #append>
            <component
              :is="showCurrent ? EyeOff : Eye"
              :size="20"
              class="cursor-pointer text-grey-5"
              @click="showCurrent = !showCurrent"
            />
          </template>
        </q-input>
        <p v-if="errors.current" class="field-error">{{ errors.current }}</p>

        <p class="forgot-link" type="button">
          <button class="forgot-btn" type="button" @click="onForgot">
            Forgot password?
          </button>
        </p>
      </q-form>
    </section>

    <!-- ─── Step 2: set new password ───────────────────────── -->
    <section v-else class="cp-section">
      <div class="cp-hero">
        <p class="cp-section-help">
          Make it at least 8 characters. Choose a password you don't use anywhere else.
        </p>
      </div>

      <q-form class="cp-form" @submit.prevent="updatePassword">
        <FieldLabel label="New password" />
        <q-input
          v-model="newPassword"
          outlined
          dense
          :type="showNew ? 'text' : 'password'"
          placeholder="••••••••"
          class="cp-input"
          hide-bottom-space
          :error="!!errors.new"
        >
          <template #append>
            <component
              :is="showNew ? EyeOff : Eye"
              :size="20"
              class="cursor-pointer text-grey-5"
              @click="showNew = !showNew"
            />
          </template>
        </q-input>
        <p v-if="errors.new" class="field-error">{{ errors.new }}</p>

        <FieldLabel label="Confirm new password" />
        <q-input
          v-model="confirmPassword"
          outlined
          dense
          :type="showConfirm ? 'text' : 'password'"
          placeholder="••••••••"
          class="cp-input"
          hide-bottom-space
          :error="!!errors.confirm"
          @keyup.enter="updatePassword"
        >
          <template #append>
            <component
              :is="showConfirm ? EyeOff : Eye"
              :size="20"
              class="cursor-pointer text-grey-5"
              @click="showConfirm = !showConfirm"
            />
          </template>
        </q-input>
        <p v-if="errors.confirm" class="field-error">{{ errors.confirm }}</p>

        <ul class="cp-rules">
          <li :class="{ ok: ruleLength }">
            <Check v-if="ruleLength" :size="14" :stroke-width="2.5" />
            <Circle v-else :size="14" :stroke-width="2" />
            At least 8 characters
          </li>
          <li :class="{ ok: ruleMatch }">
            <Check v-if="ruleMatch" :size="14" :stroke-width="2.5" />
            <Circle v-else :size="14" :stroke-width="2" />
            Passwords match
          </li>
        </ul>
      </q-form>
    </section>

    <!-- Floating action button -->
    <footer class="cp-footer">
      <q-btn
        unelevated
        no-caps
        color="primary"
        :label="step === 'verify' ? 'Continue' : 'Update Password'"
        class="full-width cp-action-btn"
        :disable="!canProceed"
        :loading="isProcessing"
        @click="step === 'verify' ? verifyCurrent() : updatePassword()"
      />
    </footer>
  </q-page>
</template>

<script setup lang="ts">
import { ref, computed, defineComponent, h } from 'vue';
import { useRouter } from 'vue-router';
import { ChevronLeft, Eye, EyeOff, Check, Circle } from 'lucide-vue-next';
import { useToast } from 'src/composables/useToast';

type Step = 'verify' | 'set';

const router = useRouter();
const toast = useToast();

const step = ref<Step>('verify');
const currentPassword = ref('');
const newPassword = ref('');
const confirmPassword = ref('');
const showCurrent = ref(false);
const showNew = ref(false);
const showConfirm = ref(false);
const isProcessing = ref(false);
const errors = ref<Record<string, string>>({});

const ruleLength = computed(() => newPassword.value.length >= 8);
const ruleMatch = computed(
  () => newPassword.value.length > 0 && newPassword.value === confirmPassword.value
);

const canProceed = computed(() => {
  if (isProcessing.value) return false;
  if (step.value === 'verify') return currentPassword.value.length > 0;
  return ruleLength.value && ruleMatch.value;
});

async function verifyCurrent() {
  if (!canProceed.value) return;
  errors.value = {};
  isProcessing.value = true;
  try {
    // BE has no "verify password" endpoint yet. Mock success.
    // When BE adds POST /api/users/password/verify, swap this for a real call.
    await new Promise((r) => setTimeout(r, 400));
    step.value = 'set';
  } catch {
    errors.value.current = 'Current password is incorrect.';
  } finally {
    isProcessing.value = false;
  }
}

async function updatePassword() {
  if (!canProceed.value) return;
  errors.value = {};

  if (newPassword.value === currentPassword.value) {
    errors.value.new = 'New password must differ from current password.';
    return;
  }

  isProcessing.value = true;
  try {
    // BE has no "change password" endpoint yet. Mock success.
    // When BE adds PUT /api/users/password, swap for:
    // await api.put('/users/password', { current: currentPassword.value, new: newPassword.value });
    await new Promise((r) => setTimeout(r, 600));
    toast.success({ title: 'Password updated.' });
    await router.push({ name: 'settings' });
  } catch {
    errors.value.new = 'Failed to update password. Try again.';
  } finally {
    isProcessing.value = false;
  }
}

function onForgot() {
  toast.info({ title: 'Password reset flow is coming soon.' });
}

function onBack() {
  if (step.value === 'set') {
    step.value = 'verify';
    newPassword.value = '';
    confirmPassword.value = '';
    errors.value = {};
    return;
  }
  if (window.history.length > 1) router.back();
  else void router.push({ name: 'settings' });
}

/* ─── Inline FieldLabel ────────────────────────────────── */
const FieldLabel = defineComponent({
  name: 'FieldLabel',
  props: { label: { type: String, required: true } },
  setup(p) {
    return () =>
      h('label', { class: 'field-label' }, p.label.toUpperCase());
  },
});
</script>

<style lang="scss" scoped>
.cp-page {
  min-height: 100dvh;
  background: #fff;
  padding-bottom: 120px;
}

.cp-header {
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

.cp-title {
  flex: 1;
  text-align: center;
  font-size: 17px;
  font-weight: 600;
  letter-spacing: -0.01em;
  margin: 0;
  color: #0F172A;
}

.cp-section {
  padding: 12px 20px 0;
}

.cp-hero {
  margin-bottom: 4px;
}

.cp-section-help {
  font-size: 13px;
  color: #6C757D;
  line-height: 1.45;
  margin: 0;
}

.cp-form {
  display: flex;
  flex-direction: column;
  gap: 6px;
}

:deep(.field-label) {
  font-size: 11px;
  font-weight: 600;
  letter-spacing: 0.08em;
  color: #6C757D;
  margin: 12px 0 4px;
  display: block;
}

.cp-input :deep(.q-field__control) {
  border-radius: 12px;
  background: #fff;
  min-height: 48px;

  &::before {
    border-color: #DEE2E6;
  }
}

.field-error {
  font-size: 12px;
  color: #DC3545;
  margin: 4px 4px 0;
}

.forgot-link {
  margin: 12px 0 0;
}

.forgot-btn {
  background: transparent;
  border: 0;
  color: #007BFF;
  font-family: inherit;
  font-size: 13px;
  font-weight: 600;
  cursor: pointer;
  padding: 0;
}

/* Password rules */
.cp-rules {
  margin: 16px 0 0;
  padding: 0;
  list-style: none;
  display: flex;
  flex-direction: column;
  gap: 6px;

  li {
    display: flex;
    align-items: center;
    gap: 8px;
    font-size: 13px;
    color: #6C757D;

    &.ok {
      color: #10B981;
    }
  }
}

/* Floating action footer */
.cp-footer {
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

.cp-action-btn {
  border-radius: 14px !important;
  min-height: 48px;
  font-weight: 600;
  letter-spacing: -0.01em;
}
</style>
