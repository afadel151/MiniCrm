<script setup lang="ts">
import { Button } from '~/components/ui/button'
const { loggedIn, user, session, fetch : refreshClientSession, clear, openInPopup } = useUserSession()
async function logout() {
  await $fetch('/api/auth/logout', { method: 'POST' })
  await refreshClientSession() // the cookie is gone, so this makes loggedIn false on the client
  await navigateTo('/auth/login')
}
</script>

<template>
  <div class="flex min-h-svh flex-col bg-muted/40">
    <header class="border-b bg-background">
      <div class="mx-auto flex h-14 max-w-5xl items-center justify-between px-4">
        <NuxtLink to="/" class="text-lg font-semibold">MiniCRM</NuxtLink>
        <nav class="flex items-center gap-2" v-if="!loggedIn">
          <Button variant="ghost" as-child>
            <NuxtLink to="/auth/login">Connexion</NuxtLink>
          </Button>
          <Button as-child>
            <NuxtLink to="/auth/register">Inscription</NuxtLink>
          </Button>
        </nav>
        <nav v-else>
            {{  user?.email }}
            <Button @click="logout">
              Logout
            </Button>
        </nav>
      </div>
    </header>

    <main class="flex flex-1 items-center justify-center p-4">
      <slot />
    </main>

    <footer class="py-4 text-center text-sm text-muted-foreground">
      © {{ new Date().getFullYear() }} MiniCRM
    </footer>
  </div>
</template>