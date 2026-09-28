<script setup lang="ts">
import type { RegisterResponseData, RegisterUserRequest } from '~~/shared/auth/auth.dto'
import { Alert, AlertDescription } from '~/components/ui/alert'
import { Button } from '~/components/ui/button'
import {
  Card,
  CardContent,
  CardDescription,
  CardFooter,
  CardHeader,
  CardTitle,
} from '~/components/ui/card'
import { Input } from '~/components/ui/input'
import { Label } from '~/components/ui/label'

definePageMeta({ layout: 'guest' })

const form = reactive<RegisterUserRequest>({
  firstName: '',
  lastName: '',
  email: '',
  password: '',
  confirmPassword: '',
})
const errorMessage = ref<string | null>(null)
const loading = ref(false)

async function onSubmit() {
  errorMessage.value = null

  if (form.password !== form.confirmPassword) {
    errorMessage.value = 'Les mots de passe ne correspondent pas.'
    return
  }

  loading.value = true

  try {
      const data : RegisterResponseData = await $fetch(
          '/api/auth/register',
          {
            method: 'POST', 
            body: { ...form, 
              accountType: 'client' 
            }
          });
    await navigateTo({ path: "/auth/login", query: { registered: '1',email: data.email }})
  } catch (err: any) {
    errorMessage.value = getErrorMessage(err)
  } finally {
    loading.value = false
  }
}
</script>

<template>
  <Card class="w-full max-w-md">
    <CardHeader>
      <CardTitle class="text-2xl">Créer un compte client</CardTitle>
      <CardDescription>Renseignez vos informations pour vous inscrire.</CardDescription>
    </CardHeader>

    <CardContent>
      <form class="grid gap-4" @submit.prevent="onSubmit">
        <Alert v-if="errorMessage" variant="destructive">
          <AlertDescription>{{ errorMessage }}</AlertDescription>
        </Alert>

        <div class="grid grid-cols-2 gap-4">
          <div class="grid gap-2">
            <Label for="firstName">Prénom</Label>
            <Input id="firstName" v-model="form.firstName" autocomplete="given-name" maxlength="100" required />
          </div>
          <div class="grid gap-2">
            <Label for="lastName">Nom</Label>
            <Input id="lastName" v-model="form.lastName" autocomplete="family-name" maxlength="100" required />
          </div>
        </div>

        <div class="grid gap-2">
          <Label for="email">E-mail</Label>
          <Input
            id="email"
            v-model="form.email"
            type="email"
            autocomplete="username"
            placeholder="nom@exemple.com"
            required
          />
        </div>

        <div class="grid gap-2">
          <Label for="password">Mot de passe</Label>
          <Input
            id="password"
            v-model="form.password"
            type="password"
            autocomplete="new-password"
            required
          />
          <p class="text-xs text-muted-foreground">
            8 caractères minimum, avec une majuscule, une minuscule, un chiffre et un caractère spécial.
          </p>
        </div>

        <div class="grid gap-2">
          <Label for="confirmPassword">Confirmer le mot de passe</Label>
          <Input
            id="confirmPassword"
            v-model="form.confirmPassword"
            type="password"
            autocomplete="new-password"
            required
          />
        </div>

        <Button type="submit" class="w-full" :disabled="loading">
          {{ loading ? 'Création…' : 'Créer mon compte' }}
        </Button>
      </form>
    </CardContent>

    <CardFooter class="justify-center text-sm text-muted-foreground">
      Déjà un compte ?
      <NuxtLink to="/auth/login" class="ml-1 font-medium text-foreground underline underline-offset-4">
        Se connecter
      </NuxtLink>
    </CardFooter>
  </Card>
</template>