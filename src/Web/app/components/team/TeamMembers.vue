<!-- app/components/team/TeamMembers.vue -->
<script setup lang="ts">
import { toast } from 'vue-sonner'
import { Button } from '@/components/ui/button'
import { Badge } from '@/components/ui/badge'
import { Table, TableBody, TableCell, TableHead, TableHeader, TableRow } from '@/components/ui/table'
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from '@/components/ui/select'
import {
  AlertDialog, AlertDialogAction, AlertDialogCancel, AlertDialogContent, AlertDialogDescription,
  AlertDialogFooter, AlertDialogHeader, AlertDialogTitle,
} from '@/components/ui/alert-dialog'

const props = defineProps<{ business: BusinessDetailDto; members: MemberDto[] | null | undefined }>()
const emit = defineEmits<{ changed: [] }>()

const { user } = useUserSession()
const base = computed(() => `/api/backend/business/${props.business.id}/members`)

// Removed members stay in the database for history. They are not part of the team any more.
const active = computed(() => (props.members ?? []).filter((m) => m.isActive))

const isSelf = (m: MemberDto) => m.userId === user.value?.id

// These mirror the API rules. The API is the authority, this only decides which controls to show.
const canChangeRole = (m: MemberDto) => props.business.iAmPrimaryOwner && !m.isPrimaryOwner
const canRemove = (m: MemberDto) =>
  !m.isPrimaryOwner &&
  (isSelf(m) || props.business.iAmPrimaryOwner || (props.business.myRole === 'Manager' && m.role === 'Staff'))

const target = ref<MemberDto | null>(null)
const busy = ref(false)

async function changeRole(m: MemberDto, role: unknown) {
  if (typeof role !== 'string' || role === m.role) return
  busy.value = true
  try {
    await $fetch(`${base.value}/${m.membershipId}/role`, { method: 'PUT', body: { role } })
    toast.success(`${m.fullName} is now ${roleLabel(role).toLowerCase()}`)
    emit('changed')
  } catch (e) {
    toast.error(errorMessage(e))
    emit('changed') // put the select back to the real value
  } finally {
    busy.value = false
  }
}

async function confirmRemove() {
  const m = target.value
  if (!m) return
  busy.value = true
  try {
    await $fetch(`${base.value}/${m.membershipId}`, { method: 'DELETE' })
    if (isSelf(m)) {
      toast.success(`You left ${props.business.businessName}`)
      await navigateTo('/')
      return
    }
    toast.success(`${m.fullName} removed`)
    emit('changed')
  } catch (e) {
    toast.error(errorMessage(e))
  } finally {
    busy.value = false
    target.value = null
  }
}
</script>

<template>
  <section class="space-y-3">
    <h2 class="text-lg font-semibold tracking-tight">Members ({{ active.length }})</h2>

    <div class="overflow-x-auto rounded-md border">
      <Table>
        <TableHeader>
          <TableRow>
            <TableHead>Name</TableHead>
            <TableHead>Email</TableHead>
            <TableHead>Role</TableHead>
            <TableHead>Joined</TableHead>
            <TableHead class="text-right"><span class="sr-only">Actions</span></TableHead>
          </TableRow>
        </TableHeader>
        <TableBody>
          <TableRow v-for="m in active" :key="m.membershipId">
            <TableCell class="font-medium">
              {{ m.fullName }}
              <Badge v-if="isSelf(m)" variant="outline" class="ml-2">You</Badge>
            </TableCell>
            <TableCell>{{ m.email }}</TableCell>
            <TableCell>
              <Select v-if="canChangeRole(m)" :model-value="m.role" :disabled="busy" @update:model-value="(v) => changeRole(m, v)">
                <SelectTrigger class="h-8 w-32" :aria-label="`Role of ${m.fullName}`">
                  <SelectValue />
                </SelectTrigger>
                <SelectContent>
                  <SelectItem v-for="r in (['Manager', 'Staff'] as MemberRole[])" :key="r" :value="r">{{ roleLabel(r) }}</SelectItem>
                </SelectContent>
              </Select>
              <span v-else>{{ roleLabel(m.role, m.isPrimaryOwner) }}</span>
            </TableCell>
            <TableCell>{{ formatDate(m.createdAtUtc) }}</TableCell>
            <TableCell class="text-right">
              <Button v-if="canRemove(m)" size="sm" variant="ghost" :disabled="busy" @click="target = m">
                {{ isSelf(m) ? 'Leave' : 'Remove' }}
              </Button>
            </TableCell>
          </TableRow>
        </TableBody>
      </Table>
    </div>

    <AlertDialog :open="!!target" @update:open="(open) => { if (!open) target = null }">
      <AlertDialogContent>
        <AlertDialogHeader>
          <AlertDialogTitle>
            {{ target && isSelf(target) ? `Leave ${business.businessName}?` : `Remove ${target?.fullName}?` }}
          </AlertDialogTitle>
          <AlertDialogDescription>
            {{
              target && isSelf(target)
                ? 'You lose access to this business right away. You can only rejoin if someone invites you again.'
                : 'They lose access to this business right away. You can invite them again later.'
            }}
          </AlertDialogDescription>
        </AlertDialogHeader>
        <AlertDialogFooter>
          <AlertDialogCancel>Cancel</AlertDialogCancel>
          <AlertDialogAction @click="confirmRemove">
            {{ target && isSelf(target) ? 'Leave' : 'Remove' }}
          </AlertDialogAction>
        </AlertDialogFooter>
      </AlertDialogContent>
    </AlertDialog>
  </section>
</template>