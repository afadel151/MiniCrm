<script setup lang="ts">
import type { LoginRequest, UserDto } from '~~/shared/auth/auth.dto'
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

const route = useRoute()
const justRegistered = computed(() => route.query.registered === '1')

const { fetch: refreshClientSession } = useUserSession()

const form = reactive<LoginRequest>({ email: justRegistered.value ? route.query.email as string : "", password: "" })
const errorMessage = ref<string | null>(null)
const loading = ref(false)
const loggedInUser = ref<UserDto | null>(null)

async function onSubmit() {
  errorMessage.value = null
  loading.value = true
  try {
    const res = await $fetch<{ user: UserDto }>('/api/auth/login', {
      method: 'POST',
      body: form,
    })
    loggedInUser.value = res.user
    await refreshClientSession() // syncs useUserSession() with the cookie the server route just set

    // if (res.user.mustChangePassword) { await navigateTo('/account/change-password'); return }
    // await navigateTo('/dashboard')
  } catch (err: any) {
    errorMessage.value = getErrorMessage(err)
  } finally {
    loading.value = false
  }
}
</script>

<template>
  <Card v-if="!loggedInUser" class="w-full max-w-sm">
    <CardHeader>
      <CardTitle class="text-2xl">Connexion</CardTitle>
      <CardDescription>Entrez votre e-mail et votre mot de passe.</CardDescription>
    </CardHeader>

    <CardContent>
      <form class="grid gap-4" @submit.prevent="onSubmit">
        <Alert v-if="justRegistered">
          <AlertDescription>Compte créé. Vous pouvez maintenant vous connecter.</AlertDescription>
        </Alert>

        <Alert v-if="errorMessage" variant="destructive">
          <AlertDescription>{{ errorMessage }}</AlertDescription>
        </Alert>

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
            autocomplete="current-password"
            required
          />
        </div>

        <Button type="submit" class="w-full" :disabled="loading">
          {{ loading ? 'Connexion…' : 'Se connecter' }}
        </Button>
      </form>
    </CardContent>

    <CardFooter class="justify-center text-sm text-muted-foreground">
      Pas encore de compte ?
      <NuxtLink to="/auth/register" class="ml-1 font-medium text-foreground underline underline-offset-4">
        Créer un compte
      </NuxtLink>
    </CardFooter>
  </Card>

  <Card v-else class="w-full max-w-sm">
    <CardHeader>
      <CardTitle class="text-2xl">Connecté</CardTitle>
      <CardDescription>Voici le profil renvoyé par l'API.</CardDescription>
    </CardHeader>

    <CardContent class="grid gap-3 text-sm">
      <Alert v-if="loggedInUser.mustChangePassword">
        <AlertDescription>Vous devez changer votre mot de passe.</AlertDescription>
      </Alert>

      <dl class="grid grid-cols-[auto_1fr] gap-x-4 gap-y-2">
        <dt class="text-muted-foreground">Nom</dt>
        <dd class="font-medium">{{ loggedInUser.firstName }} {{ loggedInUser.lastName }}</dd>
        <dt class="text-muted-foreground">E-mail</dt>
        <dd class="font-medium break-all">{{ loggedInUser.email }}</dd>
        <dt class="text-muted-foreground">Rôles</dt>
        <dd class="font-medium">{{ loggedInUser.roles.join(', ') }}</dd>
      </dl>
    </CardContent>
  </Card>
</template>