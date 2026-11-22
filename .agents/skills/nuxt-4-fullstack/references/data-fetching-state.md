# Data Fetching & State Management

Deep reference for `useFetch`, `useAsyncData`, `$fetch`, `useState`, `useCookie`, and related utilities. Read this when picking a data-fetching primitive, hitting edge cases, or debugging stale/shared/duplicated data.

## Table of contents

1. The three primitives and when to use each
2. `$fetch` — direct HTTP (ofetch)
3. `useFetch` — full signature and options
4. `useAsyncData` — full signature and options
5. Reactive keys, watch, refresh, clear
6. Shared state across components (same-key behavior)
7. `transform`, `pick`, `default`, `getCachedData`
8. Lazy variants and `useNuxtData`
9. Serialization (devalue vs JSON)
10. Server-side cookie/header forwarding
11. SSE / streaming responses
12. `useState` — SSR-shared reactive state
13. `useCookie` — cookies with reactivity
14. `callOnce` — replacing `nuxtServerInit`
15. Pinia integration
16. `refreshNuxtData` / `clearNuxtData` / `clearNuxtState` / `refreshCookie`

---

## 1. The three primitives

| Primitive | Where to use | Why |
|---|---|---|
| `useFetch(url, opts)` | `<script setup>`, top-level setup function | SSR-safe, auto-keyed, blocks Suspense by default |
| `useAsyncData(key, handler, opts)` | `<script setup>` when handler isn't a single `$fetch` (SDK calls, parallel fetches, custom logic) | Same as `useFetch` but you write the handler |
| `$fetch(url, opts)` | Event handlers (clicks, submits), Nitro server routes, `useFetch`'s underlying call | Direct HTTP — runs once where called |

`useFetch(url, opts)` ≈ `useAsyncData(autoKey, () => $fetch(url, opts), opts)`.

**Hard rule:** never call bare `$fetch` directly in `<script setup>` for initial data. It will execute on the server during SSR **and again** during client hydration (double request, double DB hit, possible UI flicker). Always wrap with `useFetch` or `useAsyncData` for setup-time data.

---

## 2. `$fetch` (ofetch, auto-imported)

```ts
const res = await $fetch<User>('/api/login', {
  method: 'POST',
  body: { email, password },
  query: { ref: 'home' },             // also: params (alias)
  headers: { 'X-Custom': '1' },
  baseURL: 'https://api.example.com',
  timeout: 5000,                       // ms
  retry: 3,
  retryDelay: 500,
  responseType: 'json',                // 'stream' | 'json' | 'text' | 'blob' | 'arrayBuffer'
  onRequest({ options }) { options.headers.set('Authorization', `Bearer ${token}`) },
  onResponse({ response }) { /* ... */ },
  onResponseError({ response }) { /* ... */ },
  onRequestError({ error }) { /* ... */ },
  signal,                              // AbortSignal
  cache: 'no-cache',                   // Request cache option
})

// Raw response (access headers, status)
const raw = await $fetch.raw('/api/x')
console.log(raw.status, raw.headers, raw._data)
```

---

## 3. `useFetch` — signature

```ts
useFetch<DataT, ErrorT = NuxtError>(
  url: string | Request | Ref<string | Request> | (() => string | Request),
  options?: {
    // Key & request
    key?: MaybeRefOrGetter<string>     // auto-generated if omitted
    method?: MaybeRefOrGetter<string>  // default 'GET'
    query?: MaybeRefOrGetter<SearchParams>   // alias: params
    body?: MaybeRefOrGetter<...>
    headers?: MaybeRefOrGetter<...>
    baseURL?: MaybeRefOrGetter<string>
    cache?: false | 'default' | 'no-store' | 'no-cache' | 'force-cache' | 'only-if-cached' | 'reload'

    // Behavior
    server?: boolean                    // default true — fetch on server side?
    lazy?: boolean                      // default false — if true, doesn't block Suspense
    immediate?: boolean                 // default true — false = manual via execute()
    default?: () => DataT               // initial data value
    transform?: (input: DataT) => DataT | Promise<DataT>
    pick?: string[]                     // only keep these top-level keys
    watch?: MultiWatchSources | false   // false disables auto-watch of reactive opts
    deep?: boolean                      // default FALSE in Nuxt 4 (shallowRef)
    dedupe?: 'cancel' | 'defer'         // default 'cancel'
    timeout?: number                    // ms, default no timeout
    getCachedData?: (key, nuxtApp, ctx: { cause: 'initial' | 'refresh:manual' | 'refresh:hook' | 'watch' }) => DataT | undefined
    $fetch?: typeof globalThis.$fetch   // override the $fetch instance
  }
): Promise<{
  data:    Ref<DataT | undefined>      // shallowRef by default — wrap nested mutations
  pending: Ref<boolean>                 // computed: true ONLY when status === 'pending'
  error:   Ref<ErrorT | undefined>
  status:  Ref<'idle' | 'pending' | 'success' | 'error'>
  refresh: (opts?: { dedupe?: 'cancel' | 'defer'; timeout?: number; signal?: AbortSignal }) => Promise<void>
  execute: typeof refresh               // alias of refresh
  clear:   () => void                   // resets to default() or undefined, cancels in-flight
}>
```

```ts
// Typical
const { data, status, error } = await useFetch<Post[]>('/api/posts', { default: () => [] })

// Computed URL (reactive — auto-refetches)
const q = ref('')
const { data } = useLazyFetch(() => `/api/search?q=${q.value}`, { immediate: false })

// With watch (refetch when these refs change)
const page = ref(1); const sort = ref('asc')
const { data } = useFetch('/api/items', { watch: [page, sort] })

// Pass query / body (reactive)
const { data } = useFetch('/api/items', { query: { page, sort } })
```

---

## 4. `useAsyncData` — signature

```ts
useAsyncData<DataT, ErrorT>(
  key?: string | Ref<string> | (() => string),
  handler: (nuxtApp: NuxtApp, ctx: { signal: AbortSignal }) => Promise<DataT>,
  options?: /* same as useFetch except no url/method/query/body/headers/baseURL */
): Promise<AsyncData<DataT, ErrorT>>
```

```ts
const { data, error, status, refresh, clear } = await useAsyncData(
  'cart-summary',
  async (_, { signal }) => {
    const [items, coupons] = await Promise.all([
      $fetch('/api/cart',    { signal }),
      $fetch('/api/coupons', { signal }),
    ])
    return { items, coupons }
  },
  { default: () => ({ items: [], coupons: [] }), dedupe: 'cancel' },
)
```

`signal` is forwarded to your `$fetch` calls so they get aborted on dedupe/cancel/clear.

---

## 5. Reactive keys, watch, refresh, clear

### Reactive keys (Nuxt 4)

The key argument accepts a `Ref<string>`, computed, or getter — Nuxt re-runs the handler and caches separately when the key changes:

```ts
const id = ref('123')
const { data: user } = useAsyncData(
  computed(() => `user-${id.value}`),
  () => $fetch(`/api/users/${id.value}`),
)
id.value = '456'                       // → automatic refetch with new key
```

`useFetch` does this too via the URL getter:

```ts
const slug = ref('a')
const { data } = useFetch(() => `/api/posts/${slug.value}`)
slug.value = 'b'                       // automatic refetch
```

### `refresh()` / `execute()`

```ts
await refresh()                                          // refetch this handler
await refresh({ dedupe: 'cancel' })                      // cancel in-flight, refetch
await refresh({ dedupe: 'defer' })                       // skip if in-flight
await refresh({ signal: controller.signal })             // abortable
```

⚠️ **In v4 you cannot pass `dedupe: true` / `dedupe: false`.** Use the string values. The codemod `npx codemod@latest nuxt/4/deprecated-dedupe-value` rewrites this.

### `clear()`

Resets state for this composable: `data` → `default()` or `undefined`, `error` → `undefined`, `status` → `'idle'`, cancels pending. **In v4 it respects `options.default()`** (previously always reset to `undefined`).

```ts
const { clear } = useAsyncData('k', fetcher, { default: () => [] })
clear()                                                  // data.value === []
```

---

## 6. Same-key sharing (new in v4)

Multiple components calling `useFetch` / `useAsyncData` with the **same key** share the underlying `data` / `error` / `status` / `pending` refs.

These options **must match** across all calls or you'll get a dev warning:

- `handler`
- `deep`
- `transform`
- `pick`
- `getCachedData`
- `default`

These options **may differ** per call:

- `server`
- `lazy`
- `immediate`
- `dedupe`
- `watch`

To read data fetched elsewhere without triggering a new fetch:

```ts
const { data } = useNuxtData<User>('users:123')
```

---

## 7. `transform`, `pick`, `default`, `getCachedData`

```ts
const { data } = await useFetch('/api/mountains', {
  pick: ['title', 'description'],     // only keep these top-level keys (shrinks payload)
  transform: list => list.map(m => ({ ...m, slug: m.title.toLowerCase() })),
  default: () => [],
})
```

### `getCachedData` (Nuxt 4 changes)

In v4, `getCachedData` is called on **every** fetch (initial AND refresh AND key change), with a `ctx.cause` argument. Return `undefined` to fall through to the real fetch.

```ts
useAsyncData('user', () => $fetch('/api/user'), {
  getCachedData(key, nuxtApp, ctx) {
    if (ctx.cause === 'refresh:manual') return       // user clicked refresh → always refetch
    return nuxtApp.payload.data[key] ?? nuxtApp.static.data[key]
  },
})
```

The four possible `ctx.cause` values:
- `'initial'` — first call to this composable
- `'refresh:manual'` — `refresh()` / `execute()` was called
- `'refresh:hook'` — triggered by `refreshNuxtData(key)`
- `'watch'` — triggered by a watched reactive source changing

To revert to v3 behavior (`getCachedData` called only on initial fetch): `experimental.granularCachedData: false`.
To purge cache on key/url change: `experimental.purgeCachedData: true`.

---

## 8. Lazy variants and `useNuxtData`

```ts
const { data, status } = useLazyFetch('/api/posts')          // = useFetch(..., { lazy: true })
const { data }         = useLazyAsyncData('k', fetcher)      // = useAsyncData(..., { lazy: true })
```

`lazy: true` means **navigation doesn't wait** for this fetch — `<Suspense>` resolves immediately, and you'll see `status: 'pending'` until the data arrives. Best for non-critical below-the-fold content.

```ts
// Read keyed data fetched elsewhere
const { data } = useNuxtData<User[]>('users')
```

---

## 9. Serialization caveats

Two different serializers are used in different places:

| Context | Serializer | Supports |
|---|---|---|
| Server route response (`/api/*` JSON return) | `JSON.stringify` | Only JSON-safe values. `Date` → ISO string. `Map`/`Set` → `{}` / `[]`. **No ref/reactive.** |
| Payload between app composables (`useAsyncData`, `useState`) | [`devalue`](https://github.com/sveltejs/devalue) | `Date`, `Map`, `Set`, `RegExp`, `BigInt`, `URL`, `ref`, `reactive`, `shallowRef`, `NuxtError`, cyclic refs, plus custom reducers via `definePayloadPlugin` |

To control the client-visible shape of a server route's response, add a `toJSON()` method on the returned object — TS will use that method's return as the inferred type.

---

## 10. Server-side cookie/header forwarding

When `useFetch('/api/me')` runs **on the server during SSR**, Nuxt automatically calls the route through `useRequestFetch()`, which **forwards the client's cookies and most headers**. So your `/api/me` handler sees the user's `session` cookie just like a real client request.

If you call `$fetch` manually inside setup, you must forward manually:

```ts
const headers = useRequestHeaders(['cookie', 'authorization'])
const user = await $fetch('/api/me', { headers })
```

To propagate `Set-Cookie` from an internal `$fetch` back to the browser (e.g. token refresh inside SSR):

```ts
import { appendResponseHeader } from 'h3'
import type { H3Event } from 'h3'

export const fetchWithCookieForwarding = async (event: H3Event, url: string) => {
  const res = await $fetch.raw(url)
  for (const c of res.headers.getSetCookie()) {
    appendResponseHeader(event, 'set-cookie', c)
  }
  return res._data
}
```

Inside a server route, use `event.$fetch(url)` instead of bare `$fetch(url)` — it auto-forwards cookies + headers (except hop-by-hop).

---

## 11. SSE / streaming

```ts
const stream = await $fetch<ReadableStream>('/api/chat', {
  method: 'POST',
  body: { messages },
  responseType: 'stream',
})
const reader = stream.pipeThrough(new TextDecoderStream()).getReader()
while (true) {
  const { value, done } = await reader.read()
  if (done) break
  // append `value` to UI
}
```

For Server-Sent Events from a Nitro route:

```ts
// server/api/events.get.ts
export default defineEventHandler(async (event) => {
  const stream = createEventStream(event)
  setInterval(() => stream.push({ event: 'ping', data: String(Date.now()) }), 1000)
  return stream.send()
})
```

---

## 12. `useState<T>(key?, init?: () => T | Ref<T>): Ref<T>`

SSR-friendly shared reactive state — serialized into the SSR payload and re-hydrated on the client. **Never declare top-level `ref()` in a module** — it would be shared across SSR requests for all users.

```ts
// app/composables/useColor.ts
export const useColor = () => useState<string>('color', () => 'pink')
```

```vue
<script setup>
const color = useColor()           // shared, reactive, hydrated
</script>
```

### Patterns

```ts
// Stable key per route (don't blow away state on nav)
const auth = useState('auth', () => ({ user: null, ready: false }))

// Per-route state (intentional reset)
const route = useRoute()
const draft = useState(() => `draft:${route.params.id}`, () => '')

// Wrap an object in shallowRef for non-reactive deep updates
const big = useState('big', () => shallowRef({ deep: 'not reactive' }))
```

### Reset / clear

```ts
clearNuxtState('counter')                              // clear specific key
clearNuxtState(['k1', 'k2'])
clearNuxtState()                                        // clear all
clearNuxtState('counter', { reset: true })             // RE-RUN init function (in v5 this is the default)
```

To make `clearNuxtState` reset-by-default before v5: `experimental.defaults.useState.resetOnClear: true`.

---

## 13. `useCookie<T>(name, options?)`

```ts
const session = useCookie<string | null>('session', {
  default: () => null,
  maxAge: 60 * 60,                       // seconds
  expires: new Date('2026-12-31'),
  httpOnly: false,                       // ⚠️ only effective server-side
  secure: true,
  sameSite: 'lax',                       // 'strict' | 'lax' | 'none' | false
  domain: '.example.com',
  path: '/',
  watch: true,                           // true | 'shallow' | false
  readonly: false,
  refresh: true,                         // refresh expiration on each assignment
  encode: v => JSON.stringify(v),
  decode: s => JSON.parse(s),
})

session.value = 'logged-in'              // auto-writes to browser cookie + server Set-Cookie
session.value = null                      // delete the cookie
```

### Behavior notes

- `useCookie` returns a `Ref<T>`. Reading + writing is **automatic** — Nuxt watches and serializes.
- `httpOnly: true` is enforced on the server but the browser **cannot set HttpOnly cookies via JS** — set those from a Nitro handler instead.
- After a `$fetch` call sets cookies server-side (e.g. login), `useCookie` won't auto-update unless you call `refreshCookie('name')` or enable `experimental.cookieStore: true` (which uses the browser CookieStore API to listen for changes).
- On the server, use h3 helpers directly: `setCookie(event, name, value, opts)`, `getCookie(event, name)`, `parseCookies(event)`, `deleteCookie(event, name)`.

---

## 14. `callOnce(fn, options?)` — once-per-request initialization

Replacement for Nuxt 2's `nuxtServerInit`. Runs the callback **once per request** (during SSR) or **once per app load** (CSR), with payload deduplication so the client doesn't re-run what the server already did.

```ts
await callOnce(async () => {
  useWebsiteConfig().value = await $fetch('https://cms/api/site')
})

// Options
callOnce(() => log.info('init'), { mode: 'render' | 'navigation' })
```

- `mode: 'render'` (default) — once per server render OR client mount.
- `mode: 'navigation'` — once per route navigation.

⚠️ Use this instead of putting `await store.fetch()` inside `useAsyncData` — Pinia actions inside `useAsyncData` can re-run with nullish values during reactivity ticks.

---

## 15. Pinia integration

```bash
npx nuxt module add pinia
```

```ts
// app/stores/cart.ts
export const useCartStore = defineStore('cart', {
  state: () => ({ items: [] as CartItem[] }),
  actions: {
    async fetch() {
      this.items = await $fetch('/api/cart')
    },
  },
})
```

```vue
<script setup>
const cart = useCartStore()
await callOnce(() => cart.fetch())       // ← use callOnce, NOT useAsyncData
</script>
```

For shared store data that should be SSR-serialized, Pinia + `@pinia/nuxt` handles payload hydration automatically.

---

## 16. Global cache management

| Function | Effect |
|---|---|
| `refreshNuxtData()` | Refetch ALL `useFetch` / `useAsyncData` keys |
| `refreshNuxtData('users')` | Refetch one key |
| `refreshNuxtData(['users', 'cart'])` | Refetch multiple keys |
| `clearNuxtData()` | Clear ALL cached data |
| `clearNuxtData('users')` | Clear one key |
| `clearNuxtState()` | Clear all `useState` |
| `clearNuxtState('counter', { reset: true })` | Clear + re-run init |
| `refreshCookie('name')` | Re-read a cookie set out-of-band by a server route |

`refreshNuxtData` triggers `getCachedData(key, app, { cause: 'refresh:hook' })`.

---

## Common bugs by symptom

| Symptom | Cause / fix |
|---|---|
| `data.value === '/api/posts'` (the URL!) | `useFetch` was auto-imported from `@vueuse/core`. Force the Nuxt one: `import { useFetch } from '#imports'` |
| Request runs twice (SSR + CSR) | Using bare `$fetch(url)` in setup. Use `useFetch`. |
| Hydration mismatch warning | `Date.now()` / `Math.random()` / `window.*` in setup. Guard with `if (import.meta.client)` or wrap in `<ClientOnly>` |
| `useState` reset on nav | Different key per render. Use a stable string. |
| `Cannot read properties of undefined` after `clearNuxtData` | v4 default for `data` is now `undefined`, not `null`. Adjust your guards. |
| `useFetch` doesn't refetch when ref changes | Pass the URL as a getter `() => '/api/' + id.value`, not as a string |
| `refresh({ dedupe: true })` throws | Removed in v4 — use `'cancel'` or `'defer'` |
| Multiple components with same key warn about mismatched options | `handler`, `deep`, `transform`, `pick`, `getCachedData`, `default` must match across same-key calls |
| Cookie set via login `$fetch` not visible | Call `refreshCookie('token')` after, or enable `experimental.cookieStore: true` |
| `getCachedData` is now slow/spammy | v4 calls it on every fetch — short-circuit with `ctx.cause` |
