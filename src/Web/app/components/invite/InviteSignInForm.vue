<!-- app/components/invite/InviteSignInForm.vue -->
<script setup lang="ts">
import { z } from 'zod'
import { Button } from '@/components/ui/button'
import { Input } from '@/components/ui/input'
import { Label } from '@/components/ui/label'
import { Alert, AlertDescription } from '@/components/ui/alert'

defineProps<{ emailHint: string }>()
const emit = defineEmits<{ signedIn: [] }>()

const schema = z.object({
  email: z.string().trim().toLowerCase().email('Enter a valid email address.'),
  password: z.string().min(1, 'Enter your password.'),
})

const form = reactive({ email: '', password: '' })
const fieldErrors = ref<Record<string, string>>({})
const serverError = ref<string | null>(null)
const submitting = ref(false)

async function submit() {
  serverError.value = null

  const parsed = schema.safeParse(form)
  if (!parsed.success) {
    const errors: Record<string, string> = {}
    for (const issue of parsed.error.issues) errors[String(issue.path[0] ?? '_')] ??= issue.message
    fieldErrors.value = errors
    return
  }
  fieldErrors.value = {}

  submitting.value = true
  try {
    // The existing route: it also creates the session cookie.
    await $fetch('/api/auth/login', { method: 'POST', body: parsed.data })
    emit('signedIn')
  } catch (e) {
    serverError.value = errorMessage(e, 'Sign-in failed. Check your email and password.')
  } finally {
    submitting.value = false
  }
}
</script>

<template>
  <form class="space-y-4" novalidate @submit.prevent="submit">
    <div class="space-y-2">
      <Label for="signin-email">Email</Label>
      <Input
        id="signin-email"
        v-model="form.email"
        type="email"
        autocomplete="email"
        :placeholder="emailHint"
        :aria-invalid="!!fieldErrors.email"
      />
      <p v-if="fieldErrors.email" class="text-sm text-destructive">{{ fieldErrors.email }}</p>
    </div>

    <div class="space-y-2">
      <Label for="signin-password">Password</Label>
      <Input id="signin-password" v-model="form.password" type="password" autocomplete="current-password" :aria-invalid="!!fieldErrors.password" />
      <p v-if="fieldErrors.password" class="text-sm text-destructive">{{ fieldErrors.password }}</p>
    </div>

    <Alert v-if="serverError" variant="destructive">
      <AlertDescription>{{ serverError }}</AlertDescription>
    </Alert>

    <Button type="submit" class="w-full" :disabled="submitting">
      {{ submitting ? 'Signing in' : 'Sign in' }}
    </Button>
  </form>
</template>