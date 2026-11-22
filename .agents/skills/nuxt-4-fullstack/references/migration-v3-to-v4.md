# Migrating Nuxt 3 → Nuxt 4

Complete reference for upgrading a Nuxt 3 project to Nuxt 4: the automated path (codemods), every breaking change, and the compatibility flag to revert each one.

## Table of contents

1. The fast path (codemods)
2. Directory structure migration
3. Data fetching changes
4. Head / Unhead 2 changes
5. TypeScript changes
6. Component & styling changes
7. Removed / changed config
8. Compatibility flags (revert anything)
9. Manual migration checklist
10. Testing the upgrade (Nuxt 5 future flag)

---

## 1. The fast path (codemods)

```bash
# One-shot: runs the full migration recipe (interactive)
npx codemod@latest nuxt/4/migration-recipe

# Individual codemods:
npx codemod@latest nuxt/4/file-structure                  # move srcDir → app/
npx codemod@latest nuxt/4/default-data-error-value        # null → undefined
npx codemod@latest nuxt/4/deprecated-dedupe-value         # dedupe: true → 'cancel'
npx codemod@latest nuxt/4/shallow-function-reactivity     # add deep: true where needed
npx codemod@latest nuxt/4/absolute-watch-path             # watch path changes
npx codemod@latest nuxt/4/template-compilation-changes    # getContents string → fn
```

Then upgrade Nuxt itself:

```bash
nuxt upgrade
# or manually bump "nuxt": "^4.0.0" in package.json and reinstall
```

After upgrading, run `nuxt prepare` to regenerate types, then `nuxt typecheck` to surface remaining issues.

---

## 2. Directory structure migration

The biggest visible change: **the new `app/` directory becomes `srcDir`.**

### Before (Nuxt 3)

```
<rootDir>/
├─ components/
├─ composables/
├─ layouts/
├─ middleware/
├─ pages/
├─ plugins/
├─ utils/
├─ app.vue
├─ server/
├─ public/
├─ modules/
└─ nuxt.config.ts
```

### After (Nuxt 4)

```
<rootDir>/
├─ app/                  # ← everything that was app-level moves here
│  ├─ components/
│  ├─ composables/
│  ├─ layouts/
│  ├─ middleware/
│  ├─ pages/
│  ├─ plugins/
│  ├─ utils/
│  └─ app.vue
├─ shared/               # NEW — code shared between app and server
├─ server/               # stays at rootDir (was already there)
├─ public/               # stays at rootDir
├─ modules/              # stays at rootDir
└─ nuxt.config.ts
```

What moves into `app/`: `components/`, `composables/`, `layouts/`, `middleware/`, `pages/`, `plugins/`, `utils/`, `app.vue`, `app.config.ts`, `error.vue`, `router.options.ts`, and `assets/`.

What stays at `<rootDir>`: `server/`, `public/`, `modules/`, `content/`, `layers/`, `nuxt.config.ts`, `.env`.

The `nuxt/4/file-structure` codemod does this move automatically.

### Why the change?

- Cleaner separation between client app code (`app/`) and server/build code
- Faster file watching (the IDE/bundler watches a narrower tree)
- `~/` and `@/` now resolve to `app/`, making imports unambiguous

### Reverting (keep Nuxt 3 layout)

```ts
// nuxt.config.ts
export default defineNuxtConfig({
  srcDir: '.',
  dir: { app: 'app' },     // keep app/ for router.options etc.
})
```

---

## 3. Data fetching changes

### `data` and `error` are now `shallowRef`

In Nuxt 3, `useAsyncData`/`useFetch` returned a deeply-reactive `ref`. In Nuxt 4 they return a **`shallowRef`** by default — mutating nested properties won't trigger reactivity.

```ts
const { data } = await useFetch('/api/user')
data.value.name = 'New'           // ❌ won't trigger re-render in v4
data.value = { ...data.value, name: 'New' }   // ✅ replace the whole value
```

Revert per-call: `useFetch('/api/user', { deep: true })`.
Revert globally: `experimental: { defaults: { useAsyncData: { deep: true } } }`.

### `data` / `error` default to `undefined`, not `null`

```ts
const { data, error } = await useFetch('/api/x')
// Before: data.value === null on error
// After:  data.value === undefined
```

Update your template guards. Codemod: `nuxt/4/default-data-error-value`.

### Same-key calls now share refs

Multiple `useFetch`/`useAsyncData` calls with the same key share `data`/`error`/`status`. These options must match across calls: `handler`, `deep`, `transform`, `pick`, `getCachedData`, `default`. (See `data-fetching-state.md` §6.)

Revert: `experimental: { granularCachedData: false }`.

### `getCachedData` is called on every fetch

Previously called only on the initial fetch. Now called on initial + refresh + watch, with a `ctx.cause` argument. Handle the cause to avoid serving stale data on manual refresh.

Revert: `experimental: { granularCachedData: false }`.

### `refresh({ dedupe })` no longer accepts booleans

```ts
refresh({ dedupe: true })    // ❌ removed
refresh({ dedupe: 'cancel' }) // ✅
refresh({ dedupe: 'defer' })  // ✅
```

Codemod: `nuxt/4/deprecated-dedupe-value`.

### `pending` is now computed

`pending` used to stay `true` until the first fetch completed even with `immediate: false`. Now it's `true` only while `status === 'pending'`.

Revert: `experimental: { pendingWhenIdle: true }`.

### `clear()` respects `default()`

`clear()` now resets `data` to `options.default()` (was always `undefined`).

### Reactive keys auto-refetch

`useFetch(() => '/api/' + id.value)` and `useAsyncData(computed(() => key), fn)` now refetch when the key/url changes. To keep v3 behavior (don't refetch on key change):

Revert: `experimental: { alwaysRunFetchOnKeyChange: true }` (note: this changes behavior the *other* way — read carefully).

---

## 4. Head / Unhead 2 changes

Nuxt 4 ships **Unhead 2**. Breaking changes:

- Removed props: `vmid`, `hid`, `children`, `body`. Use `key` for deduplication, and `innerHTML` / `textContent` instead of `children`/`body`.
- Promise input to `useHead` is no longer supported — resolve before passing.
- Tags are auto-sorted by Capo.js (changes the order tags appear in `<head>`).
- Template Params and Alias Tag Sorting plugins are now opt-in (were always-on in v1).

```ts
// Before (v1)
useHead({ script: [{ children: 'console.log(1)' }] })
useHead({ meta: [{ hid: 'desc', name: 'description', content: '...' }] })

// After (v2)
useHead({ script: [{ innerHTML: 'console.log(1)' }] })
useHead({ meta: [{ key: 'desc', name: 'description', content: '...' }] })
```

Revert to v1 behavior:

```ts
// nuxt.config.ts
unhead: { legacy: true }
```

---

## 5. TypeScript changes

### Split tsconfig (project references)

Nuxt 4 generates four tsconfigs (`app`, `server`, `shared`, `node`) and a root `tsconfig.json` that references them. If you had custom `compilerOptions`, move them into the relevant context via:

```ts
// nuxt.config.ts
typescript: {
  tsConfig:       { compilerOptions: { /* app */ } },
  sharedTsConfig: { compilerOptions: { /* shared */ } },
  nodeTsConfig:   { compilerOptions: { /* node/build */ } },
}
```

Type-check command changes:

```bash
# Before
vue-tsc --noEmit
# After (project references need -b build mode)
vue-tsc -b --noEmit
# or just
nuxt typecheck
```

### `noUncheckedIndexedAccess: true`

Now on by default. Array/object index access returns `T | undefined`:

```ts
const first = items[0]            // type: Item | undefined (was Item)
const first = items.at(0)         // also Item | undefined
if (items[0]) { /* narrowed */ }
```

Revert: set `compilerOptions.noUncheckedIndexedAccess: false` in your tsconfig override.

### Augmentation context

With project references, type augmentations only apply in the matching context. Put cross-cutting augmentations in `shared/types/`.

---

## 6. Component & styling changes

### Component names normalized

A component's Vue `name` now matches its Nuxt auto-import name (path-prefixed). This affects `<KeepAlive :include="...">`, `<Transition>`, and tests that look up components by name.

```
app/components/base/foo/Button.vue → name "BaseFooButton" (was "Button")
```

Revert: `experimental: { normalizeComponentNames: false }`.

### Inline styles: component-only

Nuxt 4 only inlines **component** CSS during SSR (not global CSS). This reduces duplicate CSS.

Revert: `features: { inlineStyles: true }`.

### SPA loading template moved

The SPA loading template now renders **alongside** `#__nuxt` instead of inside it — prevents a flash when hydration replaces the root.

Revert: `experimental: { spaLoadingTemplateLocation: 'within' }`.

---

## 7. Removed / changed config

### Top-level `generate` removed

```ts
// Before
export default defineNuxtConfig({
  generate: { routes: ['/foo'] },
})
// After
export default defineNuxtConfig({
  nitro: { prerender: { routes: ['/foo'] } },
})
```

### `scanPageMeta` default + hook change

`experimental.scanPageMeta` is now `true` by default. Page meta is scanned **after** the `pages:extend` hook, so to mutate meta, use the new `pages:resolved` hook:

```ts
// Before
hooks: { 'pages:extend'(pages) { /* mutate meta */ } }
// After
hooks: { 'pages:resolved'(pages) { /* mutate meta here */ } }
```

### `window.__NUXT__` removed after hydration

```ts
// Before
const data = window.__NUXT__.data
// After
const data = useNuxtApp().payload.data
```

### Module loading order in layers

In Nuxt 4, layer modules load **before** project modules. If you relied on the old order (project first), check cross-module dependencies and use the `modules:done` hook.

### `error.data` auto-parsed

```ts
// Before
const detail = JSON.parse(error.value.data)
// After
const detail = error.value.data        // already parsed
```

### Lodash/EJS templates removed in module authoring

`addTemplate({ getContents })` must return a string from a function — `<%= %>` EJS placeholders no longer work. Codemod: `nuxt/4/template-compilation-changes`.

---

## 8. Compatibility flags — revert anything

Put these in `nuxt.config.ts` to restore Nuxt 3 behavior individually while you migrate:

```ts
export default defineNuxtConfig({
  // Directory structure
  srcDir: '.',
  dir: { app: 'app' },

  experimental: {
    granularCachedData: false,            // getCachedData: only on initial fetch
    purgeCachedData: false,               // don't purge cache on key/url change
    normalizeComponentNames: false,       // component name = filename only
    pendingWhenIdle: true,                // pending always true until first fetch
    alwaysRunFetchOnKeyChange: true,      // (read docs — behavior nuance)
    spaLoadingTemplateLocation: 'within', // SPA loader inside #__nuxt
    defaults: {
      useAsyncData: { deep: true },       // deep-reactive data refs
      useFetch: { deep: true },
    },
  },

  features: {
    inlineStyles: true,                   // inline global + component CSS
  },

  unhead: {
    legacy: true,                         // Unhead v1 behavior
  },
})
```

---

## 9. Manual migration checklist

1. **Bump** `nuxt` to `^4.0.0`, reinstall.
2. **Move** app code into `app/` (or run `npx codemod@latest nuxt/4/file-structure`).
3. **Create** `shared/` if you have code used by both app and server.
4. **Run** the data-value codemods (`default-data-error-value`, `deprecated-dedupe-value`).
5. **Audit** `data.value` mutations — wrap nested mutations or add `deep: true`.
6. **Update** template guards for `undefined` (was `null`).
7. **Replace** removed Unhead props (`vmid`/`hid`/`children`/`body`).
8. **Move** `generate` config → `nitro.prerender`.
9. **Move** `pages:extend` meta mutations → `pages:resolved`.
10. **Replace** `window.__NUXT__` → `useNuxtApp().payload`.
11. **Stop** `JSON.parse(error.data)` — it's already parsed.
12. **Fix** `vue-tsc --noEmit` → `vue-tsc -b --noEmit` (or `nuxt typecheck`).
13. **Address** `noUncheckedIndexedAccess` type errors (add guards or `.at()`).
14. **Verify** same-key `useFetch` calls have matching options.
15. **Run** `nuxt prepare && nuxt typecheck && vitest run`.

---

## 10. Testing the upgrade — Nuxt 5 future flag

To pre-test forward compatibility (don't ship to prod):

```ts
// nuxt.config.ts
export default defineNuxtConfig({
  future: { compatibilityVersion: 5 },
})
```

Enables behaviors planned for Nuxt 5: Vite Environment API, normalized page component names, `clearNuxtState` resetting to init value by default, non-async `callHook`, and client-only comment-node placeholders.

---

## Side-by-side change summary

| Topic | Nuxt 3 | Nuxt 4 |
|---|---|---|
| srcDir | `.` | `app/` |
| server/, public/, modules/ | under srcDir | under rootDir |
| `shared/` | — | new auto-imported dir |
| data ref | deep `ref` | `shallowRef` |
| data/error default | `null` | `undefined` |
| same-key fetch | independent | shares refs |
| `getCachedData` | initial only | every fetch + `cause` |
| `refresh({dedupe})` | boolean ok | `'cancel'`/`'defer'` only |
| `pending` | always true until first fetch | computed from status |
| reactive keys | unsupported | supported (auto-refetch) |
| Unhead | v1 | v2 (Capo.js, no vmid/hid) |
| tsconfig | single | split + references |
| `noUncheckedIndexedAccess` | false | true |
| component name | filename | path-prefixed |
| inline styles | global + component | component only |
| `generate` config | top-level | `nitro.prerender` |
| layer module order | project first | layers first |
| `error.data` | string | parsed |
| `window.__NUXT__` | persists | removed after hydration |
| `pages:extend` meta | works | use `pages:resolved` |
