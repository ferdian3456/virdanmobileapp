<template>
  <q-page class="bg-grey-1 q-px-lg q-pt-lg q-pb-md">
    <ArrowLeft
      :size="24"
      class="back-btn q-mb-md cursor-pointer"
      @click="router.push('/auth/login')"
    />

    <div class="text-left q-mb-lg">
      <h1 class="text-h4 text-weight-bold text-dark q-my-none" style="font-size: 1.875rem">
        What's your email?
      </h1>
      <p class="text-body2 text-grey-6 q-mt-sm">
        Enter the email where you can be contacted. No one will see this on your profile.
      </p>
    </div>

    <q-form class="column q-gutter-y-md" @submit="register">
      <!-- Email -->
      <VInput
        v-model="email"
        label="Email"
        type="email"
        placeholder="johndoe@gmail.com"
        :error="!!errors.email"
        @keyup.enter="register"
      />
      <div v-if="errors.email" class="text-negative text-caption q-mt-xs q-ml-sm">
        {{ errors.email }}
      </div>

      <div v-if="errors.general" class="text-negative text-caption q-mt-xs">
        {{ errors.general }}
      </div>

      <VButton
        type="submit"
        label="Next"
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
          <q-img src="/assets/icons/google_logo.svg" width="24px" />
          <span>Continue with Google</span>
        </div>
      </VButton>

      <VButton color="black" class="full-width">
        <div class="row items-center no-wrap" style="gap: 12px">
          <q-img src="/assets/icons/apple_logo.svg" width="24px" class="invert" />
          <span>Continue with Apple</span>
        </div>
      </VButton>
    </div>

    <p class="text-center text-body2 text-grey-6 q-mt-lg">
      Already have an account?
      <span class="text-primary text-weight-bold cursor-pointer" @click="router.push('/auth/login')"
        >Sign In</span
      >
    </p>
  </q-page>
</template>

<script setup lang="ts">
import { ref } from 'vue';
import { useAuthStore } from 'src/stores/auth.store';
import { useRouter } from 'vue-router';
import { AxiosError } from 'axios';
import { api } from 'src/boot/axios';
import VInput from 'src/components/VInput.vue';
import VButton from 'src/components/VButton.vue';
import { ArrowLeft } from 'lucide-vue-next';

const email = ref('');
const isLoading = ref(false);
const errors = ref<Record<string, string>>({});

const authStore = useAuthStore();
const router = useRouter();

async function register() {
  errors.value = {};
  if (!email.value) {
    errors.value.email = 'Email is required to not be empty.';
    return;
  }

  isLoading.value = true;
  try {
    const res = await api.post<{ sessionId: string; otpExpiresAt: number }>('/auth/signup/start', {
      email: email.value,
    });

    await authStore.setSessionId(res.data.sessionId);
    await authStore.setOtpExpiresAt(res.data.otpExpiresAt);

    await router.push('/auth/verify-otp');
  } catch (error) {
    if (error instanceof AxiosError) {
      const respError = error.response?.data?.error || error.response?.data;
      if (respError?.param) {
        errors.value[respError.param] = respError.message;
      } else {
        errors.value.general = respError?.message || 'Failed to start registration.';
      }
    } else {
      console.error('[Register] Unexpected error:', error);
      errors.value.general = 'An unexpected error occurred.';
    }
  } finally {
    isLoading.value = false;
  }
}
</script>

<style lang="scss">
.back-btn {
  color: #212529;
  display: block;
}
</style>
