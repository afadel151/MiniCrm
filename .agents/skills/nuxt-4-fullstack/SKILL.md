---
name: nuxt-4-fullstack
description: Authoritative reference for building, debugging, deploying, or migrating Nuxt 4 apps (Nuxt v4.x, July 2025). Use whenever the user works on a Nuxt 4 project or anything that sounds like one — even when they don't say "Nuxt 4". Trigger on any mention of `nuxt.config.ts`, the `app/` or `server/` directories, file-based routing in `pages/`, `defineNuxtRouteMiddleware`, `defineEventHandler`, `definePageMeta`, `defineNuxtModule`, composables like `useFetch` / `useAsyncData` / `useState` / `useCookie` / `useHead` / `useSeoMeta`, utilities like `navigateTo` / `createError` / `callOnce`, the `nuxi` CLI, hybrid rendering with `routeRules`, prerendering / `nuxt generate`, edge deploy via Nitro presets, `@nuxt/test-utils`, layers, modules, or upgrading Nuxt 3 → 4. Use it even for "just a Vue/Nuxt question" — it covers Nuxt 4-specific behavior (new `app/` srcDir, `shallowRef` data fetching, Unhead 2, split tsconfigs, route groups, delayed hydration, `shared/` dir) that differs from Nuxt 3 and plain Vue.
---

# Nuxt 4 — Full-Stack Framework

Authoritative knowledge for working with **Nuxt v4.x** (released July 15, 2025). Distilled from the official documentation at `https://nuxt.com/docs/4.x`. Stack: Vue 3 + Nitro 2 + Vite 6 + Unhead 2 + the new `app/` directory.

## How to use this skill

This SKILL.md is the **decision center**: it covers the headline changes, the directory layout, configuration essentials, decision trees ("which composable do I use?"), the quick-reference API table, and common pitfalls. For deep coverage of any one area, load the matching reference file below.

| If you need to… | Read |
|---|---|
| Pick between `useFetch` / `useAsyncData` / `$fetch`, manage `useState`, cookies | `references/data-fetching-state.md` |
| Write Nitro server routes, middleware, plugins, caching, storage, tasks | `references/server-nitro.md` |
| Set up pages, layouts, middleware, navigation, route validation | `references/routing-middleware.md` |
| Configure SSR / SPA / hybrid / prerender / edge deploy | `references/rendering-deployment.md` |
| Use or author a module with `@nuxt/kit`, work with layers | `references/modules-layers.md` |
| Look up the signature of a specific composable or utility | `references/composables-utils-api.md` |
| Write tests with `@nuxt/test-utils` | `references/testing.md` |
| Migrate a Nuxt 3 project to Nuxt 4 (codemods, compat flags, breaking changes) | `references/migration-v3-to-v4.md` |

When in doubt, read the relevant reference file **before** writing code — Nuxt 4 changed several defaults silently (data refs are `shallowRef` now, `data`/`error` default to `undefined` not `null`, `refresh({ dedupe: true })` was removed). Outdated patterns will compile but behave wrong.

---

## 1. Headline Nuxt 4 changes (read this first)

Nuxt 4 is a refinement of Nuxt 3, not a rewrite. Most behavior is identical, but **defaults changed** and a **new directory layout** is now standard. The most important shifts:

| Area | Nuxt 3 | Nuxt 4 (default) |
|---|---|---|
| Source directory | `srcDir: '.'` (root) | **`srcDir: 'app/'`** — `~/` resolves to `app/` |
| Server dir | `<srcDir>/server` | **`<rootDir>/server`** (outside `app/`) |
| `modules/`, `public/`, `layers/`, `content/` | under `srcDir` | resolved relative to **`<rootDir>`** |
| New `shared/` directory | — | shared between Vue app and Nitro; `shared/utils/` + `shared/types/` auto-imported |
| `useAsyncData` / `useFetch` `data` ref | `ref` (deep reactive) | **`shallowRef`** (use `deep: true` to opt out) |
| Same-key `useFetch` / `useAsyncData` calls | independent | **share `data` / `error` / `status`** — `handler`, `deep`, `transform`, `pick`, `getCachedData`, `default` must match |
| `getCachedData` called when? | only on initial fetch | **every fetch** with `{ cause: 'initial' \| 'refresh:manual' \| 'refresh:hook' \| 'watch' }` |
| Reactive keys in `useFetch` / `useAsyncData` | unsupported | **supported** (computed refs, getters) — auto-refetches |
| `data` / `error` defaults | `null` | **`undefined`** |
| `refresh({ dedupe: true \| false })` | allowed | **removed** — use `'cancel'` or `'defer'` |
| `pending` ref | always `true` until first fetch | computed: `true` only while `status === 'pending'` |
| `clear()` on `useAsyncData` | sets `data` to `undefined` | **respects `options.default()`** |
| Unhead | v1 | **v2** — drops `vmid`/`hid`/`children`/`body`; tags auto-sorted by Capo.js |
| TS config | single `tsconfig.json` | **split**: `tsconfig.app.json`, `tsconfig.server.json`, `tsconfig.shared.json`, `tsconfig.node.json` |
| `compilerOptions.noUncheckedIndexedAccess` | `false` | **`true`** — `arr[i]` is now `T \| undefined` |
| Component names | filename only | **normalized to include path** (Vue name = Nuxt auto-import name) |
| SPA loading template | inside `#__nuxt` | **alongside** `#__nuxt` (prevents flash) |
| Top-level `generate` config | available | **removed** — use `nitro.prerender` |
| Module loading order in layers | project before layers (wrong) | **layers first, project last** (correct) |
| `error.data` | string, must `JSON.parse` | **parsed automatically** |
| `window.__NUXT__` | available | **removed after hydration** — use `useNuxtApp().payload` |

**Every change above has a compatibility flag to revert it.** See `references/migration-v3-to-v4.md` for the full list and the codemod commands that automate migration.

---

## 2. The Nuxt 4 directory layout

```
<rootDir>/
├─ .nuxt/                  # generated dev/types output (ignore in git)
├─ .output/                # build output: .output/server/ + .output/public/
├─ app/                    # <-- srcDir — everything reached via ~/ lives here
│  ├─ assets/              # build-processed assets (CSS, fonts, images via bundler)
│  ├─ components/          # auto-imported, path-prefixed (base/foo/Btn.vue → <BaseFooBtn/>)
│  ├─ composables/         # auto-imported (TOP LEVEL ONLY by default)
│  ├─ layouts/             # NuxtLayout slots
│  ├─ middleware/          # route middleware (.global suffix => global)
│  ├─ pages/               # file-based routes (vue-router)
│  ├─ plugins/             # auto-registered (top-level + subdir/index.ts)
│  ├─ utils/               # auto-imported util fns
│  ├─ app.vue              # root component (renders <NuxtLayout><NuxtPage/></NuxtLayout>)
│  ├─ app.config.ts        # BUILD-TIME public config (reactive, HMR, no env-var override)
│  ├─ error.vue            # error page (renders on uncaught fatal errors)
│  ├─ router.options.ts    # custom vue-router options
│  └─ spa-loading-template.html  # shown when ssr: false
├─ content/                # Nuxt Content module (if installed)
├─ layers/                 # auto-registered layers (alphabetical = priority, Z > A)
├─ modules/                # local modules: modules/*/index.ts | modules/*.ts
├─ public/                 # served verbatim at /  (favicon, robots.txt)
├─ server/                 # Nitro — DIFFERENT TS context from app/
│  ├─ api/                 # /api/* endpoints
│  ├─ routes/              # non-/api routes (e.g. sitemap.xml)
│  ├─ middleware/          # runs on every request (must NOT respond)
│  ├─ plugins/             # Nitro plugins (defineNitroPlugin)
│  ├─ tasks/               # scheduled tasks (defineTask)
│  └─ utils/               # auto-imported in server context (#server alias)
├─ shared/                 # NEW in Nuxt 4 — usable from both app/ and server/
│  ├─ utils/               # auto-imported app- and server-side (#shared alias)
│  └─ types/               # auto-imported types
├─ nuxt.config.ts
├─ tsconfig.json           # references .nuxt/tsconfig.{app,server,shared,node}.json
├─ package.json
├─ .env / .env.test / .env.production
└─ .nuxtignore             # files Nuxt should skip when scanning
```

### Path aliases

| Alias | Resolves to | Use case |
|---|---|---|
| `~/`, `@/` | `<srcDir>` (i.e. `app/`) | app code |
| `~~/`, `@@/` | `<rootDir>` | project root |
| `#imports` | virtual barrel of auto-imports | explicit auto-import |
| `#components` | virtual components module | `import { X } from '#components'` |
| `#app` | Nuxt runtime types | `import type { NuxtError } from '#app'` |
| `#shared` | `<rootDir>/shared` | manual import from `shared/` |
| `#server` | `<rootDir>/server` | inside `server/` only |
| `#layers/<name>` | a layer's `srcDir` | reference a specific layer |
| `#build/<file>` | files in `.nuxt/` | virtual build files |

### Auto-import scanning rules (memorize)

- `app/components/` — **recursive**, name = path-prefixed (set `pathPrefix: false` to drop the prefix).
- `app/composables/` and `app/utils/` — **TOP LEVEL ONLY** by default. To recurse:
  ```ts
  // nuxt.config.ts
  imports: { dirs: ['~/composables/**', '~/composables/*/index.{ts,js,mjs,mts}'] }
  ```
- `app/plugins/` — top-level files + `subdir/index.ts`.
- `app/middleware/` — top-level files + child-folder `index` files.
- `shared/utils/` + `shared/types/` — auto-imported on both app and server side.
- `server/utils/` — auto-imported in Nitro context only.

To explicitly import an auto-imported symbol (e.g. for static analysis): `import { useFetch } from '#imports'`.

---

## 3. `nuxt.config.ts` essentials

```ts
export default defineNuxtConfig({
  modules: ['@nuxt/image', '@pinia/nuxt', '@nuxtjs/tailwindcss'],

  ssr: true,                                       // false => SPA mode

  // Hybrid rendering — per-route mode
  routeRules: {
    '/':           { prerender: true },            // build-time SSG
    '/products/**': { swr: 3600 },                 // stale-while-revalidate (sec)
    '/blog/**':    { isr: true },                  // incremental static regen
    '/admin/**':   { ssr: false },                 // client-only section
    '/api/**':     { cors: true },
    '/old':        { redirect: { to: '/new', statusCode: 301 } },
  },

  // Static app-level head
  app: {
    head: { title: 'My App', htmlAttrs: { lang: 'en' } },
    baseURL: '/',                                  // overridable: NUXT_APP_BASE_URL
    cdnURL:  '',                                   // overridable: NUXT_APP_CDN_URL
  },

  // Runtime config — private + public
  runtimeConfig: {
    apiSecret: '',                                 // private — server only; NUXT_API_SECRET
    public: {
      apiBase: '/api',                             // exposed to client; NUXT_PUBLIC_API_BASE
    },
  },

  css: ['~/assets/css/main.css'],

  // Per-environment override blocks
  $production:  { routeRules: { '/**': { isr: true } } },
  $development: { devtools: { enabled: true } },
  $env: { staging: { runtimeConfig: { public: { apiBase: 'https://staging.example.com' } } } },

  // Nitro (server) — replaces removed top-level `generate`
  nitro: {
    preset: 'node-server',                         // or vercel, netlify, cloudflare-pages…
    prerender: { routes: ['/sitemap.xml'], crawlLinks: true, ignore: ['/admin'] },
    storage: { redis: { driver: 'redis', host: '127.0.0.1', port: 6379 } },
  },

  typescript: { strict: true },

  experimental: {
    typedPages: true,                              // typed route names/params
    inlineRouteRules: true,                        // enables defineRouteRules() in pages
    componentIslands: true,                        // .server.vue components
    viewTransition: true,
  },
})
```

### `runtimeConfig` vs `app.config.ts` — pick the right one

| Property | `runtimeConfig` | `app.config.ts` |
|---|---|---|
| Overridable by env vars (`NUXT_*` / `NUXT_PUBLIC_*`) | ✅ | ❌ |
| Bundled at build time | ❌ (hydrated) | ✅ |
| HMR | ❌ | ✅ |
| Supports non-primitive types | ❌ (serialized) | ✅ |
| Use for | secrets, env-specific URLs | theme/colors/title constants |

### Env vars

- Files loaded: `.env`, `.env.local`, `.env.<envName>` (use `--envName staging` / `--dotenv path`).
- `NUXT_*` overrides `runtimeConfig.*`; `NUXT_PUBLIC_*` overrides `runtimeConfig.public.*`. Nested keys use underscores: `NUXT_PUBLIC_API_BASE` → `runtimeConfig.public.apiBase`.
- In production, **only `.env` is loaded by `nuxt preview`** — on real deployments inject env vars via the host platform.
- `nuxt generate` bakes values **at build time**.

---

## 4. Decision trees

### "Which data-fetching primitive?"

```
Fetching component data in <script setup>?
├─ Single $fetch call from a URL?              → useFetch(url, opts)
├─ Multi-step / non-$fetch handler (SDK, parallel)? → useAsyncData(key, handler, opts)
├─ Need to NOT block navigation?               → useLazyFetch / useLazyAsyncData
└─ Need to read data already fetched elsewhere by key? → useNuxtData(key)

Inside a click handler / form submit / event callback?
└─ $fetch(url, opts)              // not useFetch — useFetch is setup-only

Inside a Nitro server route (server/api/*)?
└─ $fetch (or event.$fetch for cookie/header forwarding)
```

**Hard rule:** never call bare `$fetch(...)` directly inside `<script setup>` for setup-time data — it will run twice (server + hydration). Wrap it with `useFetch` or `useAsyncData`.

### "Where does this file go?"

```
A Vue page?          → app/pages/<name>.vue
A reusable component? → app/components/<Name>.vue        (auto-imported)
A reactive helper?   → app/composables/<useThing>.ts     (top-level only!)
A pure function?     → app/utils/<thing>.ts
Code shared with server? → shared/utils/<thing>.ts        (auto-imported BOTH sides)
A server route?      → server/api/<name>.<method>.ts     (POST/GET/PATCH suffixes)
A server route NOT under /api? → server/routes/<path>.ts
Server-only helper?  → server/utils/<thing>.ts
A route middleware?  → app/middleware/<name>.ts          (.global.ts = run on every nav)
A server middleware? → server/middleware/<name>.ts       (runs on every request)
A Vue plugin / global init? → app/plugins/<name>.ts     (.client.ts / .server.ts to scope)
A Nitro plugin?      → server/plugins/<name>.ts
A scheduled task?    → server/tasks/<name>.ts
Custom module logic? → modules/<name>/index.ts
Layer to share across projects? → layers/<name>/ (or use `extends` in nuxt.config)
```

### "Which rendering mode?"

```
Content rarely changes, SEO matters?               → routeRules: { prerender: true }  (or nuxt generate)
Content changes per-user (auth, dashboards)?       → default SSR — { ssr: true }
Pure SPA, no SEO needs (admin tool)?               → ssr: false  (site-wide) or { ssr: false } per route
Want CDN caching with revalidation behind it?     → routeRules: { swr: 3600 } or { isr: 3600 }
Need low latency globally?                          → nitro.preset: 'cloudflare-pages' / 'vercel-edge'
```

---

## 5. Composables & utilities — quick reference

(See `references/composables-utils-api.md` for full signatures + options.)

| Symbol | Type | One-liner |
|---|---|---|
| `useFetch(url, opts)` | composable | SSR-safe data fetch tied to setup |
| `useAsyncData(key?, handler, opts)` | composable | Same, but for arbitrary async handlers |
| `useLazyFetch` / `useLazyAsyncData` | composable | Non-blocking variants (`lazy: true`) |
| `useNuxtData(key)` | composable | Read cached data without refetching |
| `useState<T>(key?, init?)` | composable | SSR-shared reactive state |
| `useCookie<T>(name, opts)` | composable | Read/write cookies SSR-safely |
| `useRuntimeConfig(event?)` | composable | Read runtime config (pass `event` server-side) |
| `useAppConfig()` | composable | Read `app.config.ts` |
| `useRoute()` / `useRouter()` | composable | vue-router access (NEVER `useRoute()` in middleware — use `to`) |
| `useHead(input)` | composable | Mutable `<head>` tags |
| `useSeoMeta(input)` | composable | Type-safe SEO-specific tags |
| `useHeadSafe(input)` | composable | Sanitized variant for untrusted input |
| `useServerSeoMeta(input)` | composable | Server-only SEO (zero client cost) |
| `useError()` | composable | Reactive global error |
| `useNuxtApp()` | composable | Access plugins, payload, hooks |
| `useRequestEvent()` | composable | h3 `event` server-side |
| `useRequestHeaders(keys?)` | composable | Forward incoming headers |
| `useRequestURL()` | composable | SSR-safe current URL |
| `useRequestFetch()` | composable | `$fetch` pre-bound to forward cookies/headers |
| `$fetch(url, opts)` | util | Direct HTTP — use in handlers, not setup |
| `navigateTo(to, opts)` | util | Programmatic navigation (return from middleware) |
| `abortNavigation(err?)` | util | Stop navigation from middleware |
| `definePageMeta(meta)` | macro | Build-time hoisted page meta (no reactive vals!) |
| `defineNuxtPlugin(plugin)` | util | Define a plugin |
| `defineNuxtRouteMiddleware(fn)` | util | Define route middleware |
| `defineRouteRules(rules)` | macro | Per-page route rule (needs `experimental.inlineRouteRules`) |
| `defineEventHandler(fn)` | server util | Define a Nitro handler |
| `defineCachedEventHandler` / `defineCachedFunction` | server util | Cache layer |
| `createError(input)` | util | Build an error object (status, statusText, data, fatal) |
| `showError(err)` / `clearError({redirect})` | util | Trigger / dismiss error page |
| `callOnce(fn, opts?)` | util | Run once per render/navigation (SSR-safe init) |
| `refreshNuxtData(keys?)` | util | Globally refresh keyed data |
| `clearNuxtData(keys?)` | util | Globally clear cached data |
| `refreshCookie('name')` | util | Re-read a cookie set out-of-band |
| `setPageLayout(name, props?)` | util | Switch layout dynamically |
| `addRouteMiddleware(name, mw, {global?})` | util | Register middleware at runtime (in plugins) |

### `import.meta` flags

```ts
if (import.meta.server)    { /* SSR */ }
if (import.meta.client)    { /* CSR */ }
if (import.meta.dev)       { /* dev only */ }
if (import.meta.test)      { /* in @nuxt/test-utils */ }
if (import.meta.prerender) { /* during prerender */ }
```
(`process.server` / `process.client` still work, but `import.meta.*` is preferred.)

---

## 6. Minimal end-to-end example

```ts
// nuxt.config.ts
export default defineNuxtConfig({
  modules: ['@pinia/nuxt', '@nuxt/image'],
  runtimeConfig: { apiSecret: '', public: { apiBase: '/api' } },
  routeRules: { '/': { prerender: true }, '/dashboard/**': { ssr: false } },
})
```

```vue
<!-- app/app.vue -->
<template>
  <NuxtLoadingIndicator />
  <NuxtLayout>
    <NuxtPage />
  </NuxtLayout>
</template>
```

```vue
<!-- app/pages/index.vue -->
<script setup lang="ts">
definePageMeta({ middleware: 'analytics' })
useSeoMeta({ title: 'Home', description: 'Welcome' })

interface Post { id: number; title: string }
const { data: posts, status, error, refresh } = await useFetch<Post[]>('/api/posts', {
  default: () => [],
  pick: ['id', 'title'],
})
</script>

<template>
  <section>
    <h1>Posts</h1>
    <p v-if="status === 'pending'">Loading…</p>
    <ul v-else>
      <li v-for="p in posts" :key="p.id">
        <NuxtLink :to="`/posts/${p.id}`">{{ p.title }}</NuxtLink>
      </li>
    </ul>
    <button @click="refresh()">Refresh</button>
  </section>
</template>
```

```ts
// server/api/posts.get.ts
import { defineCachedEventHandler } from 'nitropack/runtime'

export default defineCachedEventHandler(async () => {
  return [{ id: 1, title: 'Hello Nuxt 4' }]
}, { maxAge: 60 })
```

```ts
// app/middleware/analytics.global.ts
export default defineNuxtRouteMiddleware((to) => {
  if (import.meta.server) return
  // track(to.path)
})
```

```ts
// app/composables/useAuth.ts
export const useAuth = () => {
  const token = useCookie<string | null>('token', { default: () => null, sameSite: 'lax' })
  async function login(email: string, password: string) {
    const { token: t } = await $fetch<{ token: string }>('/api/login', {
      method: 'POST',
      body: { email, password },
    })
    token.value = t
    await refreshCookie('token')
  }
  return { token: readonly(token), login }
}
```

```ts
// server/api/login.post.ts
import { z } from 'zod'
const schema = z.object({ email: z.string().email(), password: z.string().min(8) })

export default defineEventHandler(async (event) => {
  const body = await readValidatedBody(event, schema.parse)
  setCookie(event, 'token', 'abc123', { httpOnly: true, sameSite: 'lax', secure: true })
  return { token: 'abc123' }
})
```

---

## 7. Common pitfalls cheat-sheet

| Symptom | Likely cause |
|---|---|
| `data.value` is the URL string instead of JSON | `useFetch` was imported from `@vueuse/core`, not Nuxt's auto-import |
| Data fetched twice (server + hydration) | Used `$fetch` instead of `useFetch` / `useAsyncData` in setup |
| Hydration mismatch | Reading `Date.now()`, `Math.random()`, or `window.*` in setup — wrap with `<ClientOnly>` or `import.meta.client` |
| `data` is `undefined` after `clearNuxtData` (was `null` before) | Nuxt 4 default — adjust template guards |
| `[Vue Router warn]: No match found` flooding prod logs | `NODE_ENV` not set to `production` |
| `definePageMeta` value not updating | Macro is hoisted at build — can't reference reactive state |
| `useState` resets across pages | Different key per page; use a stable key |
| Auto-imported composable not found in tests | Run `nuxt prepare` first, or use `mockNuxtImport` from `@nuxt/test-utils/runtime` |
| `getCachedData` called on every fetch (was once before) | Nuxt 4 — handle the `ctx.cause` argument |
| `pages:extend` hook can't mutate meta | Use `pages:resolved` hook instead — v4 scans meta after `pages:extend` |
| Cookie set via `$fetch` not visible in `useCookie` | Call `refreshCookie('name')` after the request — or enable `experimental.cookieStore: true` |
| Same-key `useFetch` calls warn about mismatched options | `handler`, `deep`, `transform`, `pick`, `getCachedData`, `default` must match across calls with the same key |
| `refresh({ dedupe: true })` errors | Removed in v4 — use `'cancel'` or `'defer'` (string values) |
| Layer not picked up | Layer must contain a `nuxt.config.ts` (even if empty) |
| `useRoute()` returns wrong route in middleware | Don't call it — use the `to` argument |
| `error.data` is a string you tried to `JSON.parse` | Already parsed in v4 — just read `error.data.foo` directly |

---

## 8. CLI cheat sheet (`nuxi`)

| Command | Purpose |
|---|---|
| `npm create nuxt@latest <name>` | Scaffold a new project |
| `nuxt dev` | Dev server with HMR |
| `nuxt build` | Production build → `.output/` |
| `nuxt generate` | Build + prerender → `.output/public/` (static) |
| `nuxt preview` | Run the built server locally |
| `nuxt analyze` | Visualize bundle size |
| `nuxt prepare` | Generate `.nuxt/` types only (run in CI before `tsc`) |
| `nuxt typecheck` | `vue-tsc --noEmit` (use `-b` flag with project references) |
| `nuxt add <entity>` | Scaffold a `page`, `component`, `composable`, `layout`, `plugin`, `middleware`, `api`, `module`, `layer` |
| `nuxt module add <name>` | Install + auto-configure a Nuxt module |
| `nuxt info` | Project diagnostics |
| `nuxt upgrade` | Upgrade Nuxt to latest |
| `nuxt cleanup` | Remove `.nuxt/`, `.output/`, caches |
| `nuxt devtools enable\|disable` | Toggle DevTools per project |

Pass `--envName <name>` to select an `$env.<name>` override block, e.g. `nuxt build --envName staging`.

---

## 9. Performance best practices

- Prefer **`useLazyFetch`** for non-critical data so navigation isn't blocked by Suspense.
- Use **`pick`** / **`transform`** to shrink the SSR payload.
- Keep `useFetch` / `useAsyncData` keys **stable AND unique** — use the route param in dynamic pages.
- Don't trigger Pinia store actions inside `useAsyncData` — use **`callOnce`** instead.
- Wrap libs that touch `window` in `<ClientOnly>` or `.client.vue` filename.
- Use **delayed hydration props** (`hydrate-on-visible`, `hydrate-when`, `hydrate-on-idle`) on heavy below-the-fold `Lazy*` components.
- Use **server components** (`*.server.vue` / `<NuxtIsland>`) to ship zero JS for static-but-server-rendered sections.
- Wrap repeated DB/API hits with `defineCachedFunction` / `defineCachedEventHandler`, or use `routeRules.cache`.
- Set **`NODE_ENV=production`** in production (silences Vue Router dev warnings).
- Use `@nuxt/image` for responsive images, `@nuxt/fonts` for self-hosted fonts, `@nuxt/scripts` for third-party scripts.
- Pass `event` to `useRuntimeConfig(event)` in server routes — without it, env-var overrides won't apply per-request.
- **Always `await navigateTo()`** or `return` it from middleware — otherwise the original navigation continues.

---

That's the high-level surface. For anything beyond this, **load the matching reference file from the table at the top.** When uncertain, prefer reading the reference file before guessing — Nuxt 4 has many subtle behavioral changes from v3 that don't surface until runtime.
