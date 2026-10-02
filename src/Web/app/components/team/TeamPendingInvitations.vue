<!-- app/components/team/TeamPendingInvitations.vue -->
<script setup lang="ts">
import { toast } from 'vue-sonner'
import { Button } from '@/components/ui/button'
import { Badge } from '@/components/ui/badge'
import { Table, TableBody, TableCell, TableHead, TableHeader, TableRow } from '@/components/ui/table'

const props = defineProps<{
  businessId: number
  items: InvitationListItem[] | null | undefined
  /** Roles the current user may invite. The API enforces it, this only hides buttons. */
  invitableRoles: MemberRole[]
}>()
const emit = defineEmits<{ changed: [] }>()

const base = computed(() => `/api/backend/business/${props.businessId}/invitations`)
const busyId = ref<number | null>(null)

const STATUS_LABEL: Record<InvitationStatus, string> = {
  Pending: 'Pending',
  Accepted: 'Accepted',
  Revoked: 'Cancelled',
  Expired: 'Expired',
}
const STATUS_VARIANT: Record<InvitationStatus, 'default' | 'secondary' | 'outline'> = {
  Pending: 'secondary',
  Accepted: 'default',
  Revoked: 'outline',
  Expired: 'outline',
}

const canAct = (i: InvitationListItem) => i.status !== 'Accepted' && props.invitableRoles.includes(i.role)

// Inviting the same address again replaces the previous link, so "Resend" is a normal create call.
async function resend(i: InvitationListItem) {
  busyId.value = i.id
  try {
    const r = await $fetch<CreatedInvitation>(base.value, { method: 'POST', body: { email: i.email, role: i.role } })
    if (r.emailSent) toast.success(`Invitation sent to ${r.email}`)
    else toast.warning(`The email to ${r.email} could not be sent. Try again in a moment.`)
    emit('changed')
  } catch (e) {
    toast.error(errorMessage(e))
  } finally {
    busyId.value = null
  }
}

async function cancel(i: InvitationListItem) {
  busyId.value = i.id
  try {
    await $fetch(`${base.value}/${i.id}`, { method: 'DELETE' })
    toast.success('Invitation cancelled')
    emit('changed')
  } catch (e) {
    toast.error(errorMessage(e))
  } finally {
    busyId.value = null
  }
}
</script>

<template>
  <section class="space-y-3">
    <h2 class="text-lg font-semibold tracking-tight">Invitations</h2>

    <p v-if="!items?.length" class="text-sm text-muted-foreground">
      No invitations yet. Invite someone to give them access to this business.
    </p>

    <div v-else class="overflow-x-auto rounded-md border">
      <Table>
        <TableHeader>
          <TableRow>
            <TableHead>Email</TableHead>
            <TableHead>Role</TableHead>
            <TableHead>Status</TableHead>
            <TableHead>Invited by</TableHead>
            <TableHead>Expires</TableHead>
            <TableHead class="text-right"><span class="sr-only">Actions</span></TableHead>
          </TableRow>
        </TableHeader>
        <TableBody>
          <TableRow v-for="i in items" :key="i.id">
            <TableCell class="font-medium">{{ i.email }}</TableCell>
            <TableCell>{{ roleLabel(i.role) }}</TableCell>
            <TableCell>
              <Badge :variant="STATUS_VARIANT[i.status]">{{ STATUS_LABEL[i.status] }}</Badge>
            </TableCell>
            <TableCell>{{ i.invitedByName }}</TableCell>
            <TableCell>{{ i.status === 'Pending' ? formatDate(i.expiresAtUtc) : '' }}</TableCell>
            <TableCell class="text-right">
              <div v-if="canAct(i)" class="flex justify-end gap-1">
                <Button size="sm" variant="ghost" :disabled="busyId === i.id" @click="resend(i)">Resend</Button>
                <Button v-if="i.status === 'Pending'" size="sm" variant="ghost" :disabled="busyId === i.id" @click="cancel(i)">
                  Cancel invitation
                </Button>
              </div>
            </TableCell>
          </TableRow>
        </TableBody>
      </Table>
    </div>
  </section>
</template>