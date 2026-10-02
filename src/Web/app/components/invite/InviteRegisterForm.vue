<!-- app/components/invite/InviteRegisterForm.vue -->
<script setup lang="ts">
import { Button } from '@/components/ui/button'
import { Input } from '@/components/ui/input'
import { Label } from '@/components/ui/label'
import { Alert, AlertDescription } from '@/components/ui/alert'
import { registerStaffSchema } from '#shared/invitations/schemas'

const props = defineProps<{ token: string }>()
const emit = defineEmits<{ registered: [result: JoinResult]; refresh: [] }>()

const form = reactive({ firstName: '', lastName: '', password: '', confirmPassword: '' })
const fieldErrors = ref<Record<string, string>>({})
const serverError = ref<string | null>(null)
const serverStatus = ref(0)
const submitting = ref(false)

async function submit() {
  serverError.value = null

  const parsed = registerStaffSchema.safeParse({ token: props.token, ...form })
  if (!parsed.success) {
    const errors: Record<string, string> = {}
    for (const issue of parsed.error.issues) errors[String(issue.path[0] ?? '_')] ??= issue.message
    fieldErrors.value = errors
    return
  }
  fieldErrors.value = {}

  submitting.value = true
  try {
    const result = await $fetch<JoinResult>('/api/invitations/register', {
      method: 'POST',
      body: parsed.data,
    })
    emit('registered', result)
  } catch (e) {
    serverStatus.value = errorStatus(e)
    serverError.value = errorMessage(e, "We couldn't create your account. Try again.")
  } finally {
    submitting.value = false
  }
}
</script>

<template>
  <form class="space-y-4" novalidate @submit.prevent="submit">
    <div class="grid gap-4 sm:grid-cols-2">
      <div class="space-y-2">
        <Label for="firstName">First name</Label>
        <Input id="firstName" v-model="form.firstName" autocomplete="given-name" :aria-invalid="!!fieldErrors.firstName" />
        <p v-if="fieldErrors.firstName" class="text-sm text-destructive">{{ fieldErrors.firstName }}</p>
      </div>
      <div class="space-y-2">
        <Label for="lastName">Last name</Label>
        <Input id="lastName" v-model="form.lastName" autocomplete="family-name" :aria-invalid="!!fieldErrors.lastName" />
        <p v-if="fieldErrors.lastName" class="text-sm text-destructive">{{ fieldErrors.lastName }}</p>
      </div>
    </div>

    <div class="space-y-2">
      <Label for="password">Password</Label>
      <Input id="password" v-model="form.password" type="password" autocomplete="new-password" :aria-invalid="!!fieldErrors.password" />
      <p v-if="fieldErrors.password" class="text-sm text-destructive">{{ fieldErrors.password }}</p>
    </div>

    <div class="space-y-2">
      <Label for="confirmPassword">Confirm password</Label>
      <Input id="confirmPassword" v-model="form.confirmPassword" type="password" autocomplete="new-password" :aria-invalid="!!fieldErrors.confirmPassword" />
      <p v-if="fieldErrors.confirmPassword" class="text-sm text-destructive">{{ fieldErrors.confirmPassword }}</p>
    </div>

    <p class="text-sm text-muted-foreground">Your account will use the email address this invitation was sent to.</p>

    <Alert v-if="serverError" variant="destructive">
      <AlertDescription>
        {{ serverError }}
        <Button v-if="serverStatus === 409" type="button" variant="link" class="h-auto p-0 pl-1" @click="emit('refresh')">
          Check again
        </Button>
      </AlertDescription>
    </Alert>

    <Button type="submit" class="w-full" :disabled="submitting">
      {{ submitting ? 'Creating account' : 'Create account and join' }}
    </Button>
  </form>
</template>