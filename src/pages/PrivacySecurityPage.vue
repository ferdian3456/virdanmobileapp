<template>
  <q-page class="static-page">
    <header class="sp-header">
      <button class="icon-btn" type="button" @click="onBack">
        <ChevronLeft :size="24" />
      </button>
      <h1 class="sp-title">Privacy &amp; Security</h1>
      <span class="icon-btn"></span>
    </header>

    <section class="sp-content">
      <p class="sp-intro">
        Control who can find you, who can message you, and how your account stays
        protected.
      </p>

      <div class="sp-row">
        <div class="sp-row-text">
          <p class="sp-row-title">Private account</p>
          <p class="sp-row-help">
            When on, only approved followers can see your servers and posts.
          </p>
        </div>
        <q-toggle v-model="privateAccount" color="primary" />
      </div>

      <div class="sp-row">
        <div class="sp-row-text">
          <p class="sp-row-title">Show me in search</p>
          <p class="sp-row-help">
            Let other Virdan users find your handle when they search by username.
          </p>
        </div>
        <q-toggle v-model="discoverable" color="primary" />
      </div>

      <div class="sp-row">
        <div class="sp-row-text">
          <p class="sp-row-title">Read receipts</p>
          <p class="sp-row-help">
            Let people see when you've read their direct messages.
          </p>
        </div>
        <q-toggle v-model="readReceipts" color="primary" />
      </div>

      <div class="sp-row">
        <div class="sp-row-text">
          <p class="sp-row-title">Two-factor authentication</p>
          <p class="sp-row-help">
            Add a second step at login to keep your account secure.
          </p>
        </div>
        <span class="sp-row-coming">COMING SOON</span>
      </div>

      <div class="sp-row">
        <div class="sp-row-text">
          <p class="sp-row-title">Active sessions</p>
          <p class="sp-row-help">
            Review devices that are signed in and sign out remotely.
          </p>
        </div>
        <span class="sp-row-coming">COMING SOON</span>
      </div>
    </section>
  </q-page>
</template>

<script setup lang="ts">
import { ref } from 'vue';
import { useRouter } from 'vue-router';
import { ChevronLeft } from 'lucide-vue-next';

const router = useRouter();

// Local-only toggles for now; BE persistence wires later.
const privateAccount = ref(false);
const discoverable = ref(true);
const readReceipts = ref(true);

function onBack() {
  if (window.history.length > 1) router.back();
  else void router.push({ name: 'settings' });
}
</script>

<style lang="scss" scoped>
@import 'src/css/static-page.scss';
</style>
