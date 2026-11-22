# Server / Nitro Reference

Deep reference for the `server/` directory: handlers, middleware, plugins, tasks, caching, storage, and runtime config in the Nitro context.

## Table of contents

1. The `server/` layout (Nuxt 4 — outside `app/`)
2. Defining handlers (`defineEventHandler`)
3. h3 helper utilities
4. Validation (Zod + `readValidatedBody`)
5. Server middleware
6. Server plugins (`defineNitroPlugin`)
7. Runtime config in server context
8. Caching: `defineCachedEventHandler` & `defineCachedFunction`
9. Storage layer (`useStorage`)
10. Server tasks (cron-like)
11. WebSockets
12. Background work after response (`event.waitUntil`)
13. Internal `$fetch` with cookie/header forwarding
14. The `#server` and `#shared` aliases
15. Errors from server routes
16. Full REST resource example

---

## 1. The `server/` directory (Nuxt 4)

⚠️ In Nuxt 4, `server/` is at **`<rootDir>/server`**, NOT under `app/`. It has its own TypeScript context (`tsconfig.server.json`) and its own auto-imports.

```
server/
├─ api/                          # all routes prefixed with /api
│  ├─ hello.ts                   →  /api/hello
│  ├─ users.get.ts               →  GET    /api/users
│  ├─ users.post.ts              →  POST   /api/users
│  ├─ users/[id].get.ts          →  GET    /api/users/:id
│  ├─ users/[id].patch.ts        →  PATCH  /api/users/:id
│  └─ files/[...path].ts         →  catch-all /api/files/*
├─ routes/                       # NON-prefixed routes
│  ├─ sitemap.xml.ts             →  /sitemap.xml
│  └─ robots.txt.ts              →  /robots.txt
├─ middleware/
│  └─ auth.ts                    # runs on EVERY request; must not respond
├─ plugins/
│  └─ db.ts                      # Nitro lifecycle plugin
├─ tasks/
│  └─ cleanup.ts                 # scheduled tasks
└─ utils/
   └─ db.ts                      # auto-imported in server context
```

Method suffixes: `.get`, `.post`, `.put`, `.delete`, `.patch`, `.head`, `.options`, `.connect`, `.trace`.

Dynamic params: `[id]` (single), `[...slug]` (catch-all).

---

## 2. Defining handlers

```ts
// server/api/users/[id].get.ts
export default defineEventHandler(async (event) => {
  const id = getRouterParam(event, 'id')              // string | undefined
  const query = getQuery(event)                       // { q?: string, ... }
  return db.users.findOne({ id })                     // anything JSON-serializable
})
```

```ts
// server/api/users.post.ts
export default defineEventHandler(async (event) => {
  const body = await readBody<{ name: string; email: string }>(event)
  setResponseStatus(event, 201)
  return db.users.create(body)
})
```

### Return types

Whatever you `return` is JSON-serialized into the response body. To control the shape (and TS inference) of what reaches the client, add a `toJSON()` method on the returned object. Returning a `Response`, `ReadableStream`, `Buffer`, `Blob`, `ArrayBuffer`, or `null` (→ 204) bypasses JSON serialization.

### Async / non-async

Either is fine. Both `eventHandler` and `defineEventHandler` are the same function — use either name.

---

## 3. h3 helper utilities (auto-imported in server context)

### Reading the request

| Helper | Returns |
|---|---|
| `getRouterParam(event, 'name')` | `string \| undefined` — single dynamic param |
| `getRouterParams(event)` | `Record<string, string>` — all dynamic params |
| `getQuery(event)` | `QueryObject` — `?q=foo&x=1` |
| `getValidatedQuery(event, schema.parse)` | Validated query (throws 400 on fail) |
| `readBody(event)` / `readBody<T>(event)` | Parsed body (JSON / form / text) |
| `readValidatedBody(event, schema.parse)` | Validated body (throws 400 on fail) |
| `readRawBody(event)` / `readMultipartFormData(event)` | Raw text / multipart parts |
| `getRequestURL(event)` | `URL` instance |
| `getRequestHeaders(event)` | `Headers` |
| `getRequestHeader(event, 'name')` | `string \| undefined` |
| `getRequestIP(event, { xForwardedFor: true })` | `string \| undefined` |
| `getCookie(event, 'name')` / `parseCookies(event)` | cookie reads |
| `isMethod(event, 'POST')` / `assertMethod(event, ['POST', 'PUT'])` | method check |

### Writing the response

| Helper | Effect |
|---|---|
| `setResponseStatus(event, 201, 'Created')` | Set status code + message |
| `setResponseHeader(event, 'X-Foo', 'bar')` | Set one header |
| `setResponseHeaders(event, { 'X-Foo': 'bar' })` | Set many |
| `appendResponseHeader(event, 'set-cookie', '…')` | Append (for multiple Set-Cookie) |
| `setCookie(event, 'name', 'value', opts)` | Cookie helper |
| `deleteCookie(event, 'name')` | Delete cookie |
| `sendRedirect(event, '/path', 302)` | Redirect (use 301/302/307/308 as appropriate) |
| `sendStream(event, readableStream)` | Stream response body |
| `sendNoContent(event, 204)` | Empty response |
| `proxyRequest(event, 'https://upstream/...')` | Proxy upstream |
| `createError({ status, statusText, data, fatal? })` | Build a structured error to throw |

### Router composition

```ts
// server/api/admin/index.ts
const router = createRouter()
router.get('/users', defineEventHandler(() => db.users.list()))
router.get('/users/:id', defineEventHandler((event) => db.users.find(event.context.params.id)))
export default useBase('/api/admin', router.handler)
```

---

## 4. Validation pattern (Zod)

```ts
// server/api/users.post.ts
import { z } from 'zod'

const CreateUser = z.object({
  name: z.string().min(1).max(80),
  email: z.string().email(),
  age: z.coerce.number().int().positive().optional(),
})

export default defineEventHandler(async (event) => {
  const body = await readValidatedBody(event, CreateUser.parse)
  // body is now fully typed
  setResponseStatus(event, 201)
  return db.users.create(body)
})
```

`.parse` throws on failure → Nitro turns it into a 400 response with the Zod issue details in `error.data`.

For query strings: `await getValidatedQuery(event, Schema.parse)`.

Put schemas in `shared/utils/schemas.ts` so the same Zod schema validates on server AND can be re-used client-side (e.g. with `@vee-validate/zod`).

---

## 5. Server middleware

```ts
// server/middleware/log.ts
export default defineEventHandler((event) => {
  console.log('[req]', event.method, getRequestURL(event).pathname)
})
```

```ts
// server/middleware/auth.ts
export default defineEventHandler(async (event) => {
  const token = getRequestHeader(event, 'authorization')?.slice(7)
  event.context.user = token ? await verifyJwt(token) : null
})
```

**Important:** Server middleware must **NOT return a response** — only attach things to `event.context`. To short-circuit with a response (e.g. reject unauthenticated request), `throw createError({ status: 401 })`.

Middleware runs in alphabetical order. All middleware files run on every request — no filename matching.

---

## 6. Server plugins (`defineNitroPlugin`)

Register Nitro lifecycle hooks. Different from app plugins (which run in the Vue context).

```ts
// server/plugins/db.ts
export default defineNitroPlugin((nitroApp) => {
  nitroApp.hooks.hook('request', async (event) => {
    event.context.requestStart = Date.now()
  })

  nitroApp.hooks.hook('beforeResponse', async (event, { body }) => {
    const dur = Date.now() - event.context.requestStart
    setResponseHeader(event, 'Server-Timing', `total;dur=${dur}`)
  })

  nitroApp.hooks.hook('error', async (error, { event }) => {
    logger.error('[req-error]', error, event?.path)
  })

  nitroApp.hooks.hook('close', async () => {
    await db.close()
  })

  nitroApp.hooks.hook('render:response', async (response, { event }) => {
    // Mutate the rendered HTML response (SSR responses only)
  })
})
```

Available hooks: `request`, `beforeResponse`, `afterResponse`, `error`, `close`, `render:html`, `render:response`.

---

## 7. Runtime config in server context

```ts
// server/api/secure.get.ts
export default defineEventHandler(async (event) => {
  const config = useRuntimeConfig(event)            // ← pass event for per-request env overrides
  return $fetch('https://api.example.com/data', {
    headers: { Authorization: `Bearer ${config.apiSecret}` },
  })
})
```

⚠️ **Always pass `event`** to `useRuntimeConfig` in server routes. Without it, the env-var overrides set on a per-request basis (e.g. `NUXT_API_SECRET` injected by a serverless runtime) won't apply.

Server-side config sees the **full** runtimeConfig (private keys included). The client only sees `public.*` and `app.*`.

---

## 8. Caching

### `defineCachedEventHandler` — cache a whole route

```ts
import { defineCachedEventHandler } from 'nitropack/runtime'

export default defineCachedEventHandler(async (event) => {
  const slug = getRouterParam(event, 'slug')
  return await fetchExpensiveStuff(slug)
}, {
  maxAge: 60 * 60,           // cache for 1 hour
  staleMaxAge: -1,           // -1 = serve stale forever while revalidating in background
  swr: true,                  // stale-while-revalidate (default true)
  base: 'cache',              // unstorage mountpoint name
  name: 'home',
  group: 'pages',
  varies: ['accept-language', 'host'],
  shouldBypassCache: (event) => getHeader(event, 'cache-control') === 'no-cache',
  shouldInvalidateCache: (event) => isMethod(event, 'POST'),
  getKey: (event) => getRouterParam(event, 'slug') ?? '_',
})
```

### `defineCachedFunction` — cache any async function

```ts
export const ghStars = defineCachedFunction(
  async (event: H3Event, repo: string) => {
    const data = await $fetch<{ stargazers_count: number }>(`https://api.github.com/repos/${repo}`)
    return data.stargazers_count
  },
  {
    maxAge: 60 * 60,
    name: 'ghStars',
    getKey: (_event, repo: string) => repo,
  },
)
```

The first argument is **always** an `H3Event`, even if your function doesn't use it. The remaining arguments are yours.

### Invalidating cache manually

```ts
const storage = useStorage('cache')                    // depends on base/name/group
await storage.removeItem('nitro:functions:ghStars:nuxt/nuxt.json')
await storage.clear('nitro:functions:ghStars')         // by prefix
```

### Via `routeRules` (declarative)

```ts
// nuxt.config.ts
nitro: {
  routeRules: {
    '/api/products/**': { cache: { maxAge: 60, swr: true, group: 'products' } },
  },
}
```

---

## 9. Storage layer (`unstorage`)

```ts
// nuxt.config.ts — configure drivers
export default defineNuxtConfig({
  nitro: {
    storage: {
      redis: { driver: 'redis', host: '127.0.0.1', port: 6379, password: '' },
      uploads: { driver: 'fs', base: './uploads' },
    },
    devStorage: {                                      // only used in dev
      cache: { driver: 'fs', base: '.cache' },
    },
  },
})
```

```ts
// server/api/cache-test.ts
export default defineEventHandler(async () => {
  const store = useStorage('redis')
  await store.setItem('greeting', { hello: 'world' })
  const v = await store.getItem<{ hello: string }>('greeting')
  await store.removeItem('greeting')
  return v
})
```

### Built-in mountpoints

- `cache` — used by `defineCachedFunction` / `defineCachedEventHandler`
- `data` — persistent app data
- `assets` — built-in static assets

### Available drivers (via `unstorage`)

`fs`, `fs-lite`, `memory`, `redis`, `mongodb`, `azure-storage-blob`, `cloudflare-kv-binding`, `cloudflare-kv-http`, `cloudflare-r2-binding`, `vercel-blob`, `vercel-kv`, `netlify-blobs`, `aws-s3`, `db0`, `github`, `gcs`, `lru-cache`, `null`, `overlay`, `planetscale`, `http`, `denokv`, etc. Browse the `unstorage` docs for the full driver list.

---

## 10. Server tasks (cron / on-demand)

```ts
// server/tasks/db-cleanup.ts
export default defineTask({
  meta: {
    name: 'db:cleanup',
    description: 'Delete expired sessions',
  },
  async run({ payload, context }) {
    const deleted = await db.sessions.deleteExpired()
    return { result: { deleted } }
  },
})
```

```ts
// nuxt.config.ts — schedule
nitro: {
  experimental: { tasks: true },
  scheduledTasks: {
    '0 0 * * *': ['db:cleanup'],                        // daily at midnight
    '*/15 * * * *': ['cache:warm', 'sitemap:rebuild'],  // every 15 min
  },
}
```

Run on demand:

```bash
curl -X POST http://localhost:3000/_nitro/tasks/db:cleanup
```

Or programmatically: `runTask('db:cleanup', { payload: {...} })`.

---

## 11. WebSockets

```ts
// nuxt.config.ts
nitro: { experimental: { websocket: true } }
```

```ts
// server/api/chat.ws.ts
export default defineWebSocketHandler({
  open(peer) {
    peer.send({ user: 'server', message: 'Welcome!' })
    peer.subscribe('chat')
  },
  message(peer, message) {
    peer.publish('chat', message.text())               // broadcast to channel
  },
  close(peer, details) {
    peer.unsubscribe('chat')
  },
  error(peer, error) {
    console.error('ws error', error)
  },
})
```

Client side:

```ts
const ws = new WebSocket('ws://localhost:3000/api/chat')
ws.onmessage = (e) => console.log(e.data)
ws.send('hello')
```

---

## 12. Background work after response

```ts
export default eventHandler(async (event) => {
  event.waitUntil(logToAnalytics(event))               // doesn't delay response
  return 'ok'
})
```

`event.waitUntil(promise)` — supported by Cloudflare Workers, Vercel Edge, and Node (best-effort). Use for fire-and-forget side effects (analytics, logging, cache warming) that shouldn't block the response.

---

## 13. Internal `$fetch` with cookie/header forwarding

When one server route calls another server route via `$fetch`, you'd normally lose the original request's cookies and headers. Solution: use `event.$fetch` instead of bare `$fetch`:

```ts
// server/api/profile.get.ts
export default defineEventHandler((event) => {
  // event.$fetch automatically forwards cookies + headers (except hop-by-hop)
  return event.$fetch('/api/me')
})
```

---

## 14. `#server` and `#shared` aliases

### `#server` — for code inside `server/`

```ts
// server/utils/formatUser.ts
export const formatUser = (u: User) => ({ id: u.id, name: u.fullName })

// server/api/users/[id].get.ts
import { formatUser } from '#server/utils/formatUser'   // or rely on auto-import
```

Auto-import: `server/utils/*.ts` is auto-imported in the server context only — usually you don't need the explicit `import` line.

### `#shared` — for code usable on both sides

Code in `<rootDir>/shared/utils/` and `<rootDir>/shared/types/` is **auto-imported in both** the app and the server context. Use this for things like:
- Validation schemas (Zod schemas you want to use both in server validation AND client form validation)
- Pure utility functions (date formatters, slug builders)
- Shared types

```ts
// shared/utils/slugify.ts
export const slugify = (s: string) => s.toLowerCase().replace(/[^a-z0-9]+/g, '-')
```

Use anywhere — no import statement needed.

⚠️ Only `shared/utils/` and `shared/types/` are auto-imported, and only **top-level files**. Other subdirectories need explicit imports via the `#shared` alias.

---

## 15. Errors from server routes

```ts
export default defineEventHandler(async (event) => {
  const id = Number(getRouterParam(event, 'id'))
  if (!Number.isInteger(id)) {
    throw createError({
      status: 400,
      statusText: 'Bad Request',
      message: 'ID must be an integer',
      data: { id, hint: 'Try /api/users/123' },          // surfaces in error.data
      fatal: false,
    })
  }
  const user = await db.users.findById(id)
  if (!user) throw createError({ status: 404, statusText: 'Not Found' })
  return user
})
```

The client sees:
- `useFetch` → `error.value.statusCode`, `error.value.statusMessage`, `error.value.data` (already parsed in Nuxt 4!)
- `$fetch` → throws an `FetchError` with `.status`, `.statusText`, `.data`

---

## 16. Full pattern — REST resource

```ts
// server/api/posts.get.ts
export default defineCachedEventHandler(async (event) => {
  const { page = 1, limit = 20 } = getQuery(event)
  return db.posts.list({ page: Number(page), limit: Number(limit) })
}, { maxAge: 30, swr: true })

// server/api/posts.post.ts
import { z } from 'zod'
const CreatePost = z.object({ title: z.string().min(1), body: z.string() })

export default defineEventHandler(async (event) => {
  if (!event.context.user) throw createError({ status: 401 })
  const data = await readValidatedBody(event, CreatePost.parse)
  setResponseStatus(event, 201)
  return db.posts.create({ ...data, authorId: event.context.user.id })
})

// server/api/posts/[id].get.ts
export default defineEventHandler(async (event) => {
  const id = getRouterParam(event, 'id')
  const post = await db.posts.findById(id)
  if (!post) throw createError({ status: 404 })
  return post
})

// server/api/posts/[id].patch.ts
const UpdatePost = z.object({ title: z.string().optional(), body: z.string().optional() })

export default defineEventHandler(async (event) => {
  if (!event.context.user) throw createError({ status: 401 })
  const id = getRouterParam(event, 'id')
  const data = await readValidatedBody(event, UpdatePost.parse)
  return db.posts.update(id, data)
})

// server/api/posts/[id].delete.ts
export default defineEventHandler(async (event) => {
  if (!event.context.user) throw createError({ status: 401 })
  await db.posts.delete(getRouterParam(event, 'id'))
  setResponseStatus(event, 204)
})
```
