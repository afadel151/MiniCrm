<!-- app/components/team/TeamInviteDialog.vue -->
<script setup lang="ts">
import { z } from 'zod'
import { toast } from 'vue-sonner'
import { Button } from '@/components/ui/button'
import { Input } from '@/components/ui/input'
import { Label } from '@/components/ui/label'
import { Alert, AlertDescription } from '@/components/ui/alert'
import {
  Dialog, DialogContent, DialogDescription, DialogFooter, DialogHeader, DialogTitle, DialogTrigger,
} from '@/components/ui/dialog'
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from '@/components/ui/select'
// import { type MemberRole, type CreatedInvitation } from '#shared/invitation.dto'

const props = defineProps<{ businessId: number; roles: MemberRole[] }>()
const emit = defineEmits<{ invited: [] }>()

// Mirrors what the API enforces: Staff can work with contacts, Managers can also run the business.
const ROLE_HELP: Record<MemberRole, string> = {
  Staff: 'Can view and edit contacts.',
  Manager: 'Can also edit the business, delete contacts and invite staff.',
}

const open = ref(false)
const email = ref('')
const role = ref<MemberRole>(props.roles[0] ?? 'Staff')
const error = ref<string | null>(null)
const submitting = ref(false)

watch(open, (isOpen) => {
  if (!isOpen) {
    email.value = ''
    error.value = null
    role.value = props.roles[0] ?? 'Staff'
  }
})

async function submit() {
  error.value = null
  const parsed = z.string().trim().toLowerCase().email().max(254).safeParse(email.value)
  if (!parsed.success) {
    error.value = 'Enter a valid email address.'
    return
  }

  submitting.value = true
  try {
    const r = await $fetch<CreatedInvitation>(`/api/backend/business/${props.businessId}/invitations`, {
      method: 'POST',
      body: { email: parsed.data, role: role.value },
    })
    if (r.emailSent) {
      toast.success(`Invitation sent to ${r.email}`)
    } else {
      toast.warning(`Invitation created, but the email to ${r.email} could not be sent. Invite the same address again to retry.`)
    }
    open.value = false
    emit('invited')
  } catch (e) {
    error.value = errorMessage(e, "We couldn't send the invitation. Try again.")
  } finally {
    submitting.value = false
  }
}
</script>

<template>
  <Dialog v-model:open="open">
    <DialogTrigger as-child>
      <Button>Invite someone</Button>
    </DialogTrigger>
    <DialogContent class="sm:max-w-md">
      <DialogHeader>
        <DialogTitle>Invite someone to your team</DialogTitle>
        <DialogDescription>
          They get an email with a link. They need a business account, and can create one from the link.
        </DialogDescription>
      </DialogHeader>

      <form class="space-y-4" novalidate @submit.prevent="submit">
        <div class="space-y-2">
          <Label for="invite-email">Email</Label>
          <Input id="invite-email" v-model="email" type="email" autocomplete="off" :aria-invalid="!!error" />
        </div>

        <div v-if="roles.length > 1" class="space-y-2">
          <Label for="invite-role">Role</Label>
          <Select v-model="role">
            <SelectTrigger id="invite-role">
              <SelectValue />
            </SelectTrigger>
            <SelectContent>
              <SelectItem v-for="r in roles" :key="r" :value="r">{{ roleLabel(r) }}</SelectItem>
            </SelectContent>
          </Select>
        </div>
        <p class="text-sm text-muted-foreground">
          {{ roles.length > 1 ? '' : 'They will join as staff. ' }}{{ ROLE_HELP[role] }}
        </p>

        <Alert v-if="error" variant="destructive">
          <AlertDescription>{{ error }}</AlertDescription>
        </Alert>

        <DialogFooter>
          <Button type="button" variant="ghost" @click="open = false">Cancel</Button>
          <Button type="submit" :disabled="submitting">{{ submitting ? 'Sending' : 'Send invitation' }}</Button>
        </DialogFooter>
      </form>
    </DialogContent>
  </Dialog>
</template>