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

</script>

<template>
  <Card class="w-full max-w-md text-center">
    <CardHeader>
      <CardTitle class="text-2xl">Confirmation de l'e-mail</CardTitle>
    </CardHeader>

    <CardContent class="flex flex-col items-center gap-4">
        <p>Nous avons envoye un lien de confirmation a votre adresse email, consultez votre boite e-mail</p>
    </CardContent>
  </Card>
</template>