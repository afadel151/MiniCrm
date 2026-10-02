<script setup lang="ts">
import { Button } from '~/components/ui/button'
const { loggedIn, user, fetch: refreshClientSession } = useUserSession()
async function logout() {
  await $fetch('/api/auth/logout', { method: 'POST' })
  await refreshClientSession()
  await navigateTo('/auth/login')
}
</script>

<template>
  <div class="min-h-screen bg-background flex flex-col items-center text-foreground">
    <header class="sticky w-full  top-0 z-50 border-b bg-background/50 backdrop-blur-xl">
      <div class="mx-auto flex h-16 max-w-7xl items-center justify-between px-6">
        <NuxtLink to="/" class="flex items-center gap-2">
          <div class="flex size-8 items-center justify-center rounded-lg bg-primary text-primary-foreground shadow-sm">
            <span class="text-sm font-bold">M</span>
          </div> <span class="text-lg font-semibold tracking-tight"> MiniCRM
          </span>
        </NuxtLink>
        <nav class="hidden items-center gap-6 text-sm text-muted-foreground md:flex"> <a href="#features"
            class="transition-colors hover:text-foreground"> Fonctionnalités </a> <a href="#dashboard"
            class="transition-colors hover:text-foreground"> Aperçu </a> </nav>
        <div class="flex items-center gap-2" v-if="!loggedIn">
          <Button variant="ghost" as-child class="hidden sm:inline-flex">
            <NuxtLink to="/auth/login"> Se connecter </NuxtLink>
          </Button> <Button as-child>
            <NuxtLink to="/auth/register"> Creee un compte </NuxtLink>
          </Button>
        </div>
        <div class="flex items-center gap-2" v-else>
          <p>{{ user?.email }}</p>
          <Button @click="logout">
            Logout
          </Button>
        </div>
      </div>

    </header>
    <div class="flex-1 flex justify-center items-center w-full">
      <slot />
    </div>
  </div>

</template>