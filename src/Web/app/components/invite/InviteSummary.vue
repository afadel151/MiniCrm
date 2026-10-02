<script setup lang="ts">
// import type { InvitationPreview } from '#shared/invitation.dto'
 
defineProps<{ preview: InvitationPreview }>()
</script>
 
<template>
  <div>
    <!-- Business and inviter names are user-controlled: always text interpolation, never v-html. -->
    <h1 class="text-2xl font-semibold tracking-tight">Join {{ preview.businessName }}</h1>
    <p class="mt-2 text-muted-foreground">
      {{ preview.inviterName }} invited you to join the team as {{ roleInSentence(preview.role) }}.
    </p>
    <dl class="mt-6 grid grid-cols-[auto_1fr] gap-x-6 gap-y-2 text-sm">
      <dt class="text-muted-foreground">Sent to</dt>
      <dd>{{ preview.emailHint }}</dd>
      <dt class="text-muted-foreground">Expires</dt>
      <dd>{{ formatDate(preview.expiresAtUtc) }}</dd>
    </dl>
  </div>
</template>