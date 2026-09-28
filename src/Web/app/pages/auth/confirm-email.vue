<script setup lang="ts">
import { CircleAlert, CircleCheck, LoaderCircle, Mail } from '@lucide/vue'
import type { ConfirmEmailRequest, ResendConfirmationRequest } from '#shared/auth/auth.dto'
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
const status = ref<'loading' | 'success' | 'error'>('loading')
const errorMessage = ref('')

const resendEmail = ref('')
const resendStatus = ref<'idle' | 'sending' | 'sent'>('idle')

async function confirm() {
  const userId = route.query.userId
  const code = route.query.code

  if (typeof userId !== 'string' || typeof code !== 'string' || !userId || !code) {
    status.value = 'error'
    errorMessage.value = 'Ce lien de confirmation est invalide.'
    return
  }

  try {
    const body: ConfirmEmailRequest = { userId, code }
    await $fetch('/api/auth/confirm-email', { method: 'POST', body })
    status.value = 'success'
  } catch (err: any) {
    status.value = 'error'
    errorMessage.value = getErrorMessage(err)
  }
}

async function resend() {
  if (!resendEmail.value) return
  resendStatus.value = 'sending'
  try {
    const body: ResendConfirmationRequest = { email: resendEmail.value }
    await $fetch('/api/auth/resend-confirmation', { method: 'POST', body })
  } finally {
    // Always shown as sent: the endpoint itself never reveals whether the e-mail exists.
    resendStatus.value = 'sent'
  }
}

onMounted(confirm)
</script>

<template>
  <Card class="w-full max-w-md text-center">
    <CardHeader>
      <CardTitle class="text-2xl">Confirmation de l'e-mail</CardTitle>
      <CardDescription v-if="status === 'loading'">Vérification de votre lien en cours…</CardDescription>
    </CardHeader>

    <CardContent class="flex flex-col items-center gap-4">
      <LoaderCircle v-if="status === 'loading'" class="size-10 animate-spin text-muted-foreground" />

      <template v-else-if="status === 'success'">
        <CircleCheck class="size-10 text-primary" />
        <p class="text-sm text-muted-foreground">Votre e-mail a été confirmé. Vous pouvez maintenant vous connecter.</p>
      </template>

      <template v-else>
        <CircleAlert class="size-10 text-destructive" />
        <Alert variant="destructive">
          <AlertDescription>{{ errorMessage }}</AlertDescription>
        </Alert>

        <div v-if="resendStatus !== 'sent'" class="grid w-full gap-2 text-left">
          <Label for="resendEmail">Recevoir un nouveau lien</Label>
          <div class="flex gap-2">
            <Input
              id="resendEmail"
              v-model="resendEmail"
              type="email"
              placeholder="nom@exemple.com"
              autocomplete="email"
            />
            <Button variant="outline" :disabled="!resendEmail || resendStatus === 'sending'" @click="resend">
              <Mail class="size-4" />
              {{ resendStatus === 'sending' ? 'Envoi…' : 'Renvoyer' }}
            </Button>
          </div>
        </div>
        <Alert v-else>
          <AlertDescription>
            Si un compte correspond à cette adresse, un nouveau lien vient d'être envoyé.
          </AlertDescription>
        </Alert>
      </template>
    </CardContent>

    <CardFooter v-if="status !== 'loading'" class="justify-center">
      <Button as-child variant="link">
        <NuxtLink to="/auth/login">Retour à la connexion</NuxtLink>
      </Button>
    </CardFooter>
  </Card>
</template>