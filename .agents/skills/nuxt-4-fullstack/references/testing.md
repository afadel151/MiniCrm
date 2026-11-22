# Testing with `@nuxt/test-utils`

Deep reference for testing Nuxt 4 apps — unit tests, Nuxt-environment component tests, end-to-end tests, and Playwright integration.

## Table of contents

1. Setup & install
2. Vitest config (three project types)
3. Nuxt runtime environment (`mountSuspended`, `renderSuspended`)
4. Mocking auto-imports & components
5. Mocking endpoints
6. End-to-end testing
7. Playwright integration
8. Testing patterns & gotchas

---

## 1. Setup & install

```bash
npm i -D @nuxt/test-utils vitest @vue/test-utils happy-dom playwright-core
```

Add the module (optional but enables `import.meta.test` and config helpers):

```ts
// nuxt.config.ts
export default defineNuxtConfig({
  modules: ['@nuxt/test-utils/module'],
})
```

Set `package.json` to ESM (or use `.mts` config files):

```json
{ "type": "module" }
```

---

## 2. Vitest config — three project types

Split tests into **unit** (pure functions, node env), **nuxt** (component tests needing the Nuxt runtime), and **e2e** (full server boot).

```ts
// vitest.config.ts
import { defineConfig } from 'vitest/config'
import { defineVitestProject } from '@nuxt/test-utils/config'

export default defineConfig({
  test: {
    projects: [
      // Pure unit tests — fast, no Nuxt
      {
        test: {
          name: 'unit',
          include: ['test/unit/**/*.{test,spec}.ts'],
          environment: 'node',
        },
      },
      // Component tests — full Nuxt runtime
      await defineVitestProject({
        test: {
          name: 'nuxt',
          include: ['test/nuxt/**/*.{test,spec}.ts'],
          environment: 'nuxt',
          environmentOptions: {
            nuxt: {
              domEnvironment: 'happy-dom',   // or 'jsdom'
              overrides: { /* nuxt.config overrides for tests */ },
            },
          },
        },
      }),
      // E2E tests — boots a real server
      {
        test: {
          name: 'e2e',
          include: ['test/e2e/**/*.{test,spec}.ts'],
          environment: 'node',
        },
      },
    ],
  },
})
```

Run a specific project:

```bash
vitest --project unit
vitest --project nuxt
vitest --project e2e
vitest               # all
```

### Opting individual files into the Nuxt environment

Instead of a directory-based project, you can opt in per-file:

```ts
// @vitest-environment nuxt
import { it, expect } from 'vitest'
```

Or name the file `*.nuxt.test.ts` / `*.nuxt.spec.ts`.

---

## 3. Nuxt runtime environment

These come from `@nuxt/test-utils/runtime` and require `environment: 'nuxt'`.

### `mountSuspended` — mount a component with full Nuxt context

Built on `@vue/test-utils`'s `mount`, but handles async setup (`<Suspense>`), auto-imports, plugins, and the Nuxt app context.

```ts
import { describe, it, expect } from 'vitest'
import { mountSuspended } from '@nuxt/test-utils/runtime'
import { SomeComponent } from '#components'
import App from '~/app.vue'

describe('SomeComponent', () => {
  it('renders with async data', async () => {
    const wrapper = await mountSuspended(SomeComponent, {
      route: '/test',                            // sets the active route
      props: { title: 'Hi' },
      slots: { default: () => 'slot content' },
    })
    expect(wrapper.text()).toContain('Hi')
  })

  it('mounts the whole app at a route', async () => {
    const wrapper = await mountSuspended(App, { route: '/about' })
    expect(wrapper.html()).toContain('About')
  })
})
```

`mountSuspended` returns a standard `@vue/test-utils` `VueWrapper` — use `.find`, `.text`, `.html`, `.trigger`, `.setValue`, `.emitted`, etc.

### `renderSuspended` — render with Testing Library

Built on `@testing-library/vue` for those who prefer that API.

```ts
import { renderSuspended } from '@nuxt/test-utils/runtime'
import { screen } from '@testing-library/vue'
import App from '~/app.vue'

it('renders', async () => {
  await renderSuspended(App, { route: '/' })
  expect(screen.getByRole('heading')).toBeTruthy()
})
```

---

## 4. Mocking auto-imports & components

### `mockNuxtImport` — mock any auto-imported composable

```ts
import { mockNuxtImport } from '@nuxt/test-utils/runtime'

// Mock useState
mockNuxtImport('useState', () => {
  return () => ref('mocked value')
})

// Mock useFetch with a typed factory
const fetchMock = vi.fn()
mockNuxtImport('useFetch', () => fetchMock)

// Per-test reset
import { vi } from 'vitest'
const { useStorageMock } = vi.hoisted(() => ({ useStorageMock: vi.fn(() => 'x') }))
mockNuxtImport('useStorage', () => useStorageMock)

beforeEach(() => { useStorageMock.mockClear() })
```

⚠️ `mockNuxtImport` can only be called **once per import name per file** — it's a macro transformed at build time. Use `vi.hoisted` if you need to control the mock per-test.

### `mockComponent` — replace a component

```ts
import { mockComponent } from '@nuxt/test-utils/runtime'

// Inline implementation
mockComponent('MyButton', {
  props: ['label'],
  setup(props) {
    return () => h('button', props.label)
  },
})

// Or point to a mock file
mockComponent('~/components/Chart.vue', () => import('./MockChart.vue'))
```

---

## 5. Mocking endpoints — `registerEndpoint`

Stub Nitro routes so components can fetch without a real backend.

```ts
import { registerEndpoint } from '@nuxt/test-utils/runtime'

// GET (default)
registerEndpoint('/api/users', () => [{ id: 1, name: 'Alice' }])

// Specific method + one-shot
registerEndpoint('/api/users', {
  method: 'POST',
  once: true,                                    // only intercept the first call
  handler: () => ({ ok: true }),
})

// With dynamic response
registerEndpoint('/api/echo', (event) => {
  return { method: event.method, url: event.path }
})
```

---

## 6. End-to-end testing

From `@nuxt/test-utils/e2e` — boots a real Nuxt server.

```ts
import { describe, it, expect } from 'vitest'
import { $fetch, fetch, url, createPage, setup } from '@nuxt/test-utils/e2e'

describe('App (e2e)', async () => {
  await setup({
    rootDir: fileURLToPath(new URL('.', import.meta.url)),
    server: true,                                 // boot the server
    browser: true,                                // launch a browser (needs playwright-core)
    browserOptions: { type: 'chromium', launch: { headless: true } },
    build: true,                                   // build before testing
    setupTimeout: 120_000,
  })

  it('renders the home page (HTML)', async () => {
    const html = await $fetch('/')
    expect(html).toContain('<h1>')
  })

  it('returns 200', async () => {
    const res = await fetch('/')
    expect(res.status).toBe(200)
  })

  it('works in a real browser', async () => {
    const page = await createPage('/')
    const text = await page.getByRole('heading').textContent()
    expect(text).toContain('Welcome')
  })
})
```

E2E helpers:

| Helper | Purpose |
|---|---|
| `setup(options)` | Boot the test server (call inside `describe(async () => {...})`) |
| `$fetch(path)` | Fetch + return parsed response (HTML/JSON) |
| `fetch(path)` | Raw `Response` (status, headers) |
| `url(path)` | Absolute URL of a path on the test server |
| `createPage(path?)` | A Playwright `Page` navigated to the path |

⚠️ **You cannot mix `/runtime` and `/e2e` imports in the same file.** Keep them in separate files (e.g. `*.nuxt.spec.ts` for runtime, `*.e2e.spec.ts` for e2e).

---

## 7. Playwright integration

Use `@nuxt/test-utils/playwright` to boot Nuxt directly from the Playwright runner.

```ts
// playwright.config.ts
import { fileURLToPath } from 'node:url'
import { defineConfig, devices } from '@playwright/test'
import type { ConfigOptions } from '@nuxt/test-utils/playwright'

export default defineConfig<ConfigOptions>({
  use: {
    nuxt: {
      rootDir: fileURLToPath(new URL('.', import.meta.url)),
    },
  },
  projects: [
    { name: 'chromium', use: { ...devices['Desktop Chrome'] } },
  ],
})
```

```ts
// tests/app.spec.ts
import { expect, test } from '@nuxt/test-utils/playwright'

test('home page', async ({ page, goto }) => {
  await goto('/', { waitUntil: 'hydration' })       // ← 'hydration' is a Nuxt-specific wait state
  await expect(page.getByRole('heading')).toHaveText('Welcome to Nuxt')
})

test('navigation works', async ({ page, goto }) => {
  await goto('/', { waitUntil: 'hydration' })
  await page.getByRole('link', { name: 'About' }).click()
  await expect(page).toHaveURL(/\/about/)
})
```

The `goto` fixture supports `waitUntil: 'hydration'` — waits until Nuxt has hydrated, which is more reliable than `'load'` for SPA-style assertions.

---

## 8. Testing patterns & gotchas

### Pattern: test a composable

```ts
// @vitest-environment nuxt
import { it, expect } from 'vitest'
import { useCounter } from '~/composables/useCounter'

it('increments', () => {
  const { count, inc } = useCounter()
  expect(count.value).toBe(0)
  inc()
  expect(count.value).toBe(1)
})
```

### Pattern: test a page with mocked data

```ts
// test/nuxt/products.nuxt.spec.ts
import { it, expect, vi } from 'vitest'
import { mountSuspended, registerEndpoint } from '@nuxt/test-utils/runtime'
import ProductsPage from '~/pages/products.vue'

registerEndpoint('/api/products', () => [
  { id: 1, title: 'Widget' },
  { id: 2, title: 'Gadget' },
])

it('lists products', async () => {
  const wrapper = await mountSuspended(ProductsPage, { route: '/products' })
  expect(wrapper.text()).toContain('Widget')
  expect(wrapper.text()).toContain('Gadget')
})
```

### Pattern: test a server route directly (unit-ish)

```ts
// test/nuxt/api.nuxt.spec.ts
import { it, expect } from 'vitest'
import { $fetch } from '@nuxt/test-utils/e2e'   // in an e2e-setup file
// or with registerEndpoint mocking in a runtime file
```

For pure handler logic, extract the business logic into a `shared/utils/` function and unit-test that in the `node` environment — much faster than booting Nitro.

### Gotchas

| Symptom | Fix |
|---|---|
| `useX is not defined` in test | Use the `nuxt` environment + run `nuxt prepare` to generate types; mock with `mockNuxtImport` if you don't want the real impl |
| `mockNuxtImport` "already mocked" error | You called it twice for the same name — combine into one, use `vi.hoisted` for per-test control |
| Mixing `/runtime` and `/e2e` errors | Split into separate files |
| Component with `useFetch` hits real network | `registerEndpoint` to stub it |
| E2E test times out on `setup` | Increase `setupTimeout`; ensure `build: true` only when needed |
| Playwright assertions flaky | Use `goto(path, { waitUntil: 'hydration' })` |
| Auto-imports missing in CI | Run `nuxt prepare` before `vitest` in the CI pipeline |
| `happy-dom` missing API | Switch `domEnvironment` to `'jsdom'` |

### CI pipeline order

```bash
nuxt prepare            # generate .nuxt/ types + auto-import registry
vue-tsc -b --noEmit     # typecheck
vitest run              # all test projects
```
