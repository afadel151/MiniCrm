<script setup lang="ts">
import 'vue-sonner/style.css'
import { Toaster } from '@/components/ui/sonner'
const { loggedIn, user, fetch: refreshClientSession } = useUserSession()
const route = useRoute()

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
