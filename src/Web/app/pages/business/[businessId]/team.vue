<!-- app/pages/business/[businessId]/team.vue -->
<script setup lang="ts">
import { Skeleton } from '@/components/ui/skeleton'
definePageMeta({
  layout: 'business',
  roles: ["Business"]
})
useHead({ title: 'Team' })

const route = useRoute()
const businessId = computed(() => Number(route.params.businessId))
const base = computed(() => `/api/backend/business/${businessId.value}`)

// server: false on purpose. A token refresh during SSR would lose its Set-Cookie, so authenticated data loads in the browser.
const {
  data: business,
  status: businessStatus,
  error: businessError,
} = useFetch<BusinessDetailDto>(() => base.value, { server: false })

const { data: members, refresh: refreshMembers } = useFetch<MemberDto[]>(() => `${base.value}/members`, { server: false })

// Mirrors the API: the primary owner invites any role, a manager invites staff, everyone else cannot invite.
const inviteRoles = computed<MemberRole[]>(() => {
  if (!business.value) return []
  if (business.value.iAmPrimaryOwner) return ['Staff', 'Manager']
  return business.value.myRole === 'Manager' ? ['Staff'] : []
})
const canSeeInvitations = computed(() => inviteRoles.value.length > 0)

const { data: invitations, refresh: refreshInvitations } = useFetch<InvitationListItem[]>(
  () => `${base.value}/invitations`,
  { server: false, immediate: false },
)
watch(canSeeInvitations, (allowed) => { if (allowed) refreshInvitations() }, { immediate: true })

const loadingBusiness = computed(() => businessStatus.value === 'idle' || businessStatus.value === 'pending')
const notFound = computed(() => Number.isNaN(businessId.value) || errorStatus(businessError.value) === 404)
</script>

<template>
  <main class="mx-auto w-full max-w-4xl space-y-10 px-4 py-10">
    <div v-if="loadingBusiness && !Number.isNaN(businessId)" class="space-y-4" aria-busy="true">
      <Skeleton class="h-8 w-48" />
      <Skeleton class="h-40 w-full" />
    </div>

    <section v-else-if="!business" class="space-y-3">
      <h1 class="text-2xl font-semibold tracking-tight">
        {{ notFound ? "We can't find this business" : "We couldn't load the team" }}
      </h1>
      <p class="text-muted-foreground">
        {{ notFound ? 'It may not exist, or you may not be a member of it.' : 'Reload the page. If it keeps failing, try again later.' }}
      </p>
    </section>

    <template v-else>
      <header class="flex flex-wrap items-end justify-between gap-4">
        <div>
          <h1 class="text-2xl font-semibold tracking-tight">Team</h1>
          <p class="text-muted-foreground">{{ business.businessName }}</p>
        </div>
        <TeamInviteDialog v-if="inviteRoles.length" :business-id="business.id" :roles="inviteRoles" @invited="refreshInvitations()" />
      </header>

      <TeamMembers :business="business" :members="members" @changed="refreshMembers()" />

      <TeamPendingInvitations
        v-if="canSeeInvitations"
        :business-id="business.id"
        :items="invitations"
        :invitable-roles="inviteRoles"
        @changed="refreshInvitations()"
      />
    </template>
  </main>
</template>