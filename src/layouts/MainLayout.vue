<template>
  <q-layout view="lHh Lpr lFf">
    <q-page-container>
      <router-view />
    </q-page-container>

    <q-footer
      v-if="!route.meta.hideBottomNav"
      bordered
      class="bg-white text-dark pb-safe nav-footer"
    >
      <q-tabs
        no-caps
        active-color="primary"
        indicator-color="transparent"
        class="text-grey-6"
        align="justify"
      >
        <q-route-tab name="home" to="/app/home" exact class="nav-tab">
          <template #default>
            <PhHouse :size="28" :weight="isActive('home') ? 'fill' : 'regular'" />
          </template>
        </q-route-tab>

        <q-route-tab name="explore" to="/app/explore" class="nav-tab">
          <template #default>
            <PhMagnifyingGlass
              :size="28"
              :weight="isActive('explore') ? 'bold' : 'regular'"
            />
          </template>
        </q-route-tab>

        <q-route-tab name="create-post" to="/app/create-post" class="nav-tab">
          <template #default>
            <PhPlusCircle
              :size="30"
              :weight="isActive('create-post') ? 'fill' : 'regular'"
            />
          </template>
        </q-route-tab>

        <q-route-tab name="notifications" to="/app/notifications" class="nav-tab">
          <template #default>
            <PhHeart :size="28" :weight="isActive('notifications') ? 'fill' : 'regular'" />
          </template>
        </q-route-tab>

        <q-route-tab name="profile" to="/app/profile" class="nav-tab">
          <template #default>
            <PhUserCircle :size="28" :weight="isActive('profile') ? 'fill' : 'regular'" />
          </template>
        </q-route-tab>
      </q-tabs>
    </q-footer>
  </q-layout>
</template>

<script setup lang="ts">
import { useRoute } from 'vue-router';
import {
  PhHouse, PhMagnifyingGlass, PhPlusCircle, PhHeart, PhUserCircle,
} from '@phosphor-icons/vue';

const route = useRoute();

function isActive(name: string): boolean {
  return route.name === name;
}
</script>

<style lang="scss">
.nav-footer {
  border-top: 1px solid #DEE2E6;
}

.nav-tab {
  min-height: 56px;

  .q-tab__content {
    padding: 0 !important;
  }
}
</style>
