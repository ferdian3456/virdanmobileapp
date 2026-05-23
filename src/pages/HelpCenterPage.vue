<template>
  <q-page class="static-page">
    <header class="sp-header">
      <button class="icon-btn" type="button" @click="onBack">
        <ChevronLeft :size="24" />
      </button>
      <h1 class="sp-title">Help Center</h1>
      <span class="icon-btn"></span>
    </header>

    <section class="sp-content">
      <p class="sp-section-help">
        Find answers, contact support, and learn how Virdan works.
      </p>

      <div class="sp-placeholder">
        <p>Help articles are coming soon.</p>
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
