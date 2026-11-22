# Rendering Modes, Components & Deployment

Deep reference for SSR / SPA / hybrid rendering, `routeRules`, prerendering, components (built-in + lazy hydration + server-only), SEO, and Nitro deployment presets.

## Table of contents

1. Rendering modes overview
2. `routeRules` — full reference
3. Hybrid rendering recipes
4. Edge SSR
5. Prerendering (`nuxt generate`)
6. Built-in components
7. Component variants (`.client.vue`, `.server.vue`, `Lazy*`)
8. Delayed (lazy) hydration props
9. Dynamic components
10. SEO with Unhead 2 (`useHead`, `useSeoMeta`)
11. Error handling
12. Plugins
13. Deployment — Nitro presets and per-platform notes

---

## 1. Rendering modes

| Mode | When to use | How to enable |
|---|---|---|
| **Universal SSR** (default) | Content-driven sites, SEO-critical, e-commerce | Default — `ssr: true` |
| **Client-side SPA** | Dashboards behind auth, no SEO needs | `ssr: false` (site-wide) + use `app/spa-loading-template.html` |
| **Hybrid** (per-route) | Mix above per route | `routeRules` per pattern |
| **Edge SSR** | Low latency at scale | `nitro.preset: 'cloudflare-pages'` / `vercel-edge` / `netlify-edge` |
| **Prerender / SSG** | Static content | `nuxt generate` or `routeRules: { '/path': { prerender: true } }` |

---

## 2. `routeRules` — full reference

```ts
// nuxt.config.ts
export default defineNuxtConfig({
  routeRules: {
    '/':           { prerender: true },
    '/about':      { prerender: true },
    '/products':   { swr: 3600 },                      // stale-while-revalidate
    '/products/**':{ swr: 3600 },
    '/blog/**':    { isr: true },                      // ISR — persist until next deploy
    '/blog/*':     { isr: 60 },                        // ISR with 60s TTL
    '/admin/**':   { ssr: false },                     // client-only section
    '/api/**':     { cors: true },
    '/old':        { redirect: { to: '/new', statusCode: 301 } },
    '/docs/**':    { headers: { 'Cache-Control': 's-maxage=3600' } },
    '/widget':     { noScripts: true },                // ship HTML only, no JS
    '/legacy':     { appMiddleware: false },           // disable global middleware
    '/special':    { appMiddleware: 'auth' },          // force specific middleware
  },
})
```

| Property | Effect |
|---|---|
| `prerender: true / false` | Pre-render at build (use `false` to skip from crawled-link prerender) |
| `ssr: false` | Render client-side only |
| `isr: number \| true` | ISR (persisted on CDN; `true` = until next deploy) |
| `swr: number \| true` | Stale-while-revalidate on the server/proxy |
| `cache: { maxAge, name, group, swr, base, varies, … }` | Full cache config (same as `defineCachedEventHandler`) |
| `redirect: string \| { to, statusCode }` | Server-side redirect |
| `headers: Record<string, string>` | Add response headers |
| `cors: true` | Add CORS headers |
| `noScripts: true` | Don't render Nuxt scripts (HTML-only response) |
| `appMiddleware: string \| string[] \| Record<string, boolean>` | Force / disable specific middleware |

### Per-page route rules (inline)

```ts
// nuxt.config.ts
experimental: { inlineRouteRules: true }
```

```vue
<!-- app/pages/marketing.vue -->
<script setup>
defineRouteRules({ prerender: true })
</script>
```

---

## 3. Hybrid rendering recipes

```ts
routeRules: {
  // Static marketing pages
  '/': { prerender: true },
  '/about': { prerender: true },
  '/pricing': { prerender: true },

  // Blog with ISR — rebuilt on demand
  '/blog/**': { isr: true },

  // Product listings — fresh-ish, but cached behind CDN
  '/products': { swr: 60 },
  '/products/[slug]': { swr: 600 },

  // Internal dashboards — SPA, no SEO
  '/app/**': { ssr: false },

  // Always SSR for personalized content (default — explicit for clarity)
  '/account/**': { ssr: true },

  // Public API — CORS for external consumers
  '/api/public/**': { cors: true, headers: { 'Cache-Control': 'public, max-age=60' } },
}
```

---

## 4. Edge SSR

Set the Nitro preset to an edge target:

```ts
// nuxt.config.ts
nitro: { preset: 'cloudflare-pages' }   // or 'vercel-edge', 'netlify-edge'
```

Edge-specific constraints:
- No `fs` or Node built-ins (use `unstorage` drivers for KV/blob storage)
- No long-running tasks (use queues / scheduled tasks)
- Cold-start time matters — keep dependencies lean

---

## 5. Prerendering (`nuxt generate`)

```bash
nuxt generate                       # builds + crawls from / → .output/public/
```

Behavior:
- Renders `/` first, then follows every internal `<a>` to discover more pages
- Generates `_payload.json` next to each page so client-side nav doesn't refetch
- Output is fully static — deploy to any CDN

### Selective prerender (without crawling)

```ts
// nuxt.config.ts
nitro: {
  prerender: {
    routes: ['/sitemap.xml', '/rss.xml', '/blog/featured'],
    crawlLinks: true,                                  // follow <a> tags (default true with nuxt generate)
    ignore: ['/admin', /^\/private/, '/api/**'],
    failOnError: true,                                 // fail build if any route errors
    autoSubfolderIndex: true,                          // /about → /about/index.html (for static hosts)
  },
}
```

### Runtime control

```ts
// In any setup
prerenderRoutes(['/blog/extra'])

// Hook in nuxt.config
hooks: {
  'prerender:routes'(ctx) {
    ctx.routes.add('/extra-route')
  },
}

// Per-route skip
nitro: {
  hooks: {
    'prerender:generate'(route) {
      if (route.route.includes('/private')) route.skip = true
    },
  },
}
```

### Shared prerender data (enabled by default in Nuxt 4)

Multiple pages calling `useAsyncData('shared-key', fetcher)` share the result during prerender — Nuxt only calls the fetcher once. Required: use **stable, unique** keys so the deduplication works.

---

## 6. Built-in components

| Component | Purpose |
|---|---|
| `<NuxtPage>` | Renders the matched page (used in `app.vue` + nested in parent pages) |
| `<NuxtLayout name="...">` | Wraps content in a layout (slot) |
| `<NuxtLink to="...">` | Smart `<a>` with prefetching |
| `<NuxtLoadingIndicator>` | Top-of-page progress bar during nav |
| `<NuxtErrorBoundary @error="...">` | Catch errors in default slot; show `#error` slot |
| `<NuxtClientFallback>` | If SSR throws, show fallback HTML server-side; re-render fresh on client |
| `<NuxtIsland>` | Render a `*.server.vue` component as a server island |
| `<NuxtImg>` / `<NuxtPicture>` | From `@nuxt/image` — optimized images |
| `<NuxtRouteAnnouncer>` / `<NuxtAnnouncer>` | a11y route announcements |
| `<NuxtTime>` | SSR-safe time formatting (no hydration mismatches) |
| `<NuxtWelcome>` | Built-in welcome screen (for scaffolding) |
| `<ClientOnly>` | Renders children client-side only; `#fallback` for SSR placeholder |
| `<DevOnly>` | Renders only in dev |
| `<Teleport to="body">` | Vue's `<Teleport>` — works in Nuxt |

```vue
<ClientOnly>
  <Chart :data="data" />
  <template #fallback><div class="skeleton" /></template>
</ClientOnly>

<NuxtErrorBoundary @error="report">
  <RiskyChild />
  <template #error="{ error, clearError }">
    <p>{{ error }}</p>
    <button @click="clearError">Retry</button>
  </template>
</NuxtErrorBoundary>

<NuxtClientFallback>
  <!-- If SSR fails for this subtree, fall back to client render -->
  <ServerOnlyDependent />
  <template #fallback>Couldn't render server-side</template>
</NuxtClientFallback>
```

---

## 7. Component variants

| Filename suffix | Effect |
|---|---|
| `Foo.vue` | Standard component, hydrated on the client |
| `Foo.client.vue` | Client-only — skipped during SSR (HTML is replaced on hydration) |
| `Foo.server.vue` | Server-only island — rendered via `<NuxtIsland>`, zero client JS |
| `Foo.global.vue` or under `components/global/` | Auto-imported globally as separate chunks |
| `<LazyFoo />` prefix | Dynamic import — chunk loaded on first render |

### Server components (islands)

Requires `experimental: { componentIslands: true }`.

```vue
<!-- app/components/PriceWidget.server.vue -->
<script setup lang="ts">
const { data } = await useFetch('/api/price')
</script>
<template>
  <span>${{ data.value }}</span>
</template>
```

```vue
<!-- Use it -->
<template>
  <NuxtIsland name="PriceWidget" :props="{ currency: 'USD' }" />
</template>
```

The widget HTML is generated server-side and streamed in — zero JS for that subtree on the client.

---

## 8. Delayed (lazy) hydration

Only works on `Lazy*` components (auto-generated from regular components, prefixed with `Lazy`). Props must be defined directly in the template — not via `v-bind` spread.

| Prop | Hydrate when… |
|---|---|
| `hydrate-on-visible` | Element scrolls into the viewport (IntersectionObserver) |
| `hydrate-on-visible="{ rootMargin: '200px' }"` | + custom IntersectionObserver options |
| `hydrate-on-idle` | Browser is idle |
| `:hydrate-on-idle="2000"` | Idle + max wait of 2000ms |
| `hydrate-on-interaction` | On user interaction (default: `pointerenter, click, focus`) |
| `hydrate-on-interaction="click"` | Specific event |
| `hydrate-on-media-query="(max-width: 768px)"` | Media query matches |
| `:hydrate-after="2000"` | After 2000ms |
| `:hydrate-when="condition"` | Boolean reactive |
| `hydrate-never` | Never hydrates (static HTML only) |

All emit `@hydrated`:

```vue
<LazyHeavyChart hydrate-on-visible @hydrated="trackHydration" />
<LazyComments hydrate-on-interaction />
<LazyCart hydrate-when="hasItems" />
<LazyMap :hydrate-after="3000" />
<LazyHero hydrate-never />
```

---

## 9. Dynamic components

```vue
<script setup>
import { SomeComponent } from '#components'
const MyButton = resolveComponent('MyButton')     // ⚠️ literal string only — statically analyzed
</script>

<template>
  <component :is="clickable ? MyButton : 'div'" />
  <component :is="SomeComponent" />
</template>
```

`resolveComponent` only works with a **literal string** — Nuxt parses the source statically to know what to bundle. Variables won't work:

```ts
// ❌ Won't work
const name = props.componentName
const C = resolveComponent(name)
```

Use `defineAsyncComponent` for truly dynamic imports.

---

## 10. SEO with Unhead 2

Nuxt 4 ships **Unhead 2** — faster, smaller, with breaking changes. The official Unhead v2 announcement notes 51% faster SSR, 64% faster page switching, and 21% smaller client bundle vs v1.

```ts
// nuxt.config.ts — static defaults
app: {
  head: {
    title: 'Site',
    titleTemplate: '%s · Site',
    htmlAttrs: { lang: 'en' },
    meta: [{ name: 'viewport', content: 'width=device-width, initial-scale=1' }],
    link: [{ rel: 'icon', href: '/favicon.ico' }],
  },
}
```

```vue
<script setup>
// Reactive head
useHead({
  title: 'My Page',
  titleTemplate: chunk => chunk ? `${chunk} · Site` : 'Site',
  templateParams: { siteName: 'Site', separator: '·' },
  meta: [{ name: 'description', content: 'My description' }],
  link: [{ rel: 'stylesheet', href: 'https://fonts.googleapis.com/...' }],
  script: [{ innerHTML: 'console.log(1)', tagPosition: 'bodyClose' }],
  bodyAttrs: { class: 'dark' },
})

// Type-safe SEO helper
useSeoMeta({
  title: 'Page',
  description: 'Description',
  ogTitle: 'Page',
  ogImage: 'https://example.com/og.png',
  ogType: 'website',
  twitterCard: 'summary_large_image',
})

// Sanitize untrusted input
useHeadSafe({ link: [{ rel: 'icon', href: untrustedUserInput }] })

// Server-only (no client cost — won't be reactive client-side)
useServerSeoMeta({ description: 'Static description' })
</script>
```

Component syntax (capitalized names; tags deduped intelligently):

```vue
<template>
  <Head>
    <Title>{{ title }}</Title>
    <Meta name="description" :content="title" />
    <Link rel="canonical" :href="url" />
  </Head>
</template>
```

### Unhead 2 breaking changes

- ❌ `vmid`, `hid`, `children`, `body` props removed → use `key` to dedupe
- ❌ Promise input no longer supported
- ✅ Tags auto-sorted by Capo.js (better browser hint ordering)
- ✅ Template Params plugin is opt-in (was always on in v1)
- ✅ Alias Tag Sorting plugin is opt-in

To temporarily keep v1 behavior:

```ts
// nuxt.config.ts
unhead: { legacy: true }
```

---

## 11. Error handling

### Customize the error page — `app/error.vue`

```vue
<script setup lang="ts">
import type { NuxtError } from '#app'

const props = defineProps({ error: Object as () => NuxtError })

const handleError = () => clearError({ redirect: '/' })
</script>

<template>
  <div>
    <h2>{{ error?.statusCode }} — {{ error?.statusMessage }}</h2>
    <p>{{ error?.message }}</p>
    <pre v-if="error?.data">{{ error.data }}</pre>   <!-- already parsed in v4 -->
    <button @click="handleError">Go home</button>
  </div>
</template>
```

⚠️ In Nuxt 4 **`error.data` is already parsed** — don't `JSON.parse` it.

### Triggering errors

```ts
throw createError({
  status: 404,
  statusText: 'Not Found',
  message: 'Article not found',
  data: { id, hint: 'Check the URL' },
  fatal: true,                           // ← shows full-screen error.vue
})
```

| Where thrown | `fatal` matters? | Result |
|---|---|---|
| Server side (SSR / API) | always shows | full-screen error page |
| Client side | `fatal: true` only | full-screen page; otherwise catchable by `<NuxtErrorBoundary>` |

### Utils

| Util | Purpose |
|---|---|
| `useError()` | Reactive global Nuxt error |
| `createError(input)` | Build error object |
| `showError(err)` | Trigger error page programmatically |
| `clearError(opts?)` | Clear error; optional `{ redirect: '/path' }` |

### Chunk-load errors

By default, Nuxt does a hard reload on chunk-load failure. Customize:

```ts
// nuxt.config.ts
experimental: { emitRouteChunkError: 'manual' }      // emit nuxt:link-prefetch-error and chunk-error hooks
// or: 'automatic' (default) | false (do nothing)
```

```ts
// app/plugins/chunk-error.ts
export default defineNuxtPlugin((nuxtApp) => {
  nuxtApp.hook('app:chunkError', ({ error }) => {
    console.error('Chunk failed:', error)
    reloadNuxtApp({ persistState: true })
  })
})
```

### Global error hooks (in a plugin)

```ts
// app/plugins/error-reporter.ts
export default defineNuxtPlugin((nuxtApp) => {
  nuxtApp.vueApp.config.errorHandler = (err, instance, info) => {
    sentry.captureException(err)
  }
  nuxtApp.hook('vue:error', (err, instance, info) => { /* SSR + CSR */ })
  nuxtApp.hook('app:error', (err) => { /* startup errors */ })
})
```

---

## 12. Plugins — `app/plugins/`

Auto-registered (top-level files + `subdir/index.ts`). Use `.client.ts` / `.server.ts` to scope.

### Function syntax

```ts
// app/plugins/hello.ts
export default defineNuxtPlugin((nuxtApp) => {
  return {
    provide: {
      hello: (msg: string) => `Hello ${msg}!`,
    },
  }
})
```

```vue
<script setup>
const { $hello } = useNuxtApp()
</script>
<template>{{ $hello('world') }}</template>
```

### Object syntax (preferred — ordering, parallelism, static analysis)

```ts
export default defineNuxtPlugin({
  name: 'analytics',
  enforce: 'pre',                                  // 'pre' | 'default' | 'post'
  parallel: false,                                  // run async setup in parallel with others?
  dependsOn: ['auth'],                              // wait for these plugins first
  env: { islands: false },                          // skip in island components
  async setup(nuxtApp) { /* ... */ },
  hooks: {
    'app:created'() { /* ... */ },
  },
})
```

⚠️ With object syntax, properties are **statically analyzed at build time** — don't compute them at runtime:

```ts
// ❌ Won't work
export default defineNuxtPlugin({
  enforce: import.meta.server ? 'pre' : 'post',
  setup() {},
})
```

### Register a Vue plugin

```ts
import VueGtag, { trackRouter } from 'vue-gtag-next'

export default defineNuxtPlugin((nuxtApp) => {
  nuxtApp.vueApp.use(VueGtag, { property: { id: 'GA_ID' } })
  trackRouter(useRouter())
})
```

### Typing `$hello`

```ts
// shared/types/plugin-injections.d.ts
declare module '#app' {
  interface NuxtApp { $hello(msg: string): string }
}
declare module 'vue' {
  interface ComponentCustomProperties { $hello(msg: string): string }
}
export {}
```

---

## 13. Deployment

Nitro supports many deployment targets. Per the Nitro docs as of 2025-2026, it ships with 28 deployment presets covering 3 runtimes (Node.js, Bun, Deno) plus 25 hosting providers.

| Preset | Where |
|---|---|
| `node-server` | Generic Node.js server |
| `node-cluster` | Node.js with cluster module |
| `static` | Static HTML output |
| `cloudflare-pages`, `cloudflare-pages-modules`, `cloudflare-workers`, `cloudflare-module` | Cloudflare |
| `vercel`, `vercel-edge`, `vercel-static` | Vercel |
| `netlify`, `netlify-edge`, `netlify-static` | Netlify |
| `aws-lambda`, `aws-amplify` | AWS |
| `azure`, `azure-functions`, `azure-swa` | Azure |
| `deno-deploy`, `deno-server` | Deno |
| `bun` | Bun |
| `firebase` | Firebase |
| `github-pages`, `gitlab-pages` | Git hosts |
| `digitalocean`, `heroku`, `render-com`, `iis` | Various |
| `koyeb`, `stormkit`, `zeabur`, `zerops`, `genezio`, `edgeone-pages`, `flightcontrol`, `platform-sh`, `cleavr`, `alwaysdata`, `zephyr-cloud` | Other hosts |

Set via `nitro.preset` in `nuxt.config.ts` or via the `NITRO_PRESET` environment variable.

### Run the Node server

```bash
nuxt build                                          # outputs .output/server/index.mjs
NODE_ENV=production node .output/server/index.mjs
# Env vars:
#   NITRO_PORT / PORT     = 3000  (default)
#   NITRO_HOST / HOST     = 0.0.0.0
#   NITRO_SSL_CERT / NITRO_SSL_KEY (PEM contents, not paths)
```

⚠️ Always set `NODE_ENV=production` — strips Vue Router dev warnings that flood prod logs otherwise.

### PM2 cluster

```js
// ecosystem.config.cjs
module.exports = {
  apps: [{
    name: 'app',
    script: '.output/server/index.mjs',
    exec_mode: 'cluster',
    instances: 'max',
    env: { NODE_ENV: 'production' },
  }],
}
```

### Cloudflare gotchas

In the Cloudflare dashboard, **disable**:
1. Speed → Settings → Content Optimization → Rocket Loader
2. Security → Settings → Email Address Obfuscation

Both inject JS that breaks Vue hydration.

### Vercel (default for Nuxt)

`nitro.preset` is auto-detected as `vercel` when deployed to Vercel — no config needed. To force edge:

```ts
nitro: { preset: 'vercel-edge' }
```

### Per-environment Nitro config

```ts
// nuxt.config.ts
$production: {
  nitro: {
    minify: true,
    sourceMap: false,
    storage: { kv: { driver: 'vercel-kv' } },
  },
}
$development: {
  nitro: { devStorage: { kv: { driver: 'fs', base: '.cache/kv' } } },
}
```

---

## Performance summary

- Prerender static-ish pages: `routeRules: { '/marketing/**': { prerender: true } }`
- CDN-cache personalized pages: `{ swr: 3600 }` or `{ isr: true }`
- Ship zero JS for static blocks: use server components (`*.server.vue`)
- Delay hydration of heavy components: `hydrate-on-visible`, `hydrate-on-idle`
- Use `@nuxt/image` for images, `@nuxt/fonts` for fonts, `@nuxt/scripts` for third-party JS
- Set `NODE_ENV=production` on the server
- Disable Rocket Loader / Email Obfuscation on Cloudflare
