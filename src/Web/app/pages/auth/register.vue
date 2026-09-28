<script setup lang="ts">
import { BuildingComplex, UserRound } from '@lucide/vue';
// import { toast } from 'vue-sonner'
import {
  Card,
  CardContent,
  CardDescription,
  CardHeader,
  CardTitle,
} from '~/components/ui/card'
definePageMeta({ layout: 'guest' })
</script>

<template>
  <Card class="w-full max-w-md">
    <CardHeader>
      <CardTitle class="text-2xl">Créer un compte</CardTitle>
      <CardDescription>Choisissez quel type de compte vous voulez creer.</CardDescription>
    </CardHeader>

    <CardContent>
        <BuildingComplex />
        <UserRound />
    </CardContent>
  </Card>
</template>

<!-- RegisterBusinessRequest -->