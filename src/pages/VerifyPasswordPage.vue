<template>
  <q-page class="bg-grey-1 q-px-lg q-pt-lg q-pb-lg">
    <ArrowLeft
      :size="24"
      class="back-btn q-mb-md cursor-pointer"
      @click="router.push('/auth/verify-username')"
    />

    <div class="text-left q-mb-lg">
      <h1 class="text-h4 text-weight-bold text-dark q-my-none" style="font-size: 1.875rem;">
        Set your password
      </h1>
      <p class="text-body2 text-grey-6 q-mt-sm">
        Make sure it's at least 8 characters.
      </p>
    </div>

    <q-form class="column q-gutter-y-md" @submit="submit">
      <!-- Password -->
      <VInput
        v-model="password"
        label="Password"
        :type="showPassword ? 'text' : 'password'"
        :error="!!errors.password"
        @keyup.enter="submit"
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

      <!-- Confirm Password -->
      <VInput
        v-model="confirmPassword"
        label="Confirm Password"
        :type="showConfirmPassword ? 'text' : 'password'"
        :error="!!errors.confirmPassword"
        @keyup.enter="submit"
      >
        <template v-slot:append>
          <component
            :is="showConfirmPassword ? EyeOff : Eye"
            :size="20"
            class="cursor-pointer text-grey-5"
            @click="showConfirmPassword = !showConfirmPassword"
          />
        </template>
      </VInput>
      <div v-if="errors.confirmPassword" class="text-negative text-caption q-mt-xs q-ml-sm">
        {{ errors.confirmPassword }}
      </div>

      <div v-if="errors.general" class="text-negative text-caption q-mt-xs">
        {{ errors.general }}
      </div>

      <VButton
        type="submit"
        label="Complete Registration"
        color="primary"
        class="full-width q-mt-lg text-subtitle1"
        :loading="isLoading"
      />
    </q-form>
  </q-page>
</template>

<script setup lang="ts">
import { ref, onMounted } from 'vue';
import { useAuthStore } from 'src/stores/auth.store';
import { useRouter } from 'vue-router';
import { AxiosError } from 'axios';
import { useQuasar } from 'quasar';
import { ArrowLeft, Eye, EyeOff } from 'lucide-vue-next';
import { api } from 'src/boot/axios';
import VInput from 'src/components/VInput.vue';
import VButton from 'src/components/VButton.vue';

const password = ref('');
const confirmPassword = ref('');
const showPassword = ref(false);
const showConfirmPassword = ref(false);
const isLoading = ref(false);
const errors = ref<Record<string, string>>({});
const sessionId = ref('');

const authStore = useAuthStore();
const router = useRouter();
const $q = useQuasar();

onMounted(async () => {
  sessionId.value = (await authStore.getSessionId()) || '';
});

async function submit() {
  errors.value = {};
  if (!password.value) {
    errors.value.password = 'Password is required.';
    return;
  }
  if (password.value.length < 8) {
    errors.value.password = 'Password must be at least 8 characters.';
    return;
  }
  if (password.value !== confirmPassword.value) {
    errors.value.confirmPassword = 'Passwords do not match.';
    return;
  }

  isLoading.value = true;
  try {
    const res = await api.post<{ accessToken: string; refreshToken: string }>('/auth/signup/password', {
      sessionId: sessionId.value,
      password: password.value
    });
    
    await authStore.setTokens({
      accessToken: res.data.accessToken,
      refreshToken: res.data.refreshToken
    });
    await authStore.clearSessionId();
    await authStore.fetchUser();

    $q.notify({
      type: 'positive',
      message: 'Registration successful! Welcome to Virdan.'
    });

    // Brand new user has no servers yet — go straight to onboarding gate.
    await router.push({ name: 'onboarding-server-choice' });
  } catch (error) {
    if (error instanceof AxiosError) {
      const respError = error.response?.data?.error || error.response?.data;
      if (respError?.param) {
        errors.value[respError.param] = respError.message;
      } else {
        errors.value.general = respError?.message || 'Failed to complete registration.';
      }
    } else {
      console.error('[VerifyPassword] Unexpected error:', error);
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
