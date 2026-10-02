<script setup lang="ts">

import type { RegisterBusinessRequest, RegisterResponseData } from '~~/shared/auth/auth.dto'
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
import {
  Stepper,
  StepperItem,
  StepperSeparator,
  StepperTitle,
  StepperTrigger,
} from '@/components/ui/stepper'
import { Input } from '~/components/ui/input'
import { Label } from '~/components/ui/label'
import { Check, Circle, Dot } from '@lucide/vue'

definePageMeta({ layout: 'guest' ,public: true})

const PASSWORD_RULE = /^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)(?=.*[^A-Za-z0-9]).{8,}$/

const form = reactive<RegisterBusinessRequest>({
  firstName: '',
  lastName: '',
  email: '',
  password: '',
  confirmPassword: '',
  businessName: '',
  phoneNumber: ''
  // teamSize: 1,
})

const errorMessage = ref<string | null>(null)
const loading = ref(false)
const stepIndex = ref(1)
const stepEl = ref<HTMLElement | null>(null)

const steps = [
  { step: 1, title: 'Identité', description: 'Votre nom et votre e-mail' },
  { step: 2, title: 'Sécurité', description: 'Choisissez un mot de passe' },
  { step: 3, title: 'Entreprise', description: 'Parlez-nous de votre activité' },
]
const lastStep = steps.length
const currentStep = computed(() => steps[stepIndex.value - 1]!)

function validateStep(): boolean {
  errorMessage.value = null
  const inputs = stepEl.value?.querySelectorAll('input') ?? []
  for (const input of inputs) {
    if (!input.reportValidity()) return false
  }

  if (stepIndex.value === 2) {
    if (!PASSWORD_RULE.test(form.password)) {
      errorMessage.value =
        'Le mot de passe doit contenir 8 caractères minimum, une majuscule, une minuscule, un chiffre et un caractère spécial.'
      return false
    }
    if (form.password !== form.confirmPassword) {
      errorMessage.value = 'Les mots de passe ne correspondent pas.'
      return false
    }
  }
  return true
}

function nextStep() {
  if (stepIndex.value < lastStep && validateStep()) stepIndex.value++
}

function prevStep() {
  errorMessage.value = null
  if (stepIndex.value > 1) stepIndex.value--
}

// Enter key: advance on steps 1-2, submit on the last step.
async function onFormSubmit() {
  if (stepIndex.value < lastStep) return nextStep()
  if (!validateStep()) return
  await register()
}
async function successRegister() {
  await navigateTo({ path: '/auth/login', query: { registered: '1' } })

}
async function register() {
  loading.value = true
  errorMessage.value = null
  try {

    const data = await $fetch<RegisterResponseData>('/api/auth/register', {
      method: 'POST',
      body: { ...form, accountType: 'business' },
    })
    await navigateTo({ path: '/auth/login', query: { registered: '1', email: data.email } })
  } catch (err: any) {
    errorMessage.value = getErrorMessage(err)
  } finally {
    loading.value = false
  }
}

// Only let users jump back to steps they already completed.
function canGoTo(step: number) {
  return step < stepIndex.value
}
</script>

<template>
  <div class="w-full h-full  flex justify-center items-center">


    <Card class="w-full max-w-md">
      <CardHeader class="space-y-1.5">
        <CardTitle class="text-2xl">Créer un compte business</CardTitle>
        <CardDescription>Renseignez vos informations pour vous inscrire.</CardDescription>
      </CardHeader>

      <CardContent>
        <Stepper v-model="stepIndex" class="block ">
          <div class="mb-8 flex w-full items-start">
            <StepperItem v-for="(item, index) in steps" :key="item.step" v-slot="{ state }" :step="item.step"
              class="relative flex flex-1 flex-col items-center">
              <StepperSeparator v-if="index < steps.length - 1"
                class="absolute left-[calc(50%+22px)] right-[calc(-50%+22px)] top-4.5 block h-0.5 shrink-0 rounded-full bg-muted group-data-[state=completed]:bg-primary" />

              <StepperTrigger as-child>
                <Button type="button" size="icon" :variant="state === 'inactive' ? 'outline' : 'default'"
                  class="z-10 size-9 shrink-0 rounded-full"
                  :class="state === 'active' && 'ring-2 ring-ring ring-offset-2 ring-offset-background'"
                  :disabled="!canGoTo(item.step) && state !== 'active'"
                  :aria-label="`Étape ${item.step} : ${item.title}`">
                  <Check v-if="state === 'completed'" class="size-4" />
                  <Circle v-else-if="state === 'active'" class="size-4" />
                  <Dot v-else class="size-5" />
                </Button>
              </StepperTrigger>

              <StepperTitle class="mt-2 text-center text-xs font-medium transition sm:text-sm"
                :class="state === 'inactive' ? 'text-muted-foreground' : 'text-foreground'">
                {{ item.title }}
              </StepperTitle>
            </StepperItem>
          </div>
        </Stepper>

        <form class="grid " novalidate @submit.prevent="onFormSubmit">
          <p class="text-sm text-muted-foreground">{{ currentStep.description }}</p>

          <Alert v-if="errorMessage" variant="destructive">
            <AlertDescription>{{ errorMessage }}</AlertDescription>
          </Alert>

          <div ref="stepEl" class="grid min-h-44 content-start gap-4">
            <!-- Step 1: identity -->
            <template v-if="stepIndex === 1">
              <div class="grid gap-4 sm:grid-cols-2">
                <div class="grid gap-2">
                  <Label for="firstName">Prénom</Label>
                  <Input id="firstName" v-model="form.firstName" autocomplete="given-name" maxlength="100" required />
                </div>
                <div class="grid gap-2">number
                  <Label for="lastName">Nom</Label>
                  <Input id="lastName" v-model="form.lastName" autocomplete="family-name" maxlength="100" required />
                </div>
              </div>

              <div class="grid gap-2">
                <Label for="email">E-mail</Label>
                <Input id="email" v-model="form.email" type="email" autocomplete="email" placeholder="nom@exemple.com"
                  required />
              </div>

            </template>

            <!-- Step 2: password -->
            <template v-else-if="stepIndex === 2">
              <div class="grid gap-2">
                <Label for="password">Mot de passe</Label>
                <Input id="password" v-model="form.password" type="password" autocomplete="new-password" required />
                <p class="text-xs text-muted-foreground">
                  8 caractères minimum, avec une majuscule, une minuscule, un chiffre et un caractère spécial.
                </p>
              </div>

              <div class="grid gap-2">
                <Label for="confirmPassword">Confirmer le mot de passe</Label>
                <Input id="confirmPassword" v-model="form.confirmPassword" type="password" autocomplete="new-password"
                  required />
              </div>
            </template>

            <!-- Step 3: business -->
             <!-- TODO: remove businessName and phone number from the form -->
            <template v-else>
              <div class="grid gap-2">
                <Label for="businessName">Nom de l’entreprise</Label>
                <Input id="businessName" v-model="form.businessName" autocomplete="organization" maxlength="150"
                  required />
              </div>

              <div class="grid gap-4 sm:grid-cols-2">
                <div class="grid gap-2">
                  <Label for="phoneNumber">Téléphone</Label>
                  <Input id="phoneNumber" v-model="form.phoneNumber" type="tel" autocomplete="tel" />
                </div>
                <div class="grid gap-2">
                  <Label for="teamSize">Taille de l’équipe</Label>
                  <Input id="teamSize" type="number" inputmode="numeric" min="1" step="1" required />
                </div>
              </div>
            </template>
          </div>

          <div class="flex items-center justify-between gap-3">
            <Button type="button" variant="outline" :class="stepIndex === 1 && 'invisible'" :disabled="loading"
              @click="prevStep">
              Retour
            </Button>

            <Button v-if="stepIndex < lastStep" type="button" @click="nextStep">
              Suivant
            </Button>
            <Button v-else type="submit" :disabled="loading">
              {{ loading ? 'Création…' : 'Créer mon compte' }}
            </Button>
          </div>
        </form>
      </CardContent>

      <CardFooter class="justify-center flex-col space-y-1 text-sm text-muted-foreground">
        <GoogleSignInButton  role="business" @success="successRegister" @error="msg => errorMessage = msg" />

        <div>
          Déjà un compte ?
          <NuxtLink to="/auth/login" class="ml-1 font-medium text-foreground underline underline-offset-4">
            Se connecter
          </NuxtLink>
        </div>
      </CardFooter>
    </Card>
  </div>
</template>