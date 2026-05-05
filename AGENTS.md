# AGENTS.md - dux-pjax

Notes for AI agents (and humans skimming) working in this repo.

## What this is
Lightweight PJAX (PushState + AJAX) helper. Replaces `<main>` (or any container with `id` on a `<pjax>` tag or `.pjax` class) with the response body of an XHR, keeping history, scroll, and inline script execution in sync.

Consumers of this library inside `~/dev/dux`: `accounting`, `nekretnine`, `sleepy-shoe`, `soho-tasks`, `sohospot.com`, `bolja-pomoc`, `cms-lux`, `racunovodstvo`, `lux-template`, and others. Treat any public API as load-bearing; rg before removing.

## Layout
- `src/pjax.coffee` - main class, all static methods, lifecycle, history, swap logic.
- `src/onclick.coffee` - the `addEventListener('click', ...)` delegate. Reads link attributes, dispatches confirm, calls `Pjax.load`.
- `src/index.js` - imports the coffee modules and assigns `window.Pjax`. Default export.
- `scripts/build.mjs` - esbuild + coffeescript loader. Emits ESM, CJS, IIFE bundles into `dist/`.
- `test/pjax.test.coffee` - mocha + jsdom suite. Re-requires modules per test to avoid stale class state.
- `demo/` - static HTML pages served via `npm run demo`.

## Commands
```bash
npm install
npm run build      # one-off compile
npm run dev        # watch mode
npm test           # mocha + jsdom
npm run demo       # serves on :8000
```

## Conventions
- **Source language is CoffeeScript.** Don't convert to JS without explicit ask.
- **Do not edit `dist/*` by hand** — those are esbuild output. Always re-run `npm run build` after touching `src/`.
- **Attribute namespace is `pjax-*`.** New link/script attributes go under that prefix (`pjax-confirm`, `pjax-target`, `pjax-replace`, `pjax-delay`, etc). Older bare attributes (`click`, `data-pjax`, `data-path`, `path`) are kept for legacy reasons.
- **Lifecycle events are `pjax:<name>`.** Use `Pjax.emit(name, detail)` to dispatch — it returns `false` if a listener cancelled, which load() honors for `pjax:before`.
- **Tests must pass.** The full suite is `npm test`; run after every src change.
- **CoffeeScript fat arrow gotcha:** `=>` binds `this` lexically. In object literals (like `PjaxOnClick`), `this` is whoever called the method — for an `addEventListener` handler that's `window`, not the module. Use the module name explicitly (`PjaxOnClick.execute(ctx)`) instead of `@execute(ctx)`.

## Notable design decisions
- **Inline scripts run before the morph** (src/pjax.coffee:204-233). Rationale: inline scripts seed globals that the new HTML consumes on `pjax:render`. Scripts that need to query freshly-inserted siblings should listen for `pjax:render` or use `<script pjax-delay>` to defer to the next animation frame.
- **2-second same-href debounce** (src/pjax.coffee:298) protects against double-clicks. `Pjax.refresh()` and `Pjax.reload()` set `opts.force = true` to bypass. Programmatic `Pjax.load` calls within 2s of the same href are silently dropped unless `force` is set.
- **`Pjax.confirm`** (src/pjax.coffee:69) is the hook for `pjax-confirm` modals. Default delegates to `window.confirm`. Override returns boolean OR Promise<boolean>; async path holds the click and resolves before navigating. Promise rejection is logged via `Pjax.error`.
- **`Pjax.DEV`** (src/pjax.coffee:65) overrides `config.is_silent` so verbose logging works on production ports too.
- **View transitions** (src/pjax.coffee:188-196) are opt-in via `Pjax.useViewTransition = true`. The morph + `Pjax.after` + `pjax:render` all happen inside `startViewTransition`'s callback so listeners see the new DOM, not a half-applied state.
- **Form submit binding** (src/pjax.coffee:464-479) attaches once on either DOMContentLoaded or immediately if past `loading`. Guarded by `Pjax._booted` to prevent double-binding.

## Public API surface (rg before removing)
External callers in `~/dev/dux` rely on:
- `Pjax.onDocumentClick()` - boot
- `Pjax.load(href, opts)` - core
- `Pjax.refresh()` - re-fetch current path, full swap of the pjax container
- `Pjax.refresh('#node-id')` - re-fetch current path, swap only `#node-id` (must have an `id` matching the response). Skips history and scroll.
- `Pjax.refresh(path, opts?)` - re-fetch a different path with custom opts
- `Pjax.reload(opts?)` - hard reload, no-cache
- `Pjax.last()` - last navigated href (used in many svelte/fez components)
- `Pjax.refreshed()` - skip-animation-on-refresh check (used in info.fez and info.svelte components)
- `Pjax.pushState(href)` - shortcut over `history.pushState`
- `Pjax.qs(key, value?, opts?)` - querystring get/set/navigate
- `Pjax.config.*` - runtime config
- `Pjax.before` / `Pjax.after` / `Pjax.confirm` - hooks
- Events: `pjax:before`, `pjax:start`, `pjax:success`, `pjax:error`, `pjax:complete`, `pjax:render`

### Opts quick reference
Anything accepting `opts` (`Pjax.load`, `Pjax.refresh`, `Pjax.reload`, `Pjax.fetch`) takes the same bag. Most are flags; defaults shown.

| Opt | Type | Default | Meaning |
| --- | --- | --- | --- |
| `path` / `href` | `string` | current `location` | URL or query-only string (`?foo=bar` resolves against current path or `.ajax` container's `data-path`). |
| `target` | `string \| Node` | – | Swap response into this node by `id`. History + scroll auto-disabled. |
| `ajax` | `Node` | – | DOM node inside an `.ajax` region; resolved to nearest `.ajax` ancestor. Set automatically by the click handler. |
| `form` | `HTMLFormElement` | – | Serialize via `FormData` and append to the path. |
| `done` | `function` | – | Callback fired after a successful apply. |
| `scroll` | `bool` | `true` for full swaps | Set `false` to keep current scroll. |
| `history` | `bool` | `true` | Set `false` to skip `pushState`/`replaceState`. |
| `cache` | `bool` | `true` | Set `false` to add `cache-control: no-cache`. |
| `replace` | `bool` | `false` | Use `replaceState` instead of `pushState`. |
| `replacePath` | `string` | – | Alternate URL to push/replace into history. |
| `force` | `bool` | `false` | Skip the 2-second same-href debounce. Set automatically by `refresh` and `reload`. |

Internal/derived (set by the lib, don't pass yourself): `node`, `ajax_node`, `req_start_time`, `path` (after normalization).

Convenience shortcuts when calling:
- Pass a string instead of opts → treated as `target` selector: `Pjax.load('/users', '#list')`
- Pass a function → treated as `done`: `Pjax.load('/users', cb)`
- Pass a DOM node → treated as `ajax`: `Pjax.load('/users', node)`

### Refresh dispatch table
| Call | What happens |
| --- | --- |
| `Pjax.refresh()` | Re-fetch current `path()`, swap the whole pjax container (no scroll change). |
| `Pjax.refresh('#sidebar')` | Re-fetch current path, swap only `#sidebar` from the response. History suppressed. |
| `Pjax.refresh('/users/42')` | Re-fetch the given path, full swap. |
| `Pjax.refresh('/users/42', {target: '#detail'})` | Re-fetch the given path, swap only `#detail`. |
| `Pjax.reload()` | Same path, full swap, `cache-control: no-cache`, scrolls to top. |

All four bypass the 2-second same-href debounce (they set `opts.force = true` internally).

## Testing tips
- Tests re-require `src/pjax.coffee` per test (`delete require.cache[...]`) because the class holds static state.
- `setupGlobals()` resets `document.body` to a known DOM each test.
- `createClickEvent({...})` synthesizes click events with overridable `target`, `which`, `metaKey`.
- Async tests use `(done)` callback with `setTimeout(..., 0)` to flush microtasks.

## Things to NOT do
- Don't reintroduce a hidden `Z` (Zepto-style) dependency for form serialization — use native `FormData`/`URLSearchParams`.
- Don't remove `Pjax.last()`, `Pjax.refreshed()`, `Pjax.pushState()`, or `Pjax.qs()` — all are in use across consuming apps.
- Don't run scripts via `eval` of `script.textContent` directly; use `new Function(...)` so they're at least scoped.
- Don't add `data-*` for new pjax-specific attributes; use the `pjax-*` namespace.
