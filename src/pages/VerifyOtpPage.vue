<template>
  <q-page class="bg-grey-1 q-px-lg q-pt-lg q-pb-lg">
    <ArrowLeft
      :size="24"
      class="back-btn q-mb-md cursor-pointer"
      @click="router.push('/auth/register')"
    />

    <div class="text-left q-mb-lg">
      <h1 class="text-h4 text-weight-bold text-dark q-my-none" style="font-size: 1.875rem;">
        Verify OTP
      </h1>
      <p class="text-body2 text-grey-6 q-mt-sm">
        We've sent a verification code to your email. Please enter it below.
      </p>
      <p
        class="text-body2 q-mt-xs"
        :class="timeLeft === 'Expired' ? 'text-negative' : 'text-grey-6'"
      >
        {{ timeLeft === 'Expired' ? 'Code expired. Please try again.' : `Code expires in ${timeLeft}` }}
      </p>
    </div>

    <div class="row justify-center q-gutter-x-sm q-mb-lg">
      <input
        v-for="(_, index) in 6"
        :key="index"
        :id="`otp-${index}`"
        v-model="otpDigits[index]"
        type="text"
        maxlength="1"
        inputmode="numeric"
        class="otp-input"
        @input="onOtpInput($event, index)"
        @keydown="onOtpKeydown($event, index)"
        @keyup.enter="verifyOtp"
      />
    </div>

    <div v-if="errors.otp" class="text-negative text-caption text-center q-mb-md">
      {{ errors.otp }}
    </div>
    <div v-if="errors.general" class="text-negative text-caption text-center q-mb-md">
      {{ errors.general }}
    </div>

    <VButton
      label="Next"
      color="primary"
      class="full-width q-mb-lg text-subtitle1"
      :loading="isLoading"
      @click="verifyOtp"
    />

    <p class="text-center text-body2 text-grey-6">
      Didn’t receive a code?
      <span 
        class="text-primary text-weight-bold cursor-pointer"
        :class="{ 'opacity-50 pointer-events-none': isResending }"
        @click="resendOtp"
      >
        {{ isResending ? 'Sending...' : 'Resend' }}
      </span>
    </p>
  </q-page>
</template>

<script setup lang="ts">
import { ref, onMounted, onUnmounted, computed } from 'vue';
import { useAuthStore } from 'src/stores/auth.store';
import { useRouter } from 'vue-router';
import { AxiosError } from 'axios';
import { useToast } from 'src/composables/useToast';
import { ArrowLeft } from 'lucide-vue-next';
import { api } from 'src/boot/axios';
import VButton from 'src/components/VButton.vue';

const otpDigits = ref<string[]>(['', '', '', '', '', '']);
const isLoading = ref(false);
const isResending = ref(false);
const errors = ref<Record<string, string>>({});
const timeLeft = ref('');
const otpExpiresAt = ref(0);
let timerInterval: ReturnType<typeof setInterval> | null = null;

const authStore = useAuthStore();
const router = useRouter();
const toast = useToast();

const otpValue = computed(() => otpDigits.value.join(''));

onMounted(async () => {
  const storedExpiresAt = await authStore.getOtpExpiresAt();
  // Check if we have it in router state (from RegisterPage) or fallback to storage
  otpExpiresAt.value = (history.state?.otpExpiresAt as number) || storedExpiresAt;
  
  startTimer();
});

onUnmounted(() => {
  if (timerInterval) clearInterval(timerInterval);
});

function startTimer() {
  const updateTimer = () => {
    const now = Math.floor(Date.now() / 1000);
    const diff = otpExpiresAt.value - now;
    
    if (diff <= 0) {
      timeLeft.value = 'Expired';
      if (timerInterval) clearInterval(timerInterval);
    } else {
      const m = Math.floor(diff / 60);
      const s = diff % 60;
      timeLeft.value = `${m}:${s.toString().padStart(2, '0')}`;
    }
  };
  
  updateTimer();
  timerInterval = setInterval(updateTimer, 1000);
}

function onOtpInput(event: Event, index: number) {
  const input = event.target as HTMLInputElement;
  const val = input.value;
  
  // Only allow numbers
  if (val && !/^\d+$/.test(val)) {
    otpDigits.value[index] = '';
    return;
  }

  otpDigits.value[index] = val;
  
  if (val && index < 5) {
    const nextInput = document.getElementById(`otp-${index + 1}`);
    nextInput?.focus();
  }
}

function onOtpKeydown(event: KeyboardEvent, index: number) {
  if (event.key === 'Backspace' && !otpDigits.value[index] && index > 0) {
    const prevInput = document.getElementById(`otp-${index - 1}`);
    prevInput?.focus();
  }
}

async function verifyOtp() {
  errors.value = {};
  if (otpValue.value.length < 6) {
    errors.value.otp = 'Please enter the complete 6-digit code.';
    return;
  }

  isLoading.value = true;
  try {
    const sessionId = await authStore.getSessionId();
    await api.post('/auth/signup/otp', {
      sessionId,
      otp: otpValue.value
    });
    
    await authStore.clearOtpExpiresAt();
    await router.push('/auth/verify-password');
  } catch (error) {
    if (error instanceof AxiosError) {
      const respError = error.response?.data?.error || error.response?.data;
      if (respError?.param) {
        errors.value[respError.param] = respError.message;
      } else {
        errors.value.general = respError?.message || 'Verification failed.';
      }
    } else {
      console.error('[VerifyOtp] Unexpected error:', error);
      errors.value.general = 'An unexpected error occurred.';
    }
  } finally {
    isLoading.value = false;
  }
}

async function resendOtp() {
  errors.value = {};
  isResending.value = true;
  try {
    const sessionId = await authStore.getSessionId();
    const res = await api.post<{ otpExpiresAt: number }>('/auth/signup/resend-otp', {
      sessionId
    });
    
    otpExpiresAt.value = res.data.otpExpiresAt;
    await authStore.setOtpExpiresAt(res.data.otpExpiresAt);
    
    // Reset timer
    if (timerInterval) clearInterval(timerInterval);
    startTimer();
    
    // Clear inputs
    otpDigits.value = ['', '', '', '', '', ''];
    document.getElementById('otp-0')?.focus();
    
    toast.success({ title: 'A new verification code has been sent to your email.' });
  } catch (error) {
    if (error instanceof AxiosError) {
      toast.error({ title: error.response?.data?.error?.message || 'Failed to resend OTP.' });
    }
  } finally {
    isResending.value = false;
  }
}
</script>

<style lang="scss">
.back-btn {
  color: #212529;
  display: block;
}

.otp-input {
  width: 44px;
  height: 48px;
  text-align: center;
  font-size: 1.25rem;
  font-weight: 600;
  border-radius: 12px;
  border: 1px solid #e5e7eb;
  background-color: white;
  transition: border-color 0.2s ease;

  &:focus {
    outline: none;
    border-color: var(--q-primary);
  }
}
</style>
