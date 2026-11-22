# Composables, Utilities, Lifecycle & TypeScript API

Full signature reference for every Nuxt 4 composable and utility, plus the request lifecycle and TypeScript setup. Use as a lookup table — search for the symbol you need.

## Table of contents

1. Data fetching composables
2. State & config composables
3. Routing composables & utils
4. Head / SEO composables
5. App & request composables
6. Error utilities
7. Lifecycle / hooks utilities
8. Component & chunk utilities
9. Server-only utilities (recap)
10. `import.meta` flags
11. The Nuxt lifecycle
12. Runtime hooks reference
13. TypeScript setup

---

## 1. Data fetching composables

(Full detail in `data-fetching-state.md`.)

```ts
useFetch<T>(url, options?): Promise<AsyncData<T>>
useAsyncData<T>(key?, handler, options?): Promise<AsyncData<T>>
useLazyFetch<T>(url, options?): Promise<AsyncData<T>>          // = useFetch(..., { lazy: true })
useLazyAsyncData<T>(key?, handler, options?): Promise<AsyncData<T>>
useNuxtData<T>(key): { data: Ref<T | undefined> }              // read cached, no refetch
```

`AsyncData<T>` shape:

```ts
{
  data:    Ref<T | undefined>       // shallowRef by default in v4
  pending: Ref<boolean>             // computed: true only while status === 'pending'
  error:   Ref<NuxtError | undefined>
  status:  Ref<'idle' | 'pending' | 'success' | 'error'>
  refresh: (opts?) => Promise<void>
  execute: (opts?) => Promise<void> // alias of refresh
  clear:   () => void
}
```

Factory composables (project-wide defaults):

```ts
const useApiFetch = createUseFetch({ baseURL: '/api', credentials: 'include' })
const useApiData  = createUseAsyncData({ /* defaults */ })
```

---

## 2. State & config composables

```ts
useState<T>(key?, init?: () => T | Ref<T>): Ref<T>
useCookie<T>(name, options?): Ref<T>
useRuntimeConfig(event?): RuntimeConfig           // pass event on server side!
useAppConfig(): AppConfig
updateAppConfig(patch): void                       // merge into app config at runtime
```

`useCookie` options: `maxAge`, `expires`, `httpOnly`, `secure`, `domain`, `path`, `sameSite`, `default`, `watch` (`true | 'shallow' | false`), `readonly`, `refresh`, `encode`, `decode`.

---

## 3. Routing composables & utils

```ts
useRoute(): RouteLocationNormalizedLoaded          // setup only — NEVER in middleware
useRouter(): Router                                 // .push, .replace, .back, .go, .resolve
navigateTo(to, options?): Promise<...> | ...
abortNavigation(err?): false
addRouteMiddleware(name, middleware, { global? }): void
setPageLayout(name, props?): void
onBeforeRouteLeave(guard): void                     // vue-router guard in setup
onBeforeRouteUpdate(guard): void
definePageMeta(meta): void                          // compiler macro
defineRouteRules(rules): void                       // compiler macro (needs experimental flag)
defineNuxtRouteMiddleware(fn): NavigationGuard
```

`navigateTo` options: `replace`, `redirectCode`, `external`, `open: { target, windowFeatures }`.

`useRouter()` methods:

```ts
const router = useRouter()
router.push('/path')
router.push({ name: 'product', params: { slug: 'x' } })   // typed with experimental.typedPages
router.replace('/path')
router.back(); router.forward(); router.go(-2)
router.resolve({ name: 'home' })                           // → resolved route, no nav
router.beforeEach((to, from) => { /* guard */ })
router.afterEach((to, from) => { /* hook */ })
```

---

## 4. Head / SEO composables

```ts
useHead(input, options?): void                      // reactive head tags
useHeadSafe(input, options?): void                  // sanitized variant
useSeoMeta(input): void                             // type-safe SEO meta
useServerSeoMeta(input): void                       // server-only (no client cost)
```

`useHead` input keys: `title`, `titleTemplate`, `templateParams`, `meta[]`, `link[]`, `script[]`, `noscript[]`, `style[]`, `htmlAttrs`, `bodyAttrs`, `base`.

`useSeoMeta` input: flat typed keys like `title`, `description`, `ogTitle`, `ogDescription`, `ogImage`, `ogUrl`, `ogType`, `twitterCard`, `twitterTitle`, `twitterImage`, `robots`, `author`, `keywords`, `charset`, `viewport`, etc.

---

## 5. App & request composables

```ts
useNuxtApp(): NuxtApp                                // plugins, payload, hooks, $injected
tryUseNuxtApp(): NuxtApp | null                      // safe variant (returns null outside context)
useRequestEvent(): H3Event | undefined               // server-side h3 event
useRequestHeaders<K>(keys?): Record<K, string>       // incoming request headers (SSR)
useRequestHeader(name): string | undefined           // single header shortcut
useRequestURL(): URL                                 // SSR-safe current URL
useRequestFetch(): typeof $fetch                      // $fetch pre-bound to forward cookies/headers
useResponseHeader(name, value?): Ref<string>         // set/get response header (SSR effective)
useHydration(key, getServer, setClient): void        // sync a server value to client manually
usePreviewMode(options?): { enabled: Ref<boolean>; state: Ref }  // CMS preview
useRouteAnnouncer(): { message, polite, set, assertive }
useAnnouncer(): typeof useRouteAnnouncer
useLoadingIndicator(): { isLoading, progress, start, finish, clear, error }
useId(): string                                      // SSR-safe unique IDs for a11y
```

`useNuxtApp()` exposes:

```ts
const nuxtApp = useNuxtApp()
nuxtApp.payload                  // serialized SSR payload (replaces window.__NUXT__)
nuxtApp.static                   // static prerendered payload
nuxtApp.isHydrating              // true during initial client hydration
nuxtApp.hook(name, cb)           // register a runtime hook
nuxtApp.callHook(name, ...args)  // call a hook
nuxtApp.vueApp                   // the underlying Vue app instance
nuxtApp.provide(name, value)     // add a $injected helper
nuxtApp.runWithContext(fn)       // run fn with Nuxt context (for async-after-await composable calls)
nuxtApp.$config                  // runtimeConfig shortcut
```

⚠️ `window.__NUXT__` is **removed after hydration** in Nuxt 4 — use `useNuxtApp().payload` instead.

### `runWithContext` — for composables after `await`

```ts
const nuxtApp = useNuxtApp()
await someAsyncThing()
// Calling a Nuxt composable here can lose context — wrap it:
const route = nuxtApp.runWithContext(() => useRoute())
```

---

## 6. Error utilities

```ts
useError(): Ref<NuxtError | undefined>
createError(input): NuxtError                        // input: string | { status, statusText, message, data, fatal, cause }
showError(error): void                               // trigger error page
clearError(options?: { redirect?: string }): Promise<void>
```

`NuxtError` shape: `{ statusCode, statusMessage, message, data, stack, cause, name, fatal, unhandled }`.

---

## 7. Lifecycle / hooks utilities

```ts
callOnce(fn, options?: { mode?: 'render' | 'navigation' }): Promise<void>
callOnce(key, fn, options?): Promise<void>           // with explicit key
onNuxtReady(cb): void                                 // after hydration completes (client only)
onPrehydrate(cb): void                                // inline script before hydration
definePayloadReducer(name, reduce): void              // custom payload serialization
definePayloadReviver(name, revive): void              // custom payload deserialization
definePayloadPlugin(plugin): void                     // register reducers/revivers
prerenderRoutes(routes): void                         // add routes to prerender at runtime
```

---

## 8. Component & chunk utilities

```ts
prefetchComponents(names): Promise<void>              // download component chunks
preloadComponents(names): Promise<void>              // preload (higher priority)
preloadRouteComponents(path): Promise<void>          // preload a route's components
reloadNuxtApp(options?: { path?, ttl?, force?, persistState? }): void   // hard reload
defineNuxtComponent(options): Component               // Options-API helper w/ asyncData + head
defineNuxtPlugin(plugin): Plugin                      // fn or object form
defineLazyHydrationComponent(strategy, loader): Component  // programmatic lazy hydration
```

`defineNuxtComponent` (Options API, supports `asyncData` and `head`):

```ts
export default defineNuxtComponent({
  async asyncData() {
    return { posts: await $fetch('/api/posts') }
  },
  head() {
    return { title: 'Posts' }
  },
})
```

`defineLazyHydrationComponent`:

```ts
const LazyChart = defineLazyHydrationComponent('visible', () => import('./Chart.vue'))
// strategies: 'visible' | 'idle' | 'interaction' | 'mediaQuery' | 'if' | 'time' | 'never'
```

---

## 9. Server-only utilities (recap — see `server-nitro.md`)

```ts
defineEventHandler(fn) / eventHandler(fn)
defineCachedEventHandler(fn, options)
defineCachedFunction(fn, options)
defineNitroPlugin(fn)
defineTask({ meta, run })
defineWebSocketHandler({ open, message, close, error })
defineRouteMeta(meta)                                 // OpenAPI metadata for a route
```

Plus all h3 helpers (`readBody`, `getQuery`, `createError`, `setCookie`, `sendRedirect`, etc.).

---

## 10. `import.meta` flags

```ts
import.meta.server      // running on the server (SSR/Nitro)
import.meta.client      // running in the browser
import.meta.dev         // dev mode
import.meta.test        // under @nuxt/test-utils
import.meta.prerender   // during prerendering
import.meta.browser     // alias of client
import.meta.nitro       // inside Nitro
import.meta.hot         // Vite HMR API (dev only)
```

These are statically replaced at build time → dead-code elimination removes the non-matching branch from each bundle. Prefer them over `process.server` / `process.client` (which still work but aren't tree-shaken as cleanly).

---

## 11. The Nuxt lifecycle

### Build / dev startup

1. Load `nuxt.config.ts` + layers (layers' modules first, then project — Nuxt 4 order)
2. Run all modules' `setup()` → `modules:done` hook
3. Scan pages → `pages:extend` → scan page meta → `pages:resolved` hook
4. Generate templates / types → `app:templates`, `prepare:types`
5. Build Nitro server → `nitro:config`, `nitro:init`
6. `ready` hook (Nitro available via `useNitro()`)

### Per request (SSR)

1. Nitro middleware (`server/middleware/*`) runs
2. Route matched:
   - **Server route** (`/api/*`, `server/routes/*`) → handler runs → response
   - **Page** → Vue SSR (`renderRoute`):
     1. Plugins run (in order: `enforce: 'pre'` → default → `'post'`)
     2. Global middleware → route validation → named/inline middleware
     3. `app:created` → `app:beforeMount`
     4. Page setup runs; `<Suspense>` awaits `useAsyncData` / `useFetch`
     5. Serialize payload (devalue) → `app:rendered`
     6. Send HTML

### Client hydration (first load)

1. Plugins run again (client-side)
2. Middleware runs — **skipped** when `nuxtApp.isHydrating && payload.serverRendered`
3. `app:mounted`
4. Page setup hydrates against server HTML
5. `onNuxtReady` callbacks fire

### Subsequent client navigations

1. Global middleware → route validation → route middleware
2. `page:start` → `<NuxtPage>` setup (`useAsyncData`/`useFetch` may use cached data)
3. Render → `page:finish` → `page:transition:finish`

---

## 12. Runtime hooks reference

Register via `useNuxtApp().hook('name', cb)` (usually inside a plugin).

| Hook | When |
|---|---|
| `app:created` | Vue app instance created |
| `app:beforeMount` | Before mounting (client) |
| `app:mounted` | After mounting (client) |
| `app:rendered` | After SSR render (server) |
| `app:redirected` | Before SSR redirect |
| `app:suspense:resolve` | After Suspense resolves |
| `app:error` | A fatal error occurred |
| `app:error:cleared` | Error was cleared |
| `app:chunkError` | A JS chunk failed to load |
| `vue:setup` | Vue setup (sync) |
| `vue:error` | Vue error (SSR + CSR) |
| `page:start` | Page navigation starts |
| `page:finish` | Page navigation finishes |
| `page:loading:start` / `page:loading:end` | Loading indicator |
| `page:transition:finish` | After page transition |
| `link:prefetch` | A `<NuxtLink>` is prefetched |

Build-time hooks (used in modules / `nuxt.config` `hooks`): `modules:before`, `modules:done`, `pages:extend`, `pages:resolved`, `app:resolve`, `app:templates`, `prepare:types`, `build:before`, `build:done`, `ready`, `close`, `builder:watch`, `nitro:config`, `nitro:init`, `prerender:routes`, `prerender:generate`, `prerender:done`.

---

## 13. TypeScript setup

### Split tsconfig (Nuxt 4)

```json
// tsconfig.json (root)
{
  "files": [],
  "references": [
    { "path": "./.nuxt/tsconfig.app.json" },
    { "path": "./.nuxt/tsconfig.server.json" },
    { "path": "./.nuxt/tsconfig.shared.json" },
    { "path": "./.nuxt/tsconfig.node.json" }
  ]
}
```

| Context | tsconfig | Covers |
|---|---|---|
| App | `tsconfig.app.json` | `app/` (Vue components, composables, plugins) |
| Server | `tsconfig.server.json` | `server/` (Nitro) |
| Shared | `tsconfig.shared.json` | `shared/` |
| Node | `tsconfig.node.json` | `nuxt.config.ts`, `modules/` (build-time) |

Type-check:

```bash
nuxt prepare              # generate .nuxt/ types first (run in CI!)
vue-tsc -b --noEmit       # the -b flag = build mode for project references
# or simply:
nuxt typecheck
```

⚠️ `noUncheckedIndexedAccess: true` is on by default in Nuxt 4 — `array[i]` is typed `T | undefined`, `obj[key]` is `V | undefined`. Add explicit guards or use `array.at(i)`.

### Type runtime config

```ts
// shared/types/runtime-config.d.ts (or anywhere — but augment from the right context)
declare module 'nuxt/schema' {
  interface RuntimeConfig {
    apiSecret: string
    db: { url: string }
  }
  interface PublicRuntimeConfig {
    apiBase: string
    siteUrl: string
  }
}
export {}
```

### Type `useState` keys (manual generics)

```ts
const user = useState<User | null>('user', () => null)
```

### Augment `NuxtApp` for `$injected` helpers

```ts
declare module '#app' {
  interface NuxtApp { $myHelper(): void }
}
declare module 'vue' {
  interface ComponentCustomProperties { $myHelper(): void }
}
export {}
```

### Augmentation context rules (Nuxt 4 + project references)

Because of split tsconfigs, augmentations must be **declared in the right context** to take effect:
- App-facing augmentations → declare from a file inside `app/` or `shared/`
- Server augmentations → declare from a file inside `server/` or `shared/`
- Cross-cutting → put in `shared/types/`

### Typed pages

```ts
// nuxt.config.ts
experimental: { typedPages: true }
```

Generates typed route helpers — `router.push({ name, params })` and `<NuxtLink :to="{ name }">` become type-checked. Requires pages to have names.

### Importing auto-imports explicitly (for clarity/tooling)

```ts
import { ref, computed } from 'vue'
import { useFetch, useState, navigateTo } from '#imports'
import type { NuxtError } from '#app'
```

---

## Quick "which thing am I looking for?" index

- **Fetch data in setup** → `useFetch` / `useAsyncData` (§1)
- **Fetch data in a click handler** → `$fetch`
- **Shared reactive state** → `useState` (§2)
- **Cookies** → `useCookie` (§2)
- **Config / secrets** → `useRuntimeConfig` (§2)
- **Constants / theme** → `useAppConfig` (§2)
- **Navigate** → `navigateTo` (§3)
- **Current route info** → `useRoute` (§3)
- **Programmatic router** → `useRouter` (§3)
- **`<head>` tags** → `useHead` / `useSeoMeta` (§4)
- **h3 event server-side** → `useRequestEvent` (§5)
- **Forward cookies/headers** → `useRequestHeaders` / `useRequestFetch` (§5)
- **Current error** → `useError` (§6)
- **Throw an error** → `createError` (§6)
- **Init once** → `callOnce` (§7)
- **After hydration** → `onNuxtReady` (§7)
- **Plugin internals/payload** → `useNuxtApp` (§5)
