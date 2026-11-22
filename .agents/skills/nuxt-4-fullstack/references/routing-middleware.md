# Routing, Pages, Layouts & Route Middleware

Deep reference for the routing layer — file-based pages, `definePageMeta`, layouts, `<NuxtLink>`, `navigateTo`, route middleware, and validation.

## Table of contents

1. File-based routes in `app/pages/`
2. `app.vue` and `<NuxtPage>`
3. Dynamic routes, catch-all, optional params
4. Route groups (`(folder)`)
5. Nested routes
6. `definePageMeta`
7. `<NuxtLink>`
8. `navigateTo` / `abortNavigation`
9. Route middleware (named, global, inline, anonymous)
10. Route validation
11. Layouts
12. Switching layout dynamically
13. Typed pages (experimental)
14. Hash + scroll behavior + transitions

---

## 1. File-based routes

```
app/pages/
├─ index.vue                  → /
├─ about.vue                  → /about
├─ users-[group]/[id].vue     → /users-:group/:id
├─ blog/
│  ├─ [...slug].vue           → /blog/*               (catch-all)
│  └─ [[draft]].vue           → /blog AND /blog/:draft (optional param)
├─ (marketing)/about.vue      → /about (route group — URL-invisible)
└─ parent.vue + parent/child.vue → /parent and /parent/child (nested)
```

Rules:
- Pages **must have a single root element** (HTML comments count as elements).
- Remove `app/pages/` entirely to drop vue-router from the bundle. To force-enable: `pages: true` in `nuxt.config`.
- Filenames are converted to route names: `users/[id].vue` → name `users-id`. Override via `definePageMeta({ name: 'user' })`.

---

## 2. `app.vue` and `<NuxtPage>`

```vue
<!-- app/app.vue -->
<template>
  <NuxtLoadingIndicator />
  <NuxtLayout>
    <NuxtPage />
  </NuxtLayout>
</template>
```

`<NuxtPage>` is where the matched page renders. Optional props:
- `name`: target a named view
- `route`: pass a specific `RouteLocationNormalized`
- `pageKey`: change to force re-mount (e.g. `:page-key="route.fullPath"`)
- `transition`, `keepalive`: control transitions / `<KeepAlive>`

---

## 3. Dynamic routes

| Pattern | Filename | URL |
|---|---|---|
| Single param | `[id].vue` | `/123` |
| Multiple params | `[group]/[id].vue` | `/admin/42` |
| Catch-all | `[...slug].vue` | `/a/b/c` — `params.slug` = `'a/b/c'` |
| Optional | `[[draft]].vue` | `/`, `/preview` (both match) |
| Mixed text + param | `users-[id].vue` | `/users-42` |
| Custom regex via path | (any) + `definePageMeta({ path: '/:id(\\d+)' })` | `/123` only |

Access params:

```vue
<script setup>
const route = useRoute()
const id = route.params.id              // string | string[]
</script>
```

---

## 4. Route groups — `(folder)`

Folders wrapped in parentheses are **URL-invisible** but group routes logically. The group name lands on `route.meta.groups: string[]`.

```
app/pages/
├─ (marketing)/about.vue         → /about      route.meta.groups = ['marketing']
├─ (marketing)/contact.vue       → /contact    route.meta.groups = ['marketing']
└─ (app)/dashboard.vue           → /dashboard  route.meta.groups = ['app']
```

Use cases:
- Group routes by feature without affecting URL
- Apply layout / middleware via global middleware that reads `route.meta.groups`

---

## 5. Nested routes

```
app/pages/
├─ parent.vue                 → /parent (contains <NuxtPage> for child)
└─ parent/
   ├─ index.vue               → /parent
   └─ child.vue               → /parent/child
```

```vue
<!-- app/pages/parent.vue -->
<template>
  <div>
    <h2>Parent</h2>
    <NuxtPage />              <!-- child renders here -->
  </div>
</template>
```

---

## 6. `definePageMeta`

Compiler macro — values are hoisted out at build time. **Cannot reference reactive state, refs, or local variables** declared in the same `<script setup>`.

```vue
<script setup lang="ts">
definePageMeta({
  name: 'product',
  path: '/products/:slug',
  alias: ['/p/:slug'],
  validate: (route) => /^\d+/.test(String(route.params.slug)),
  middleware: ['auth', (to) => { /* inline */ }],
  layout: { name: 'panel', props: { sidebar: true, title: 'Products' } },
  key: route => route.fullPath,
  keepalive: true,
  pageTransition: { name: 'fade', mode: 'out-in' },
  scrollToTop: true,
})
</script>
```

### Full `PageMeta` interface

```ts
interface PageMeta {
  validate?: (route) => boolean | Promise<boolean> | Partial<NuxtError>
  redirect?: RouteRecordRedirectOption
  name?: string
  path?: string                                      // custom matcher
  alias?: string | string[]
  middleware?: MiddlewareKey | NavigationGuard | Array<MiddlewareKey | NavigationGuard>
  layout?: false | LayoutKey | { name: LayoutKey; props?: Record<string, unknown> }
  key?: false | string | ((route) => string)
  keepalive?: boolean | KeepAliveProps
  pageTransition?: boolean | TransitionProps
  layoutTransition?: boolean | TransitionProps
  viewTransition?: boolean | 'always' | object       // experimental
  scrollToTop?: boolean | ((to, from) => boolean)
  props?: boolean | object | ((route) => object)
  groups?: string[]                                  // read-only — set by (folder) syntax
  [custom: string]: unknown                          // extend via module augmentation
}
```

### Augment `PageMeta` with custom fields

```ts
// shared/types/page-meta.d.ts
declare module '#app' {
  interface PageMeta {
    requiresAuth?: boolean
    sidebar?: 'collapsed' | 'expanded' | 'hidden'
  }
}
export {}
```

---

## 7. `<NuxtLink>`

Renders `<a href>` for internal/external, prefetches the linked page's chunk + payload when visible, and handles SPA navigation. For external URLs, falls back to a regular `<a>` (so `target="_blank"` works correctly).

```vue
<NuxtLink to="/blog/hello">Read</NuxtLink>
<NuxtLink to="/products/42" prefetch>View</NuxtLink>
<NuxtLink :to="{ name: 'user', params: { id: 42 } }">Profile</NuxtLink>
<NuxtLink to="https://nuxt.com" external target="_blank">Docs</NuxtLink>

<!-- Prefetch on hover/focus only, not on visibility -->
<NuxtLink to="/heavy" :prefetch-on="{ interaction: true, visibility: false }">Heavy</NuxtLink>

<!-- Disable prefetching entirely for a link -->
<NuxtLink to="/admin" no-prefetch>Admin</NuxtLink>
```

Common props:

| Prop | Type | Purpose |
|---|---|---|
| `to` | `RouteLocationRaw` | The destination |
| `href` | `string` | Alias for `to` |
| `external` | `boolean` | Force external (full-page) navigation |
| `replace` | `boolean` | History `replaceState` instead of `pushState` |
| `target` | `'_blank' \| '_self' \| string` | Standard `<a>` target |
| `activeClass` | `string` | Class when route matches loosely |
| `exactActiveClass` | `string` | Class when route matches exactly |
| `prefetch` | `boolean` | Force prefetch |
| `noPrefetch` | `boolean` | Disable prefetch |
| `prefetchOn` | `{ visibility?: boolean; interaction?: boolean }` | Configure when prefetch fires |
| `prefetchedClass` | `string` | Class after prefetch completes |

Global defaults:

```ts
// nuxt.config.ts
app: {
  pageTransition: { name: 'fade', mode: 'out-in' },
  layoutTransition: { name: 'fade', mode: 'out-in' },
}
// NuxtLink defaults
experimental: { defaults: { nuxtLink: { activeClass: 'nuxt-link-active', prefetch: true } } }
```

---

## 8. `navigateTo` / `abortNavigation`

```ts
navigateTo(
  to: RouteLocationRaw | undefined | null,
  options?: {
    replace?: boolean        // default false (uses pushState; true uses replaceState)
    redirectCode?: number    // default 302; on server-side this sets the HTTP status
    external?: boolean       // REQUIRED for external URLs (otherwise blocked for security)
    open?: { target: '_blank' | string;
             windowFeatures?: { width?, height?, top?, left?, noopener?, noreferrer?, popup? } }
  }
): Promise<void | NavigationFailure | false> | false | void | RouteLocationRaw
```

**Always `await` or `return`** `navigateTo`. Returning from middleware aborts the current nav and starts a new one.

```ts
// Inside a click handler
const onClick = async () => { await navigateTo('/dashboard') }

// Inside middleware
export default defineNuxtRouteMiddleware((to) => {
  if (!useAuth().isLoggedIn.value) {
    return navigateTo({ path: '/login', query: { redirect: to.fullPath } })
  }
})

// External URL
return navigateTo('https://github.com', { external: true, redirectCode: 301 })

// Open in new tab
navigateTo('/preview/42', { open: { target: '_blank' } })
```

In server routes (not middleware), use `sendRedirect(event, '/path', 302)` from h3 instead.

### `abortNavigation`

```ts
export default defineNuxtRouteMiddleware((to) => {
  if (!to.params.id) return abortNavigation()
  if (Number.isNaN(+to.params.id)) {
    return abortNavigation(createError({ status: 400, statusText: 'Invalid ID' }))
  }
})
```

---

## 9. Route middleware

Three flavors:

### Anonymous / inline

```vue
<script setup>
definePageMeta({
  middleware: [
    (to, from) => { if (!ok) return navigateTo('/login') },
  ],
})
</script>
```

### Named — `app/middleware/<name>.ts`

```ts
// app/middleware/auth.ts
export default defineNuxtRouteMiddleware((to, from) => {
  const auth = useAuth()
  if (!auth.isLoggedIn.value) {
    return navigateTo('/login')
  }
})
```

Reference by **filename, kebab-cased**:

```ts
definePageMeta({ middleware: 'auth' })             // app/middleware/auth.ts
definePageMeta({ middleware: ['auth', 'logged'] }) // multiple
```

(`myCustomMw` → `my-custom-mw`. Use kebab in `middleware: ['my-custom-mw']`.)

### Global — `app/middleware/<name>.global.ts`

```ts
// app/middleware/analytics.global.ts
export default defineNuxtRouteMiddleware((to, from) => {
  if (import.meta.server) return
  // Don't run on initial hydration (server already saw the navigation)
  const nuxtApp = useNuxtApp()
  if (nuxtApp.isHydrating && nuxtApp.payload.serverRendered) return
  track('pageview', to.path)
})
```

Runs on **every** navigation (and on initial SSR + hydration unless guarded).

### Return values

| Return | Effect |
|---|---|
| (nothing) / `undefined` | Continue navigation |
| `navigateTo('/x')` | Redirect (302 default; SSR sends HTTP redirect) |
| `navigateTo('/x', { redirectCode: 301 })` | Custom code |
| `abortNavigation()` | Cancel navigation silently |
| `abortNavigation(createError({...}))` | Cancel + show error page |

⚠️ **Always `return`** these — calling them without returning still triggers them, but the original navigation also continues, causing race conditions.

### Pitfalls

- **Don't call `useRoute()` in middleware** — use the `to` argument. `useRoute()` returns the *current* route, which might not be the navigation target.
- **Cookies need `useRequestHeaders` in server-rendered nav**, but `useCookie` auto-handles this.
- To skip middleware on hydration, check `useNuxtApp().isHydrating` and `payload.serverRendered`.

### Register middleware at runtime (in a plugin)

```ts
// app/plugins/middleware.ts
export default defineNuxtPlugin(() => {
  addRouteMiddleware('global-test', () => {
    console.log('I am a globally-added middleware')
  }, { global: true })

  addRouteMiddleware('named-test', () => {
    console.log('I am a named middleware')
  })
})
```

---

## 10. Route validation

```vue
<script setup>
definePageMeta({
  validate: async (route) => {
    return typeof route.params.id === 'string' && /^\d+$/.test(route.params.id)
  },
})
</script>
```

Return values:
- `true` — pass
- `false` — 404
- `{ status, statusText, message? }` — custom error

`validate` runs **before middleware**, so it's a good place for shape checks (numeric IDs, allowed slugs) before doing expensive auth checks in middleware.

---

## 11. Layouts

```
app/layouts/
├─ default.vue
├─ admin.vue
└─ blank.vue
```

```vue
<!-- app/layouts/default.vue -->
<template>
  <div>
    <AppHeader />
    <slot />                                  <!-- page content goes here -->
    <AppFooter />
  </div>
</template>
```

Rules:
- Layouts **must have a single root element**, and the root **cannot be `<slot/>` itself**.
- Wrapping in a `<div>` (or any single element) is required.

### Selecting a layout per-page

```vue
<script setup>
definePageMeta({ layout: 'admin' })           // app/layouts/admin.vue
definePageMeta({ layout: false })             // no layout at all
</script>
```

Layout names are kebab-cased filenames.

### Typed layout props

```vue
<!-- app/pages/dashboard.vue -->
<script setup>
definePageMeta({
  layout: { name: 'admin', props: { sidebar: true, title: 'Dashboard' } },
})
</script>
```

```vue
<!-- app/layouts/admin.vue -->
<script setup lang="ts">
const props = defineProps<{ sidebar?: boolean; title?: string }>()
</script>
<template>
  <div>
    <aside v-if="props.sidebar">…</aside>
    <header>{{ props.title }}</header>
    <slot />
  </div>
</template>
```

---

## 12. Switching layout dynamically

```ts
import { setPageLayout } from '#app'

const setLayoutMode = (mode: 'sidebar' | 'fullscreen') => {
  setPageLayout('admin', { sidebar: mode === 'sidebar' })
}
```

Use cases:
- Switch layout based on user role at runtime
- Force "blank" layout for a print view
- Apply different layouts conditionally inside middleware

---

## 13. Typed pages (experimental)

```ts
// nuxt.config.ts
experimental: { typedPages: true }
```

```ts
const router = useRouter()
router.push({ name: 'product', params: { slug: 'foo' } })   // ← typed
                                                              // wrong param name = TS error
                                                              // wrong route name = TS error
```

This requires the page to have a name (either auto-derived from the filename or set via `definePageMeta({ name: 'product' })`).

---

## 14. Hash + scroll behavior + transitions

### Scroll behavior — `app/router.options.ts`

```ts
import type { RouterConfig } from '@nuxt/schema'

export default <RouterConfig>{
  scrollBehavior(to, from, savedPosition) {
    if (savedPosition) return savedPosition          // browser back/forward
    if (to.hash) return { el: to.hash, top: 80 }     // anchor scroll with offset
    return { top: 0 }
  },
}
```

### Page transitions

```ts
// nuxt.config.ts — global default
app: {
  pageTransition: { name: 'fade', mode: 'out-in' },
  layoutTransition: { name: 'fade', mode: 'out-in' },
}
```

```vue
<!-- Page-specific override -->
<script setup>
definePageMeta({ pageTransition: { name: 'slide', mode: 'out-in' } })
</script>
```

```css
/* app/assets/css/main.css */
.fade-enter-active, .fade-leave-active { transition: opacity 200ms ease; }
.fade-enter-from, .fade-leave-to { opacity: 0; }
```

### View Transitions (experimental)

```ts
// nuxt.config.ts
experimental: { viewTransition: true }
```

```vue
<script setup>
definePageMeta({ viewTransition: 'always' })    // 'always' | true | false | object
</script>
```

Uses the browser's native `document.startViewTransition` API.

---

## Common navigation pitfalls

| Symptom | Cause / Fix |
|---|---|
| Middleware fires twice on first load | Hydration — check `useNuxtApp().isHydrating && payload.serverRendered` and bail |
| Page transitions glitchy | Layout / page has more than one root element |
| `navigateTo` doesn't redirect | Not awaited / returned — return it from middleware, await in handlers |
| External URL silently fails | Missing `external: true` |
| Param is string when expected number | Always coerce: `+route.params.id` or `Number(route.params.id)` |
| `definePageMeta({ middleware: myFn })` breaks | Can't reference local refs from setup — macro is hoisted |
| Page name doesn't match expectations in typedPages | Set explicit name: `definePageMeta({ name: 'product' })` |
| `useRoute()` returns stale data in middleware | Use the `to` argument |
| Route group folder leaks into URL | Use parentheses: `(marketing)`, not plain folder name |
