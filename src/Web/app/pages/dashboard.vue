<script setup lang="ts">
import { Alert, AlertDescription } from '~/components/ui/alert'
import {
  Card,
  CardContent,
  CardDescription,
  CardFooter,
  CardHeader,
  CardTitle,
} from '~/components/ui/card'
const { user} = useUserSession()
// definePageMeta({ layout: 'guest' })
</script>


<template>
    <Card  class="w-full max-w-sm">
        <CardHeader>
            <CardTitle class="text-2xl">Connecté</CardTitle>
            <CardDescription>Voici le profil renvoyé par l'API.</CardDescription>
        </CardHeader>

        <CardContent class="grid gap-3 text-sm">
            <Alert v-if="user?.mustChangePassword">
                <AlertDescription>Vous devez changer votre mot de passe.</AlertDescription>
            </Alert>

            <dl class="grid grid-cols-[auto_1fr]  gap-x-4 gap-y-2">
                <dt class="text-muted-foreground">Nom</dt>
                <dd class="font-medium">{{ user?.firstName }} {{ user?.lastName }}</dd>
                <dt class="text-muted-foreground">E-mail</dt>
                <dd class="font-medium break-all">{{ user?.email }}</dd>
                <dt class="text-muted-foreground">Rôles</dt>
                <dd class="font-medium">{{ user?.role }}</dd>
            </dl>
        </CardContent>
    </Card>
</template>