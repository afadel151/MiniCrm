<script setup lang="ts">
import 'vue-sonner/style.css'
import { Toaster } from '@/components/ui/sonner'
const { loggedIn, user, fetch: refreshClientSession } = useUserSession()
const route = useRoute()

async function logout() {
  await $fetch('/api/auth/logout', { method: 'POST' })
  await refreshClientSession()
  await navigateTo('/auth/login')
}
onMounted(() => {
  if (
    !loggedIn.value &&
    route.path !== '/' &&
    !route.path.startsWith('/auth/')
  ) {
    navigateTo('/auth/login')
  }
})
</script>
<template>
  <NuxtLoadingIndicator />
  <Toaster />
  <NuxtLayout>
    <NuxtPage />
  </NuxtLayout>
</template>
