# Modules & Layers

Deep reference for using existing Nuxt modules, authoring your own modules with `@nuxt/kit`, and structuring code reuse with layers.

## Table of contents

1. Installing & using modules
2. Popular ecosystem modules
3. Authoring a module — quickstart
4. `@nuxt/kit` utility reference
5. Module options & runtime config
6. Add components, composables, server handlers
7. Templates & type generation
8. Module hooks
9. Publishing a module (`@nuxt/module-builder`)
10. Layers — reuse code across projects
11. Layer registration & priority
12. Layer use cases

---

## 1. Installing & using modules

```bash
nuxt module add <name>      # installs + adds to nuxt.config.modules + scaffolds config
```

Or manually:

```bash
npm install -D @nuxt/image
```

```ts
// nuxt.config.ts
export default defineNuxtConfig({
  modules: ['@nuxt/image'],
  image: {
    quality: 80,
    format: ['webp'],
  },
})
```

Each module documents its own config key under `nuxt.config`.

---

## 2. Popular ecosystem modules

| Module | Purpose |
|---|---|
| `@nuxt/image` | `<NuxtImg>` / `<NuxtPicture>` — IPX provider or remote CDN |
| `@nuxt/content` | File-based MD/MDC CMS in `content/` |
| `@nuxt/ui` / `@nuxt/ui-pro` | Vue + Tailwind component library (Nuxt UI v3) |
| `@nuxt/fonts` | Self-hosted fonts with auto-optimization |
| `@nuxt/icon` | SVG icon system with Iconify integration |
| `@nuxt/scripts` | Third-party scripts with safe loading + privacy |
| `@nuxt/eslint` | ESLint config for Nuxt |
| `@nuxt/test-utils` | Testing utilities |
| `@pinia/nuxt` | Pinia store integration |
| `@nuxtjs/tailwindcss` | TailwindCSS integration |
| `@vueuse/nuxt` | VueUse composables auto-imported |
| `@nuxtjs/i18n` | Internationalization (vue-i18n) |
| `@nuxtjs/color-mode` | Dark/light mode with system preference |
| `@nuxtjs/seo` | SEO suite (sitemap, robots, og-image, schema.org) |
| `@nuxtjs/sitemap` / `@nuxtjs/robots` | Standalone SEO modules |
| `@sidebase/nuxt-auth` | Authentication (NextAuth.js port) |
| `nuxt-auth-utils` | Lightweight auth utilities |
| `@vee-validate/nuxt` | Form validation |
| `@formkit/nuxt` | Form framework |
| `nuxt-security` | Security headers + CSP |
| `nuxt-svgo` | Inline optimized SVG |
| `@nuxtjs/device` | User agent / device detection |
| `@nuxtjs/turnstile` | Cloudflare Turnstile |

Browse all at `https://nuxt.com/modules`.

---

## 3. Authoring a module — quickstart

Local modules live in `<rootDir>/modules/`:
- `modules/<name>/index.ts` (folder form — preferred when you have runtime code)
- `modules/<name>.ts` (single-file form — simple modules)

```ts
// modules/hello/index.ts
import {
  defineNuxtModule, createResolver,
  addPlugin, addImportsDir, addComponent, addServerHandler,
} from '@nuxt/kit'

export interface ModuleOptions {
  apiKey: string
  baseURL: string
  enabled?: boolean
}

export default defineNuxtModule<ModuleOptions>({
  meta: {
    name: '@my/hello',
    version: '1.0.0',
    configKey: 'hello',                              // nuxt.config: { hello: {...} }
    compatibility: { nuxt: '>=4.0.0' },
  },
  defaults: {
    baseURL: 'https://api.example.com',
    apiKey: '',
    enabled: true,
  },
  async setup(options, nuxt) {
    if (!options.enabled) return false               // returning false disables the module

    const resolver = createResolver(import.meta.url)

    // Expose to client via runtimeConfig.public (don't leak the API key!)
    nuxt.options.runtimeConfig.public.hello = { baseURL: options.baseURL }
    nuxt.options.runtimeConfig.hello = { apiKey: options.apiKey }   // private

    // Auto-import composables from runtime/composables/
    addImportsDir(resolver.resolve('./runtime/composables'))

    // Add a component
    addComponent({
      name: 'HelloBadge',
      filePath: resolver.resolve('./runtime/components/HelloBadge.vue'),
    })

    // Add a Vue plugin
    addPlugin({
      src: resolver.resolve('./runtime/plugin.client.ts'),
      mode: 'client',
    })

    // Add a server route
    addServerHandler({
      route: '/api/_hello/ping',
      handler: resolver.resolve('./runtime/server/api/ping.get'),
    })
  },
})
```

⚠️ All runtime code in a module **MUST live inside `<module>/runtime/`** (or another folder you reference via `createResolver`). This keeps it properly type-checked and excluded from build-time TS context. Common subdirs:

```
modules/hello/
├─ index.ts                       # the module itself (build-time)
└─ runtime/                       # all runtime code (ships in the app)
   ├─ composables/
   ├─ components/
   ├─ plugin.client.ts
   ├─ middleware/
   └─ server/
      └─ api/ping.get.ts
```

### `.with()` form (typed defaults)

```ts
export default defineNuxtModule<ModuleOptions>().with({
  meta: { name: '@my/hello', configKey: 'hello' },
  defaults: { baseURL: 'https://api.example.com' },
  setup(options, nuxt) { /* options is fully typed */ },
})
```

---

## 4. `@nuxt/kit` utility reference

### Resolvers / paths

| Function | Use |
|---|---|
| `createResolver(import.meta.url)` | Returns `{ resolve, resolvePath }` for relative paths |
| `resolver.resolve('./runtime/x')` | Absolute path |
| `resolver.resolvePath('foo.vue')` | Async resolve (looks up extension) |

### Adding things to the app

| Function | Adds |
|---|---|
| `addPlugin(plugin, { append? })` | Vue plugin |
| `addPluginTemplate({ filename, getContents })` | Dynamically generated plugin |
| `addComponent({ name, filePath, mode?, global?, island?, export? })` | Single component |
| `addComponentsDir({ path, prefix?, pathPrefix? })` | All components in a directory |
| `addImports({ name, from, as? })` | Single auto-import |
| `addImportsDir(dirs)` | All exports from directories |
| `addImportsSources([{ from, imports: ['x', 'y'] }])` | Auto-import from a 3rd-party package |
| `addRouteMiddleware({ name, path, global? }, { prepend?, override? })` | Route middleware |
| `addLayout({ filename, getContents }, name)` | Layout |
| `extendPages(cb)` + `pages:resolved` hook | Mutate generated routes |

### Adding to the server / Nitro

| Function | Adds |
|---|---|
| `addServerHandler({ route, handler, method?, middleware? })` | API/route handler |
| `addServerImports({ name, from })` / `addServerImportsDir(dirs)` | Auto-imports in server context |
| `addServerScanDir(dir)` | Scan an external dir for server routes |
| `addServerPlugin(filePath)` | Nitro plugin |
| `addDevServerHandler({ route, handler })` | Dev-only route |
| `addPrerenderRoutes(routes)` | Add routes to prerender list |

### Templates & types

| Function | Use |
|---|---|
| `addTemplate({ filename, getContents, write?, options? })` | Generate a file at build-time |
| `addTypeTemplate({ filename, getContents }, { nitro?, nuxt? })` | Generate a `.d.ts` file |
| `addServerTemplate(template)` | Server-only template |
| `updateTemplates({ filter })` | Trigger HMR for templates |

### Misc

| Function | Use |
|---|---|
| `installModule(name, options?)` | Programmatically install another module |
| `extendViteConfig(cb)` / `extendWebpackConfig(cb)` | Modify bundler config |
| `useLogger('module-name')` | Scoped logger (consola) |
| `useNuxt()` | Current Nuxt instance (inside `setup`) |
| `useNitro()` | Nitro instance — ONLY inside `ready` hook |
| `isNuxtMajorVersion(4)` | Conditional v3 vs v4 logic |

⚠️ **Lodash / EJS template syntax was removed in Nuxt 4.** Use `getContents` (a function returning a string) instead of `getContents` (a string with `<%= %>` placeholders).

---

## 5. Module options & runtime config

Use `defu` to merge options safely (deep merge that doesn't overwrite user-set keys):

```ts
import { defu } from 'defu'

setup(options, nuxt) {
  nuxt.options.runtimeConfig.public.myModule = defu(
    nuxt.options.runtimeConfig.public.myModule,
    { foo: options.foo, baseURL: options.baseURL },
  )
}
```

This way users can override your module's defaults via env vars:

```bash
NUXT_PUBLIC_MY_MODULE_BASE_URL=https://prod.example.com node .output/server/index.mjs
```

### Expose typed options

```ts
declare module '@nuxt/schema' {
  interface PublicRuntimeConfig {
    myModule: { baseURL: string; foo: string }
  }
}
```

---

## 6. Adding components, composables, server handlers (worked examples)

### Add composables

```ts
// In setup:
addImportsDir(resolver.resolve('./runtime/composables'))

// modules/hello/runtime/composables/useHello.ts
export const useHello = () => {
  const config = useRuntimeConfig()
  return { greet: (n: string) => `Hello ${n} from ${config.public.hello.baseURL}` }
}
```

Now `useHello()` is auto-imported app-wide.

⚠️ Inside a published module's runtime files, **you must explicitly `import { x } from '#imports'`** — auto-imports from the user's app don't apply to your module's source code:

```ts
// modules/hello/runtime/composables/useHello.ts
import { useRuntimeConfig } from '#imports'
export const useHello = () => useRuntimeConfig().public.hello
```

### Add components with a directory

```ts
addComponentsDir({
  path: resolver.resolve('./runtime/components'),
  prefix: 'Hello',                                    // <Hello***Badge> etc
  pathPrefix: false,                                  // don't add path-based prefix
  global: false,                                       // chunked, not global
})
```

### Add a server handler

```ts
addServerHandler({
  route: '/api/_hello/ping',
  handler: resolver.resolve('./runtime/server/api/ping.get'),
})
```

```ts
// modules/hello/runtime/server/api/ping.get.ts
import { defineEventHandler } from '#imports'
export default defineEventHandler(() => ({ pong: true }))
```

### Add route middleware

```ts
addRouteMiddleware(
  {
    name: 'hello-auth',
    path: resolver.resolve('./runtime/middleware/auth'),
    global: true,                                      // run on every nav
  },
  { prepend: true },                                   // run before user middleware
)
```

---

## 7. Templates & type generation

### Add a generated runtime file

```ts
addTemplate({
  filename: 'hello.config.mjs',
  getContents: () => `export default ${JSON.stringify(options)}`,
})
```

Import in your runtime:

```ts
// modules/hello/runtime/composables/useHello.ts
// @ts-expect-error virtual file
import config from '#build/hello.config.mjs'
```

### Add types (extend `#hello` alias)

```ts
addTypeTemplate({
  filename: 'types/hello.d.ts',
  getContents: () => `
declare module '#hello' {
  interface HelloUser { id: string; name: string }
}
`,
}, { nitro: true, nuxt: true })
```

---

## 8. Module hooks

```ts
setup(options, nuxt) {
  // Wait for other modules to finish
  nuxt.hook('modules:done', () => {
    // safe to inspect other modules' contributions
  })

  // After page metadata is scanned (Nuxt 4)
  nuxt.hook('pages:resolved', (pages) => {
    // mutate page meta here, NOT in pages:extend
  })

  // After Nitro is ready
  nuxt.hook('ready', () => {
    const nitro = useNitro()
    nitro.logger.info('[hello] ready')
  })

  // Listen for file changes in dev
  nuxt.hook('builder:watch', (event, path) => { /* ... */ })

  // Customize Nitro config
  nuxt.hook('nitro:config', (nitroConfig) => {
    nitroConfig.runtimeConfig = nitroConfig.runtimeConfig || {}
  })
}
```

### Module-level `onInstall` / `onUpgrade` callbacks

```ts
defineNuxtModule({
  meta: { name: 'hello' },
  async onInstall(nuxt) {
    // Runs once when the module is first installed (nuxt module add)
  },
  async onUpgrade(nuxt, options, previous) {
    // Runs on `nuxt upgrade` if the module version changed
  },
  setup() {},
})
```

---

## 9. Publishing a module (`@nuxt/module-builder`)

```bash
npx nuxi init -t module my-module    # scaffolds a module template
cd my-module
npm install
npm run dev:prepare
```

The template includes:
- `src/module.ts` — entry
- `src/runtime/` — runtime code (composables, plugins, components, server)
- `playground/` — test app to develop against
- `test/` — Vitest tests using `@nuxt/test-utils`

Build & publish:

```bash
npm run prepack          # @nuxt/module-builder build
npm publish
```

---

## 10. Layers — reuse code across projects

Layers are Nuxt projects that extend other Nuxt projects. Use them to:
- Share a design system + components across multiple apps
- Build a multi-tenant app with shared base + per-tenant overrides
- Distribute starter templates as installable packages

Layer = any Nuxt project. Must contain at minimum a `nuxt.config.ts` (can be empty: `export default defineNuxtConfig({})`).

### Local layers (auto-registered)

```
<rootDir>/
├─ layers/                # auto-registered
│  ├─ 1.base/
│  │  ├─ nuxt.config.ts
│  │  ├─ app/components/Logo.vue
│  │  ├─ app/composables/useTheme.ts
│  │  └─ server/utils/db.ts
│  ├─ 2.marketing/
│  └─ 3.admin/
└─ nuxt.config.ts         # main project
```

Number prefixes control priority (alphabetical — Z beats A, so `3.` overrides `1.`).

### Layers via `extends`

```ts
// nuxt.config.ts
export default defineNuxtConfig({
  extends: [
    '../base-layer',                                           // local path
    '@my-themes/awesome',                                       // npm package
    'github:my-themes/awesome#v1',                              // git ref
    ['github:my-themes/private', { auth: process.env.GH_TOKEN }],   // private git
    './packages/marketing-layer',                               // monorepo
  ],
})
```

Remote layers (git refs) are fetched at build time via `giget` and cached locally.

---

## 11. Layer priority

High → low priority:

1. **Your project files** (highest priority)
2. **`~~/layers/*`** — alphabetical order (Z > A); use number prefixes to control
3. **`extends`** array — first item > last item

Files in higher-priority layers **override** files in lower-priority layers with the same path. So if `app/components/Logo.vue` exists in both project and a layer, the project's version wins.

### Module loading order (changed in Nuxt 4)

In Nuxt 4, **layers' modules load FIRST, then the project's modules**. This is the opposite of Nuxt 3 (which loaded the project first). The new order is correct because it lets the project's modules override layer modules.

For cross-module dependencies, use the `modules:done` hook to react after all modules have loaded.

---

## 12. Layer use cases

### Design system layer

```
layers/design-system/
├─ nuxt.config.ts
├─ app/
│  ├─ components/         # Button.vue, Card.vue, Modal.vue, ...
│  ├─ composables/useTheme.ts
│  └─ assets/css/tokens.css
└─ shared/types/theme.d.ts
```

```ts
// layers/design-system/nuxt.config.ts
export default defineNuxtConfig({
  css: ['~/assets/css/tokens.css'],
  modules: ['@nuxtjs/tailwindcss'],
})
```

Use it: every project that does `extends: ['../design-system']` gets all components and the theme CSS.

### Multi-tenant app

```
<rootDir>/
├─ layers/base/             # shared logic
│  ├─ app/                  # shared pages, components, composables
│  └─ server/               # shared API
├─ tenants/
│  ├─ acme/                 # tenant-specific overrides
│  │  ├─ app/assets/css/theme.css
│  │  └─ app/components/Logo.vue
│  └─ globex/
└─ nuxt.config.ts           # chooses which tenant via env var
```

```ts
// nuxt.config.ts
const tenant = process.env.TENANT || 'acme'
export default defineNuxtConfig({
  extends: ['./layers/base', `./tenants/${tenant}`],
})
```

### NPM-distributed layer

Publish your layer as an npm package:

```json
{
  "name": "@my-org/nuxt-design-system",
  "main": "./nuxt.config.ts",
  "files": ["app", "shared", "nuxt.config.ts", "modules"]
}
```

Users install:

```bash
npm install @my-org/nuxt-design-system
```

```ts
// nuxt.config.ts
export default defineNuxtConfig({
  extends: ['@my-org/nuxt-design-system'],
})
```

### Layer aliases

Each layer is auto-aliased as `#layers/<name>`:

```ts
// In your project, reference a specific layer
import { Button } from '#layers/design-system/components'
```

---

## Common module/layer pitfalls

| Symptom | Cause / Fix |
|---|---|
| Module runtime code not type-checked | Move all runtime code into `<module>/runtime/`, use `createResolver`, and import via `#imports` |
| Runtime config overwritten by module | Use `defu` for safe merging |
| Layer not picked up | Layer must contain `nuxt.config.ts` (can be empty); check spelling / casing |
| `pages:extend` hook can't mutate meta | Use `pages:resolved` instead — v4 reorders these hooks |
| `useNitro()` returns undefined | Only available inside the `ready` hook |
| Module hooks fire in wrong order | Use `modules:done` to wait for all modules; respect `enforce: 'pre' \| 'post'` |
| Local layer's modules don't run | In v4, layer modules load before project modules — order is intentional |
| `addTemplate` with `<%= %>` placeholders doesn't work | Removed in v4 — use `getContents: () => 'string'` |
| Components from layer not found | Check path overrides — same-named files in project override layer |
