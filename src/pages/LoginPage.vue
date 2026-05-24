<template>
  <q-page class="bg-grey-1 q-px-lg q-pt-lg q-pb-lg">
    <div class="text-left q-mb-lg">
      <h1 class="text-h4 text-weight-bold text-dark q-my-none">Welcome To Virdan</h1>
      <p class="text-body2 text-grey-6 q-mt-sm">
        Good to see you. Enter your email and password to continue.
      </p>
    </div>

    <q-form class="column q-gutter-y-md" @submit="login">
      <!-- Email -->
      <VInput v-model="email" label="Email" type="email" :error="!!errors.email" @keyup.enter="login" />
      <div v-if="errors.email" class="text-negative text-caption q-mt-xs q-ml-sm">
        {{ errors.email }}
      </div>

      <!-- Password -->
      <VInput
        v-model="password"
        label="Password"
        :type="showPassword ? 'text' : 'password'"
        :error="!!errors.password"
        @keyup.enter="login"
      >
        <template v-slot:append>
          <component
            :is="showPassword ? EyeOff : Eye"
            :size="20"
            class="cursor-pointer text-grey-5"
            @click="showPassword = !showPassword"
          />
        </template>
      </VInput>
      <div v-if="errors.password" class="text-negative text-caption q-mt-xs q-ml-sm">
        {{ errors.password }}
      </div>

      <div v-if="errors.general" class="text-negative text-caption q-mt-xs">
        {{ errors.general }}
      </div>

      <VButton
        type="submit"
        label="Sign In"
        color="primary"
        class="full-width q-mt-lg text-subtitle1"
        :loading="isLoading"
      />
    </q-form>

    <div class="row items-center q-my-lg no-wrap">
      <q-separator class="col" color="grey-6" />
      <span class="text-caption text-weight-medium q-mx-md text-grey-5">OR</span>
      <q-separator class="col" color="grey-6" />
    </div>

    <!-- Social Logins -->
    <div class="column q-gutter-y-md">
      <VButton
        outline
        class="full-width bg-white"
        style="border: 1px solid #e5e7eb; color: #374151"
      >
        <div class="row items-center no-wrap" style="gap: 12px">
          <img src="/assets/icons/google_logo.svg" alt="" style="width: 24px" />
          <span>Continue with Google</span>
        </div>
      </VButton>

      <VButton color="black" class="full-width">
        <div class="row items-center no-wrap" style="gap: 12px">
          <img src="/assets/icons/apple_logo.svg" alt="" style="width: 24px" class="invert" />
          <span>Continue with Apple</span>
        </div>
      </VButton>
    </div>

    <p class="text-center text-body2 text-grey-6 q-mt-lg">
      Don't have an account?
      <span
        class="text-primary text-weight-bold cursor-pointer"
        @click="router.push('/auth/register')"
        >Sign Up</span
      >
    </p>

    <!-- Resume Modal -->
    <q-dialog v-model="showResumeModal" persistent>
      <q-card class="q-pa-lg rounded-2xl" style="width: 320px; max-width: 90vw">
        <q-card-section class="q-pa-none">
          <div class="text-h6 text-weight-bold" style="color: #1a1a2e">Resume Registration</div>
          <div class="text-body2 text-grey-6 q-mt-sm">
            You have an unfinished registration. Would you like to continue where you left off?
          </div>
        </q-card-section>

        <q-card-actions align="between" class="q-pa-none q-mt-xl no-wrap q-gutter-x-md">
          <q-btn
            flat
            label="No"
            class="col bg-grey-2 text-grey-8 rounded-xl font-semibold no-caps"
            @click="startOver"
          />
          <q-btn
            unelevated
            label="Yes"
            color="primary"
            class="col rounded-xl font-semibold no-caps"
            @click="continueRegistration"
          />
        </q-card-actions>
      </q-card>
    </q-dialog>
  </q-page>
</template>

<script setup lang="ts">
import { ref, onMounted } from 'vue';
import { useAuthStore } from 'src/stores/auth.store';
import { useRouter } from 'vue-router';
import { useToast } from 'src/composables/useToast';
import { AxiosError } from 'axios';
import { Eye, EyeOff } from 'lucide-vue-next';
import { api } from 'src/boot/axios';
import VInput from 'src/components/VInput.vue';
import VButton from 'src/components/VButton.vue';

const email = ref('');
const password = ref('');
const isLoading = ref(false);
const showPassword = ref(false);
const showResumeModal = ref(false);
const pendingStep = ref('');
const errors = ref<Record<string, string>>({});

const authStore = useAuthStore();
const router = useRouter();
const toast = useToast();

onMounted(async () => {
  const sessionId = await authStore.getSessionId();
  if (!sessionId) return;

  try {
    const res = await api.get<{ step: string }>(`auth/signup/${sessionId}/status`);
    if (res.data.step === 'password_set') {
      await authStore.clearSessionId();
      return;
    }
    pendingStep.value = res.data.step;
    showResumeModal.value = true;
  } catch {
    await authStore.clearSessionId();
  }
});

async function continueRegistration() {
  showResumeModal.value = false;
  switch (pendingStep.value) {
    case 'start_signup':
      await router.push('/auth/verify-otp');
      break;
    case 'otp_verified':
      await router.push('/auth/verify-password');
      break;
  }
}

async function startOver() {
  await authStore.clearSessionId();
  showResumeModal.value = false;
}

async function login() {
  errors.value = {};
  if (!email.value) {
    errors.value.email = 'Email is required to not be empty.';
    return;
  }
  if (!password.value) {
    errors.value.password = 'Password is required to not be empty.';
    return;
  }

  isLoading.value = true;
  try {
    await authStore.login({
      email: email.value.trim().toLowerCase(),
      password: password.value,
    });

    toast.success({ title: 'Login successful' });

    await router.push({ name: 'home' });
  } catch (error) {
    if (error instanceof AxiosError) {
      const respError = error.response?.data?.error || error.response?.data;
      if (respError?.param) {
        errors.value[respError.param] = respError.message;
      } else {
        errors.value.general = respError?.message || 'Login failed. Please check your credentials.';
      }
    } else {
      console.error('[Login] Unexpected error:', error);
      errors.value.general = 'An unexpected error occurred.';
    }
  } finally {
    isLoading.value = false;
  }
}
</script>

<style lang="scss">
.invert {
  filter: invert(1);
}
</style>
