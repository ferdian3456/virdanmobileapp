<template>
  <q-page class="static-page">
    <header class="sp-header">
      <button class="icon-btn" type="button" @click="onBack">
        <ChevronLeft :size="24" />
      </button>
      <h1 class="sp-title">Privacy Policy</h1>
      <span class="icon-btn"></span>
    </header>

    <section class="sp-content">
      <p class="sp-intro">
        This policy explains what information Virdan collects, how we use it,
        and the choices you have. It applies to the Virdan mobile app and the
        accounts you create through it.
      </p>
      <p class="sp-meta">Last updated: 23 May 2026 (draft)</p>

      <div class="sp-section">
        <h2 class="sp-section-title">1. Information we collect</h2>
        <p class="sp-section-body">
          We collect data you give us when you sign up (email and password),
          set up a per-server profile (nickname, username, bio, avatar), and
          create content (posts, comments, likes). We also collect basic
          technical data — device type, app version, IP address — to keep the
          service running and secure.
        </p>
      </div>

      <div class="sp-section">
        <h2 class="sp-section-title">2. How we use it</h2>
        <p class="sp-section-body">
          To run the app: deliver posts and comments, route notifications,
          protect against abuse, fix bugs. To verify ownership of your account:
          OTPs sent to your email when you change credentials. We don't sell
          your personal data.
        </p>
      </div>

      <div class="sp-section">
        <h2 class="sp-section-title">3. What other members see</h2>
        <p class="sp-section-body">
          Inside a server, members see the nickname, username, avatar, and
          posts you publish in that server. They don't see your email or your
          identity in other servers unless you choose to share it.
        </p>
      </div>

      <div class="sp-section">
        <h2 class="sp-section-title">4. Storage and security</h2>
        <p class="sp-section-body">
          Your data is stored on managed PostgreSQL, Redis, and MinIO services.
          Passwords are hashed with bcrypt. Avatars and post images live in
          object storage with restricted access. We use TLS in transit.
        </p>
      </div>

      <div class="sp-section">
        <h2 class="sp-section-title">5. Your choices</h2>
        <p class="sp-section-body">
          You can edit your per-server profile any time, delete posts you've
          written, change or revoke email/password, and close your account.
          When you close your account we remove identifying data within 30
          days; some aggregated logs may be kept for security audits.
        </p>
      </div>

      <div class="sp-section">
        <h2 class="sp-section-title">6. Children</h2>
        <p class="sp-section-body">
          Virdan isn't intended for children under 13. If you believe a child
          has registered an account, please contact us so we can remove it.
        </p>
      </div>

      <div class="sp-section">
        <h2 class="sp-section-title">7. Changes to this policy</h2>
        <p class="sp-section-body">
          We'll post material updates in-app and update the "Last updated"
          date. Reviewing the page from time to time is a good idea.
        </p>
      </div>

      <div class="sp-section">
        <h2 class="sp-section-title">8. Contact</h2>
        <p class="sp-section-body">
          Privacy questions or data requests: privacy@virdan.app.
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
