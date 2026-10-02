<script setup lang="ts">
import { Building2, ChevronRight, UserRound } from '@lucide/vue'
import {
  Card,
  CardContent,
  CardDescription,
  CardFooter,
  CardHeader,
  CardTitle,
} from '~/components/ui/card'

definePageMeta({ layout: 'guest',public: true })

const roles = [
  {
    to: '/auth/client/register',
    icon: UserRound,
    title: 'Particulier',
    description: "Je cherche à contacter des vendeurs et suivre mes échanges.",
  },
  {
    to: '/auth/business/register',
    icon: Building2,
    title: 'Business',
    description: 'Je vends des produits ou services et je veux gérer mes clients.',
  },
] as const
</script>

<template>
  <Card class="w-full max-w-lg">
    <CardHeader>
      <CardTitle class="text-2xl">Créer un compte</CardTitle>
      <CardDescription>Choisissez le type de compte qui vous correspond.</CardDescription>
    </CardHeader>

    <CardContent>
      <div class="grid gap-4 sm:grid-cols-2">
        <NuxtLink
          v-for="role in roles"
          :key="role.to"
          :to="role.to"
          class="group flex flex-col items-start gap-3 rounded-lg border p-4 text-left transition-colors hover:border-primary hover:bg-accent focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ring"
        >
          <span class="flex size-10 items-center justify-center rounded-md bg-primary/10 text-primary">
            <component :is="role.icon" class="size-5" />
          </span>
          <span class="flex w-full items-center justify-between font-medium">
            {{ role.title }}
            <ChevronRight class="size-4 text-muted-foreground transition-transform group-hover:translate-x-0.5" />
          </span>
          <span class="text-sm text-muted-foreground">{{ role.description }}</span>
        </NuxtLink>
      </div>
    </CardContent>

    <CardFooter class="justify-center text-sm text-muted-foreground">
      Déjà un compte ?
      <NuxtLink to="/auth/login" class="ml-1 font-medium text-foreground underline underline-offset-4">
        Se connecter
      </NuxtLink>
    </CardFooter>
  </Card>
</template>