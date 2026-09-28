<script setup lang="ts">
import { Button } from '~/components/ui/button'
declare module 'nuxt/app' {
  interface NuxtLayouts {
    'guest': unknown
  }
}
definePageMeta({ layout: 'guest' })
</script>

<template>
  <div class="mx-auto max-w-2xl text-center">
    <h1 class="text-4xl font-bold tracking-tight sm:text-5xl">MiniCRM</h1>
    <p class="mt-4 text-lg text-muted-foreground">
      Gérez vos contacts, vos opportunités et vos échanges au même endroit.
    </p>
    <div class="mt-8 flex justify-center gap-3">
      <Button size="lg" as-child>
        <NuxtLink to="/auth/login">Se connecter</NuxtLink>
      </Button>
      <Button size="lg" variant="outline" as-child>
        <NuxtLink to="/auth/register">Créer un compte</NuxtLink>
      </Button>
    </div>
  </div>
</template>