<script setup lang="ts">
import HeroText from "~/components/HeroText.vue";
import { Button } from "~/components/ui/button"
import { Tetris } from "~/components/ui/tetris";
interface Props {
  base?: number;
  squareColor?: string;
}
const { loggedIn, user, session, fetch: refreshClientSession, clear, openInPopup } = useUserSession()

const props = withDefaults(defineProps<Props>(), {
  base: 15,
  squareColor: "#6366F1",
});
definePageMeta({
  layout: "guest",
})
</script>

<template>

  <main>
    <section class="relative  z-10 overflow-hidden border-b">
      <Tetris :base="props.base" :square-color="props.squareColor"
        class="pointer-events-none absolute inset-0 -z-10 h-full w-full mask-[radial-gradient(500px_circle_at_50%_35%,#6366F1,transparent)]" />
      <div class="mx-auto max-w-7xl px-6 pb-20 pt-20 sm:pb-28 sm:pt-28">
        <div class="mx-auto max-w-3xl text-center">
          <HeroText />

          <p class="mx-auto mt-6 max-w-2xl text-balance text-lg leading-8 text-muted-foreground sm:text-xl">
            Centralisez vos contacts, entreprises, opportunités et échanges
            dans une seule plateforme pensée pour votre équipe.
          </p>

          <div class="mt-8 flex flex-col justify-center gap-3 sm:flex-row" v-if="!loggedIn">
            <Button size="lg" class="h-11 px-6 shadow-lg shadow-primary/20" as-child>
              <NuxtLink to="/auth/register">
                Créer un compte
                <span class="ml-2">→</span>
              </NuxtLink>
            </Button>

            <Button size="lg" variant="outline" class="h-11 px-6" as-child>
              <NuxtLink to="/auth/login">
                Se connecter
              </NuxtLink>
            </Button>
          </div>
          <div class="mt-8 flex flex-col justify-center gap-3 sm:flex-row" v-else>
            <Button size="lg" class="h-11 px-6 shadow-lg shadow-primary/20" as-child>
              <NuxtLink to="/dashboard">
                Dashboard
                <span class="ml-2">→</span>
              </NuxtLink>
            </Button>
          </div>

          <p class="mt-4 text-xs text-muted-foreground">
            Simple à utiliser · Rapide à prendre en main · Conçu pour les équipes
          </p>
        </div>

        <!-- Dashboard preview -->
        <div id="dashboard" class="mx-auto mt-16 max-w-6xl sm:mt-20">
          <div class="overflow-hidden rounded-2xl border bg-card shadow-2xl shadow-primary/10">
            <!-- Browser top bar -->
            <div class="flex items-center gap-2 border-b bg-muted/40 px-4 py-3">
              <div class="flex gap-1.5">
                <span class="size-2.5 rounded-full bg-muted-foreground/30" />
                <span class="size-2.5 rounded-full bg-muted-foreground/30" />
                <span class="size-2.5 rounded-full bg-muted-foreground/30" />
              </div>

              <div class="mx-auto hidden h-7 max-w-md flex-1 rounded-md border bg-background/80 sm:block" />
            </div>

            <!-- Dashboard -->
            <div class="grid min-h-[420px] grid-cols-12">
              <!-- Sidebar -->
              <aside class="hidden border-r bg-muted/20 p-4 md:col-span-3 md:block">
                <div class="mb-6 flex items-center gap-2">
                  <div
                    class="flex size-7 items-center justify-center rounded-md bg-primary text-xs font-bold text-primary-foreground">
                    M
                  </div>
                  <span class="font-semibold">MiniCRM</span>
                </div>

                <div class="space-y-1 text-sm">
                  <div class="rounded-md bg-primary/10 px-3 py-2 font-medium text-primary">
                    Tableau de bord
                  </div>
                  <div class="rounded-md px-3 py-2 text-muted-foreground">
                    Contacts
                  </div>
                  <div class="rounded-md px-3 py-2 text-muted-foreground">
                    Entreprises
                  </div>
                  <div class="rounded-md px-3 py-2 text-muted-foreground">
                    Opportunités
                  </div>
                  <div class="rounded-md px-3 py-2 text-muted-foreground">
                    Activités
                  </div>
                </div>
              </aside>

              <!-- Content -->
              <div class="col-span-12 p-5 sm:p-7 md:col-span-9">
                <div class="flex items-center justify-between">
                  <div>
                    <div class="text-xl font-semibold">Bonjour, bienvenue 👋</div>
                    <div class="mt-1 text-sm text-muted-foreground">
                      Voici un aperçu de votre activité.
                    </div>
                  </div>

                  <div class="hidden h-9 w-9 rounded-full bg-muted sm:block" />
                </div>

                <!-- Stats -->
                <div class="mt-7 grid gap-3 sm:grid-cols-3">
                  <div class="rounded-xl border bg-background p-4">
                    <p class="text-sm text-muted-foreground">Contacts</p>
                    <p class="mt-2 text-2xl font-semibold">1,284</p>
                    <p class="mt-1 text-xs text-emerald-600">+12,5% ce mois</p>
                  </div>

                  <div class="rounded-xl border bg-background p-4">
                    <p class="text-sm text-muted-foreground">Opportunités</p>
                    <p class="mt-2 text-2xl font-semibold">48</p>
                    <p class="mt-1 text-xs text-emerald-600">+8,2% ce mois</p>
                  </div>

                  <div class="rounded-xl border bg-background p-4">
                    <p class="text-sm text-muted-foreground">Pipeline</p>
                    <p class="mt-2 text-2xl font-semibold">€84.2K</p>
                    <p class="mt-1 text-xs text-emerald-600">+18,4% ce mois</p>
                  </div>
                </div>

                <!-- Recent activity -->
                <div class="mt-4 rounded-xl border bg-background p-4">
                  <div class="flex items-center justify-between">
                    <h3 class="font-medium">Activité récente</h3>
                    <span class="text-xs text-muted-foreground">
                      Voir tout
                    </span>
                  </div>

                  <div class="mt-4 space-y-4">
                    <div class="flex items-center gap-3">
                      <div
                        class="flex size-8 items-center justify-center rounded-full bg-primary/10 text-xs font-medium text-primary">
                        AM
                      </div>

                      <div class="min-w-0 flex-1">
                        <p class="truncate text-sm font-medium">
                          Nouveau contact ajouté
                        </p>
                        <p class="text-xs text-muted-foreground">
                          Alice Martin · Il y a 10 min
                        </p>
                      </div>

                      <div class="size-2 rounded-full bg-emerald-500" />
                    </div>

                    <div class="flex items-center gap-3">
                      <div
                        class="flex size-8 items-center justify-center rounded-full bg-primary/10 text-xs font-medium text-primary">
                        KB
                      </div>

                      <div class="min-w-0 flex-1">
                        <p class="truncate text-sm font-medium">
                          Opportunité mise à jour
                        </p>
                        <p class="text-xs text-muted-foreground">
                          Kamel Benali · Il y a 42 min
                        </p>
                      </div>

                      <div class="size-2 rounded-full bg-amber-500" />
                    </div>

                    <div class="flex items-center gap-3">
                      <div
                        class="flex size-8 items-center justify-center rounded-full bg-primary/10 text-xs font-medium text-primary">
                        SN
                      </div>

                      <div class="min-w-0 flex-1">
                        <p class="truncate text-sm font-medium">
                          Appel client planifié
                        </p>
                        <p class="text-xs text-muted-foreground">
                          Sarah Nouri · Il y a 1 h
                        </p>
                      </div>

                      <div class="size-2 rounded-full bg-primary" />
                    </div>
                  </div>
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>
    </section>

    <!-- Features -->
    <section id="features" class="border-t bg-muted/20">
      <div class="mx-auto max-w-7xl px-6 py-20 sm:py-24">
        <div class="mx-auto max-w-2xl text-center">
          <p class="text-sm font-medium text-primary">
            Tout ce dont vous avez besoin
          </p>

          <h2 class="mt-2 text-3xl font-bold tracking-tight sm:text-4xl">
            Un CRM pensé pour rester simple
          </h2>

          <p class="mt-4 text-muted-foreground">
            Une interface claire pour suivre votre activité sans vous perdre
            dans des fonctionnalités inutiles.
          </p>
        </div>

        <div class="mt-12 grid gap-4 md:grid-cols-3">
          <div
            class="group rounded-xl border bg-card p-6 transition-all hover:-translate-y-0.5 hover:border-primary/30 hover:shadow-lg">
            <div class="flex size-10 items-center justify-center rounded-lg bg-primary/10 text-primary">
              <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="currentColor"
                stroke-width="2" class="size-5">
                <path d="M16 21v-2a4 4 0 0 0-4-4H6a4 4 0 0 0-4 4v2" />
                <circle cx="9" cy="7" r="4" />
                <path d="M22 21v-2a4 4 0 0 0-3-3.87" />
                <path d="M16 3.13a4 4 0 0 1 0 7.75" />
              </svg>
            </div>

            <h3 class="mt-5 font-semibold">Contacts centralisés</h3>

            <p class="mt-2 text-sm leading-6 text-muted-foreground">
              Retrouvez toutes les informations de vos contacts et entreprises
              depuis un seul endroit.
            </p>
          </div>

          <div
            class="group rounded-xl border bg-card p-6 transition-all hover:-translate-y-0.5 hover:border-primary/30 hover:shadow-lg">
            <div class="flex size-10 items-center justify-center rounded-lg bg-primary/10 text-primary">
              <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="currentColor"
                stroke-width="2" class="size-5">
                <path d="M3 3v18h18" />
                <path d="m7 16 4-5 3 3 5-7" />
              </svg>
            </div>

            <h3 class="mt-5 font-semibold">Suivi des opportunités</h3>

            <p class="mt-2 text-sm leading-6 text-muted-foreground">
              Visualisez votre pipeline commercial et gardez une vue claire
              sur vos opportunités.
            </p>
          </div>

          <div
            class="group rounded-xl border bg-card p-6 transition-all hover:-translate-y-0.5 hover:border-primary/30 hover:shadow-lg">
            <div class="flex size-10 items-center justify-center rounded-lg bg-primary/10 text-primary">
              <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="currentColor"
                stroke-width="2" class="size-5">
                <path d="M3 12a9 9 0 1 0 18 0" />
                <path d="M12 3v9l6 3" />
              </svg>
            </div>

            <h3 class="mt-5 font-semibold">Activités & échanges</h3>

            <p class="mt-2 text-sm leading-6 text-muted-foreground">
              Gardez une trace des appels, tâches et interactions avec vos
              clients.
            </p>
          </div>
        </div>
      </div>
    </section>

    <!-- CTA -->
    <section class="border-t">
      <div class="mx-auto max-w-7xl px-6 py-20 sm:py-24">
        <div
          class="relative overflow-hidden rounded-2xl border bg-primary px-6 py-12 text-primary-foreground shadow-xl sm:px-12 sm:py-16">
          <div class="pointer-events-none absolute -right-20 -top-20 size-64 rounded-full bg-white/10 blur-3xl" />

          <div class="relative mx-auto max-w-2xl text-center">
            <h2 class="text-3xl font-bold tracking-tight sm:text-4xl">
              Prêt à mieux gérer vos clients ?
            </h2>

            <p class="mt-4 text-primary-foreground/75">
              Centralisez votre activité et donnez à votre équipe une vue
              claire de ses relations commerciales.
            </p>

            <div class="mt-8">
              <Button size="lg" variant="secondary" class="h-11 px-6" as-child>
                <NuxtLink to="/auth/register">
                  Commencer avec MiniCRM
                  <span class="ml-2">→</span>
                </NuxtLink>
              </Button>
            </div>
          </div>
        </div>
      </div>
    </section>
  </main>

  <!-- Footer -->
  <footer class="border-t">
    <div
      class="mx-auto flex max-w-7xl flex-col items-center justify-between gap-4 px-6 py-8 text-sm text-muted-foreground sm:flex-row">
      <div class="flex items-center gap-2">
        <div
          class="flex size-7 items-center justify-center rounded-md bg-primary text-xs font-bold text-primary-foreground">
          M
        </div>

        <span>MiniCRM</span>
      </div>

      <p>© {{ new Date().getFullYear() }} MiniCRM. Tous droits réservés.</p>
    </div>
  </footer>
</template>
