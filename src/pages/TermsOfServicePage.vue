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
      <p class="sp-intro">
        Welcome to Virdan. By creating an account or using the app you agree to
        these terms. Please read them carefully.
      </p>
      <p class="sp-meta">Last updated: 23 May 2026 (draft)</p>

      <div class="sp-section">
        <h2 class="sp-section-title">1. Eligibility</h2>
        <p class="sp-section-body">
          You must be at least 13 years old to use Virdan. If you are under 18,
          you confirm that a parent or guardian has reviewed these terms with
          you. Some communities may set higher age requirements.
        </p>
      </div>

      <div class="sp-section">
        <h2 class="sp-section-title">2. Your account</h2>
        <p class="sp-section-body">
          You are responsible for keeping your login credentials private. Pick
          a strong password and don't share it. You're responsible for activity
          that happens through your account, so tell us right away if you think
          someone else has access.
        </p>
      </div>

      <div class="sp-section">
        <h2 class="sp-section-title">3. Acceptable use</h2>
        <p class="sp-section-body">
          Don't use Virdan to do anything illegal, harassing, or harmful. Don't
          impersonate others, scrape the platform without permission, or upload
          content you don't have rights to. Server owners may add their own
          rules — when you join a server you agree to follow them.
        </p>
      </div>

      <div class="sp-section">
        <h2 class="sp-section-title">4. Content you post</h2>
        <p class="sp-section-body">
          You keep ownership of anything you post. By posting, you grant Virdan
          a non-exclusive licence to host, display, and distribute your content
          so the app can show it to other members of the relevant server. You
          can delete a post at any time and the licence ends with that delete.
        </p>
      </div>

      <div class="sp-section">
        <h2 class="sp-section-title">5. Suspension and termination</h2>
        <p class="sp-section-body">
          We may suspend or remove an account that violates these terms or that
          puts the safety of other users at risk. You can close your account
          any time from Settings — your data is removed in line with the
          Privacy Policy.
        </p>
      </div>

      <div class="sp-section">
        <h2 class="sp-section-title">6. Service availability</h2>
        <p class="sp-section-body">
          Virdan is provided "as is" without warranties. We work hard to keep
          the service available but we can't guarantee uninterrupted access or
          that the app will be free of errors.
        </p>
      </div>

      <div class="sp-section">
        <h2 class="sp-section-title">7. Changes</h2>
        <p class="sp-section-body">
          We may update these terms when the product changes or to reflect new
          legal requirements. We'll let you know in-app for material changes;
          continued use after the update means you accept the new version.
        </p>
      </div>

      <div class="sp-section">
        <h2 class="sp-section-title">8. Contact</h2>
        <p class="sp-section-body">
          Questions about these terms? Email legal@virdan.app.
        </p>
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
