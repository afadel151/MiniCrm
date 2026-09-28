<script setup lang="ts">
import { Button } from '~/components/ui/button'
</script>

<template>
  <div class="flex min-h-svh flex-col bg-muted/40">
    <header class="border-b bg-background">
      <div class="mx-auto flex h-14 max-w-5xl items-center justify-between px-4">
        <NuxtLink to="/" class="text-lg font-semibold">MiniCRM</NuxtLink>
        <nav class="flex items-center gap-2">
          <Button variant="ghost" as-child>
            <NuxtLink to="/auth/login">Connexion</NuxtLink>
          </Button>
          <Button as-child>
            <NuxtLink to="/auth/register">Inscription</NuxtLink>
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