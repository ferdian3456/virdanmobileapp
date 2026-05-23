<template>
  <q-page class="ce-page">
    <header class="ce-header">
      <button class="icon-btn" type="button" @click="onBack">
        <ChevronLeft :size="24" />
      </button>
      <h1 class="ce-title">Change Email</h1>
      <span class="icon-btn"></span>
    </header>

    <!-- ─── Step 1: input new email ────────────────────── -->
    <section v-if="step === 'request'" class="ce-section">
      <div class="ce-hero">
        <p class="ce-section-help">
          We'll send a 6-digit code to your current email to confirm the change.
        </p>
      </div>

      <q-form class="ce-form" @submit.prevent="requestChange">
        <FieldLabel label="New email" />
        <q-input
          v-model="newEmail"
          outlined
          dense
          type="email"
          placeholder="Enter your new email"
          class="ce-input"
          hide-bottom-space
          :error="!!errors.email"
          @keyup.enter="requestChange"
        />
        <p v-if="errors.email" class="field-error">{{ errors.email }}</p>
      </q-form>
    </section>

    <!-- ─── Step 2: input OTP ──────────────────────────── -->
    <section v-else class="ce-section">
      <div class="ce-hero">
        <p class="ce-section-help">
          We sent a 6-digit code to your current email. Enter it below to confirm
          changing to <strong>{{ newEmail }}</strong>.
        </p>
      </div>

      <q-form class="ce-form" @submit.prevent="confirmChange">
        <FieldLabel label="Verification code" />
        <q-input
          v-model="otp"
          outlined
          dense
          maxlength="6"
          inputmode="numeric"
          placeholder="123456"
          class="ce-input"
          hide-bottom-space
          :error="!!errors.otp"
          @keyup.enter="confirmChange"
        />
        <p v-if="errors.otp" class="field-error">{{ errors.otp }}</p>
      </q-form>
    </section>

    <!-- Floating action -->
    <footer class="ce-footer">
      <q-btn
        unelevated
        no-caps
        color="primary"
        :label="step === 'request' ? 'Send Code' : 'Confirm'"
        class="full-width ce-action-btn"
        :disable="!canProceed"
        :loading="isProcessing"
        @click="step === 'request' ? requestChange() : confirmChange()"
      />
    </footer>
  </q-page>
</template>

<script setup lang="ts">
import { ref, computed, defineComponent, h } from 'vue';
import { useRouter } from 'vue-router';
import { ChevronLeft } from 'lucide-vue-next';
import { api } from 'src/boot/axios';
import { useToast } from 'src/composables/useToast';
import { normalizeError } from 'src/composables/useApiError';

type Step = 'request' | 'confirm';

const EMAIL_REGEX = /^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$/;
const OTP_REGEX = /^\d{6}$/;

const router = useRouter();
const toast = useToast();

const step = ref<Step>('request');
const newEmail = ref('');
const otp = ref('');
const isProcessing = ref(false);
const errors = ref<Record<string, string>>({});

const canProceed = computed(() => {
  if (isProcessing.value) return false;
  if (step.value === 'request') return EMAIL_REGEX.test(newEmail.value.trim());
  return OTP_REGEX.test(otp.value.trim());
});

async function requestChange() {
  if (!canProceed.value) return;
  errors.value = {};
  isProcessing.value = true;
  try {
    await api.post('/users/email/change/request', {
      newEmail: newEmail.value.trim().toLowerCase(),
    });
    toast.success({ title: 'Code sent to your current email.' });
    step.value = 'confirm';
  } catch (err) {
    const normalized = normalizeError(err);
    errors.value.email = normalized.message || 'Failed to send code. Try again.';
  } finally {
    isProcessing.value = false;
  }
}

async function confirmChange() {
  if (!canProceed.value) return;
  errors.value = {};
  isProcessing.value = true;
  try {
    await api.post('/users/email/change/confirm', { otp: otp.value.trim() });
    toast.success({ title: 'Email updated.' });
    await router.push({ name: 'settings' });
  } catch (err) {
    const normalized = normalizeError(err);
    errors.value.otp = normalized.message || 'Invalid code. Try again.';
  } finally {
    isProcessing.value = false;
  }
}

function onBack() {
  if (step.value === 'confirm') {
    step.value = 'request';
    otp.value = '';
    errors.value = {};
    return;
  }
  if (window.history.length > 1) router.back();
  else void router.push({ name: 'settings' });
}

const FieldLabel = defineComponent({
  name: 'FieldLabel',
  props: { label: { type: String, required: true } },
  setup(p) {
    return () => h('label', { class: 'field-label' }, p.label.toUpperCase());
  },
});
</script>

<style lang="scss" scoped>
.ce-page {
  min-height: 100dvh;
  background: #fff;
  padding-bottom: 120px;
}

.ce-header {
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

  &:hover { background: #F1F3F5; }
}

.ce-title {
  flex: 1;
  text-align: center;
  font-size: 17px;
  font-weight: 600;
  letter-spacing: -0.01em;
  margin: 0;
  color: #0F172A;
}

.ce-section {
  padding: 24px 20px;
}

.ce-hero {
  margin-bottom: 20px;
}

.ce-section-help {
  font-size: 14px;
  color: #6C757D;
  line-height: 1.5;
  margin: 0;
}

.ce-form {
  display: flex;
  flex-direction: column;
  gap: 6px;
}

:deep(.field-label) {
  font-size: 11px;
  font-weight: 600;
  letter-spacing: 0.08em;
  color: #6C757D;
  display: block;
  margin-bottom: 6px;
}

.ce-input :deep(.q-field__control) {
  border-radius: 12px;
  background: #fff;
  min-height: 44px;

  &::before { border-color: #DEE2E6; }
}

.field-error {
  font-size: 12px;
  color: #DC3545;
  margin: 4px 4px 0;
}

.ce-footer {
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

.ce-action-btn {
  border-radius: 14px !important;
  min-height: 48px;
  font-weight: 600;
  letter-spacing: -0.01em;
}
</style>
