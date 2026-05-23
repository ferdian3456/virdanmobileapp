<template>
  <q-page class="static-page">
    <header class="sp-header">
      <button class="icon-btn" type="button" @click="onBack">
        <ChevronLeft :size="24" />
      </button>
      <h1 class="sp-title">Terms of Service</h1>
      <span class="icon-btn"></span>
    </header>

    <section class="sp-content">
      <p class="sp-section-help">Last updated: —</p>

      <div class="sp-placeholder">
        <p>
          Our terms of service will be published here. By using Virdan you
          agree to follow the community guidelines and applicable laws.
        </p>
        <p>Full document coming soon.</p>
      </div>
    </section>
  </q-page>
</template>

<script setup lang="ts">
import { useRouter } from 'vue-router';
import { ChevronLeft } from 'lucide-vue-next';

const router = useRouter();

function onBack() {
  if (window.history.length > 1) router.back();
  else void router.push({ name: 'settings' });
}
</script>

<style lang="scss" scoped>
@import 'src/css/static-page.scss';
</style>
