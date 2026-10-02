<!-- app/pages/invite.vue -->
<script setup lang="ts">
import { Button } from '@/components/ui/button'
import { Alert, AlertDescription } from '@/components/ui/alert'
import { Skeleton } from '@/components/ui/skeleton'
definePageMeta({
    layout: 'guest',
    public: true
})
// The link carries a secret. Keep it out of Referer headers and search indexes.
useHead({
  title: 'Team invitation',
  meta: [
    { name: 'referrer', content: 'no-referrer' },
    { name: 'robots', content: 'noindex' },
  ],
})

const { user, token, preview, view, accepting, acceptError, registeredAs, init, load, accept, logout, onRegistered, onSignedIn } =
  useInviteFlow()

// The token lives in the URL fragment, which only exists in the browser.
onMounted(init)

const deadTitle = computed(() => {
  switch (preview.value?.status) {
    case 'Expired': return 'This invitation has expired'
    case 'Accepted': return 'This invitation was already used'
    default: return 'This invitation was cancelled'
  }
})
</script>

<template>
  <main class="mx-auto flex min-h-[70vh] w-full max-w-md flex-col justify-center gap-6 px-4 py-12">
    <div v-if="view === 'loading'" class="space-y-4" aria-busy="true">
      <Skeleton class="h-8 w-3/4" />
      <Skeleton class="h-4 w-full" />
      <Skeleton class="h-24 w-full" />
    </div>

    <section v-else-if="view === 'invalid'" class="space-y-3">
      <h1 class="text-2xl font-semibold tracking-tight">This invitation link doesn't work</h1>
      <p class="text-muted-foreground">
        Open the full link from the email. If it still fails, ask the business to send a new invitation.
      </p>
    </section>

    <section v-else-if="view === 'error'" class="space-y-4">
      <h1 class="text-2xl font-semibold tracking-tight">We couldn't load this invitation</h1>
      <p class="text-muted-foreground">Check your connection and try again.</p>
      <Button variant="outline" @click="load">Try again</Button>
    </section>

    <section v-else-if="view === 'dead' && preview" class="space-y-3">
      <h1 class="text-2xl font-semibold tracking-tight">{{ deadTitle }}</h1>
      <p class="text-muted-foreground">
        Ask {{ preview.inviterName }} at {{ preview.businessName }} to send a new invitation.
      </p>
    </section>

    <section v-else-if="view === 'not-eligible' && preview" class="space-y-4">
      <h1 class="text-2xl font-semibold tracking-tight">{{ preview.businessName }} needs a business account</h1>
      <p class="text-muted-foreground">
        {{ user ? 'You are signed in with a personal account.' : `${preview.emailHint} is registered as a personal account.` }}
        Only business accounts can join a team. Ask {{ preview.inviterName }} to invite a different email address.
      </p>
      <Button v-if="user" variant="outline" @click="logout">Sign out</Button>
    </section>

    <section v-else-if="view === 'register' && preview && token" class="space-y-6">
      <InviteSummary :preview="preview" />
      <InviteRegisterForm :token="token" @registered="onRegistered" @refresh="load" />
      <!-- Put your existing Google sign-in button here, with role forced to "Business" and no role picker. -->
    </section>

    <section v-else-if="view === 'signin' && preview" class="space-y-6">
      <InviteSummary :preview="preview" />
      <InviteSignInForm :email-hint="preview.emailHint" @signed-in="onSignedIn" />
      <!-- Put your existing Google sign-in button here, with role forced to "Business" and no role picker. -->
    </section>

    <section v-else-if="view === 'accept' && preview" class="space-y-6">
      <InviteSummary :preview="preview" />
      <p class="text-sm text-muted-foreground">Signed in as {{ user?.email }}.</p>
      <Alert v-if="acceptError" variant="destructive">
        <AlertDescription>{{ acceptError }}</AlertDescription>
      </Alert>
      <div class="flex flex-wrap gap-3">
        <Button :disabled="accepting" @click="accept">
          {{ accepting ? 'Joining' : 'Accept invitation' }}
        </Button>
        <Button variant="ghost" :disabled="accepting" @click="logout">Use another account</Button>
      </div>
    </section>

    <section v-else-if="view === 'wrong-account' && preview" class="space-y-4">
      <h1 class="text-2xl font-semibold tracking-tight">This invitation is for a different account</h1>
      <p class="text-muted-foreground">
        You are signed in as {{ user?.email }}, but the invitation was sent to {{ preview.emailHint }}.
        Sign out, then sign in with that address.
      </p>
      <Button variant="outline" @click="logout">Sign out</Button>
    </section>

    <section v-else-if="view === 'registered'" class="space-y-4">
      <h1 class="text-2xl font-semibold tracking-tight">Your account is ready</h1>
      <p class="text-muted-foreground">You joined {{ registeredAs }}. Sign in to continue.</p>
      <Button as-child>
        <NuxtLink to="/auth/login">Sign in</NuxtLink>
      </Button>
    </section>
  </main>
</template>