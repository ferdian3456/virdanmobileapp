<template>
  <q-page class="bg-grey-1 q-px-lg q-pt-lg q-pb-lg">
    <ArrowLeft
      :size="24"
      class="back-btn q-mb-md cursor-pointer"
      @click="router.push('/auth/verify-otp')"
    />

    <div class="text-left q-mb-lg">
      <h1 class="text-h4 text-weight-bold text-dark q-my-none" style="font-size: 1.875rem;">
        Choose a username
      </h1>
      <p class="text-body2 text-grey-6 q-mt-sm">
        You can always change this later.
      </p>
    </div>

    <q-form class="column q-gutter-y-md" @submit="submit">
      <!-- Username -->
      <VInput
        v-model="username"
        label="Username"
        :error="!!errors.username"
        @keyup.enter="submit"
      />
      <div v-if="errors.username" class="text-negative text-caption q-mt-xs q-ml-sm">
        {{ errors.username }}
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
  </q-page>
</template>

<script setup lang="ts">
import { ref, onMounted } from 'vue';
import { useAuthStore } from 'src/stores/auth.store';
import { useRouter } from 'vue-router';
import { AxiosError } from 'axios';
import { ArrowLeft } from 'lucide-vue-next';
import { api } from 'src/boot/axios';
import VInput from 'src/components/VInput.vue';
import VButton from 'src/components/VButton.vue';

const username = ref('');
const isLoading = ref(false);
const errors = ref<Record<string, string>>({});
const sessionId = ref('');

const authStore = useAuthStore();
const router = useRouter();

onMounted(async () => {
  sessionId.value = (await authStore.getSessionId()) || '';
});

async function submit() {
  errors.value = {};
  if (!username.value) {
    errors.value.username = 'Username is required.';
    return;
  }

  isLoading.value = true;
  try {
    await api.post('/auth/signup/username', {
      sessionId: sessionId.value,
      username: username.value
    });
    
    await router.push('/auth/verify-password');
  } catch (error) {
    if (error instanceof AxiosError) {
      const respError = error.response?.data?.error || error.response?.data;
      if (respError?.param) {
        errors.value[respError.param] = respError.message;
      } else {
        errors.value.general = respError?.message || 'Failed to set username.';
      }
    } else {
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
