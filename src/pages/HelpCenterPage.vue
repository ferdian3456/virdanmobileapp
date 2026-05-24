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
      <p class="sp-intro">
        Quick answers to the questions we hear most. Tap one to expand.
      </p>

      <div class="sp-faq-list">
        <div v-for="(item, idx) in faqs" :key="item.q" class="sp-faq">
          <button
            type="button"
            class="sp-faq-trigger"
            :aria-expanded="openIdx === idx"
            @click="toggle(idx)"
          >
            <span>{{ item.q }}</span>
            <ChevronDown :size="18" class="sp-faq-chev" :class="{ open: openIdx === idx }" />
          </button>
          <div v-if="openIdx === idx" class="sp-faq-body">
            {{ item.a }}
          </div>
        </div>
      </div>

      <div class="sp-contact-card">
        <div class="sp-contact-icon">
          <Mail :size="18" />
        </div>
        <div class="sp-contact-text">
          <p class="sp-contact-title">Still need help?</p>
          <p class="sp-contact-help">Email support@virdan.app — we usually reply within a day.</p>
        </div>
      </div>
    </section>
  </q-page>
</template>

<script setup lang="ts">
import { ref } from 'vue';
import { useRouter } from 'vue-router';
import { ChevronLeft, ChevronDown, Mail } from 'lucide-vue-next';

const router = useRouter();

interface Faq {
  q: string;
  a: string;
}

const faqs: Faq[] = [
  {
    q: 'What is a server in Virdan?',
    a: 'A server is a community space with its own members, posts, and identity. You can join multiple servers and have a different nickname, username, and avatar in each.',
  },
  {
    q: 'How do I create a server?',
    a: 'From the home page, open the server menu and tap "Create a server". Choose a name, short name, category, and your per-server profile, then invite friends with a generated link.',
  },
  {
    q: 'Can I change my username later?',
    a: 'Your @username is unique per server. Open Settings → Edit Profile while the relevant server is active to update it. The global account is identified by email only.',
  },
  {
    q: 'How do I change the email on my account?',
    a: 'Settings → Change Email. We send a 6-digit code to your current email; enter it on the next step to switch to your new address.',
  },
  {
    q: 'I forgot my password — what now?',
    a: 'On the login screen tap "Forgot password?" — we email a reset link to the address on your account. (Reset flow is rolling out, please reach out to support if you get stuck.)',
  },
  {
    q: 'How do I leave a server?',
    a: 'Open the server, tap the settings icon, scroll to the bottom, and tap Leave Server. Your per-server profile stays in your profile history.',
  },
  {
    q: 'How do I report a post or member?',
    a: 'Tap the … menu on a post or profile and choose Report. Our team reviews reports within 48 hours.',
  },
];

const openIdx = ref<number | null>(0);

function toggle(idx: number) {
  openIdx.value = openIdx.value === idx ? null : idx;
}

function onBack() {
  if (window.history.length > 1) router.back();
  else void router.push({ name: 'settings' });
}
</script>

<style lang="scss" scoped>
@import 'src/css/static-page.scss';
</style>
