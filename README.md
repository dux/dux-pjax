# dux-pjax

**Live demo:** [dux.github.io/dux-pjax/](https://dux.github.io/dux-pjax/)

`dux-pjax` is a lightweight PJAX helper. PJAX (PushState + AJAX) renders a new HTML response into the current page instead of performing a hard navigation. You preserve browser history, avoid expensive asset reloads, and keep any UI state that lives outside the refreshed container. This package focuses on the common pattern of replacing your `<main>` (or any container you choose) with the server-rendered markup coming from a standard controller action.

At a glance:

```javascript
import Pjax from 'dux-pjax'

Pjax.onDocumentClick() // hijack eligible links once

// Rendered page contains:
// <main id="pjax" class="pjax"> ... </main>

// Navigate without a full reload
Pjax.load('/users')

// Later, refresh part of the page in place
Pjax.refresh('#sidebar')
```

The helper takes care of issuing the XMLHttpRequest, parsing inline scripts, dispatching `pjax:render`, scrolling when appropriate, and keeping the browser history stack in sync.

## Features
- **Drop-in navigation** – call `Pjax.onDocumentClick()` once to hijack every link that should stay on the current page.
- **Scoped refreshes** – target a specific DOM node via `Pjax.refresh('#sidebar')` or rely on `.ajax` regions for dialog/content updates.
- **History-aware** – integrates with `window.history`, dispatches `pjax:render`, and caches responses for fast back-button support.
- **Inline script support** – replays inline `<script>` tags (tag with `pjax-delay` to defer until after the DOM swap) when new markup is inserted.
- **Scroll management** – preserves scroll position for refreshes, enforces top-of-page jumps for reloads, and exposes an opt-in view-transition mode.
- **Form handling** – any `<form data-pjax="true">` (full swap) or `<form data-pjax="#selector">` (targeted swap) automatically uses PJAX instead of a hard submit.

## Installation
```bash
npm install dux-pjax
```

## Usage options

### 1. Bundler / module import
```javascript
import Pjax from 'dux-pjax'
// or just: import 'dux-pjax' // attaches window.Pjax as a side effect

Pjax.onDocumentClick()
```

The default export is the `Pjax` class. When the module runs in a browser it automatically assigns `window.Pjax`, so legacy code that expects the global still works without extra glue.

### 2. Direct `<script>` tag
The build also ships an immediately-invoked bundle for browser-only projects:

```html
<script src="/node_modules/dux-pjax/dist/pjax.global.js" defer></script>
<!-- Once loaded, window.Pjax is ready -->
<script defer src="/demo/demo.js"></script>
```

Host `dist/pjax.global.js` from your CDN or copy it into your public assets folder. This build exposes the same API via the `Pjax` global without requiring a bundler.

## Getting started
```javascript
import Pjax from 'dux-pjax'

// Attach a single document click handler (usually once, on boot)
Pjax.onDocumentClick()

// Initial page load already rendered <main id="pjax"> ... </main>
// Trigger a navigation without full reload
Pjax.load('/users')
```
Minimal DOM expectations:
```html
<main id="pjax" class="pjax">
  <!-- the portion of the page PJAX will keep replacing -->
</main>
```
You can also scope reloads:
```javascript
// Refresh a panel in-place and skip history/scroll changes
Pjax.refresh('#filters')

// Force a full reload while busting the HTTP cache
Pjax.reload()
```

## API highlights
| Method | Description |
| --- | --- |
| `Pjax.load(pathOrOpts, opts?)` | Normalizes the arguments via `getOpts` and performs an XMLHttpRequest. |
| `Pjax.refresh(targetOrPath, opts?)` | Keeps scroll position, skips history changes for selector-based calls, and can refresh `.ajax` regions. Bypasses the same-href debounce. |
| `Pjax.reload(opts?)` | Forces a no-cache request and scrolls to the top once content is swapped. Bypasses the same-href debounce. |
| `Pjax.onDocumentClick()` | Installs the shared handler that intercepts link clicks. Idempotent. |
| `Pjax.before(href, opts) / Pjax.after(href)` | Lifecycle hooks you can override; return `false` in `before` to cancel navigation. |
| `Pjax.confirm(message, node)` | Hook for `pjax-confirm`; default delegates to `window.confirm`. May return a boolean or a Promise. |
| `Pjax.path()` | Current `location.pathname + location.search`. |
| `Pjax.last()` | The last href PJAX navigated to, or `Pjax.path()` if none. |
| `Pjax.refreshed()` | True iff the last two navigations targeted the same href (useful for skipping entrance animations on refresh). |
| `Pjax.pushState(href)` / `Pjax.replace(href)` | Thin shortcuts over `history.pushState` / `replaceState` that auto-fill `document.title`. `Pjax.push` is an alias of `pushState`. |
| `Pjax.qs(key, value, opts)` | Get/set query parameters; setter triggers `Pjax.load` by default, or `pushState` (with `{push: true}`), or returns the URL string (with `{href: true}`). |
| `Pjax.emit(name, detail)` | Dispatches a cancellable `pjax:<name>` event; returns `false` if a listener prevented it. |
| `Pjax.parseScripts(htmlOrNode)` | Replays inline `<script>` tags (respects `pjax-delay`). |
| `Pjax.sendGlobalEvent()` | Dispatches `pjax:render` on `document`. |
| `Pjax.config` | Feature flags for skipping PJAX on certain paths/classes, defining `.ajax` selectors, and scroll suppression classes (see [Configuration](#configuration)). |

### Request options
Anything accepting `opts` (`Pjax.load`, `Pjax.refresh`, `Pjax.reload`) takes the same bag.

| Opt | Type | Default | Meaning |
| --- | --- | --- | --- |
| `path` / `href` | `string` | current `location` | URL or query-only string (`?foo=bar` resolves against current path or `.ajax` container's `data-path`). |
| `target` | `string \| Node` | – | Swap response into this node by `id`. History + scroll auto-disabled. |
| `ajax` | `Node` | – | DOM node inside an `.ajax` region; resolved to nearest `.ajax` ancestor. Set automatically by the click handler. |
| `form` | `HTMLFormElement` | – | Serialize via native `FormData` and append to the path. |
| `done` | `function` | – | Callback fired after a successful apply. |
| `scroll` | `bool` | `true` for full swaps | Set `false` to keep current scroll. |
| `history` | `bool` | `true` | Set `false` to skip `pushState`/`replaceState`. |
| `cache` | `bool` | `true` | Set `false` to add `cache-control: no-cache`. |
| `replace` | `bool` | `false` | Use `replaceState` instead of `pushState`. |
| `replacePath` | `string` | – | Alternate URL to push/replace into history. |
| `force` | `bool` | `false` | Skip the 2-second same-href debounce. Set automatically by `refresh` and `reload`. |

Convenience shortcuts when calling:
- Pass a string instead of opts → treated as `target` selector: `Pjax.load('/users', '#list')`
- Pass a function → treated as `done`: `Pjax.load('/users', cb)`
- Pass a DOM node → treated as `ajax`: `Pjax.load('/users', node)`

### Configuration
| Key | Default | Purpose |
| --- | --- | --- |
| `Pjax.config.is_silent` | `true` on standard ports, `false` on dev ports (≥ 1000) | Suppresses `Pjax.console` logs in production. |
| `Pjax.config.timeout` | `10000` | XHR timeout in ms. |
| `Pjax.config.history_max` | `20` | Max in-memory cached responses for back/forward. |
| `Pjax.config.ajax_selector` | `'.ajax'` | Selector for in-place region swaps. |
| `Pjax.config.no_pjax_class` | `['no-pjax', 'direct']` | Classes that bypass PJAX entirely. |
| `Pjax.config.no_ajax_class` | `['ajax-skip', 'skip-ajax', 'no-ajax', 'top']` | Classes that opt out of `.ajax` region matching. |
| `Pjax.config.no_scroll_selector` | `['.no-scroll']` | Selectors whose ancestors suppress scroll-to-top. |
| `Pjax.config.paths_to_skip` | `[]` | Strings/regexes/functions that force a hard navigation. |
| `Pjax.DEV` | `undefined` | Set to `true` to force-enable verbose logging regardless of `is_silent`. |
| `Pjax.useViewTransition` | `undefined` | Set to `true` to wrap full-page swaps in `document.startViewTransition` when available. |

### Link attributes
All pjax-specific attributes live under the `pjax-*` namespace. The shared click handler honors:
- `pjax-confirm="Are you sure?"` – prompts before navigating; cancel aborts the click. See [Custom confirm modals](#custom-confirm-modals) below.
- `pjax-replace` – uses `history.replaceState` instead of `pushState` (no new back-stack entry).
- `pjax-target="#selector"` – swaps the response into the selector instead of the main pjax container. If the selector matches nothing the click is aborted with an error.
- `click="…"` – inline JS run on click (instead of navigating). Bound to the element as `this`. Bypasses CSP only when `'unsafe-eval'` is allowed; prefer `addEventListener` in CSP-strict apps.
- classes from `Pjax.config.no_pjax_class` (`no-pjax`, `direct` by default) – bypass PJAX entirely.

### DOM container
The PJAX swap target is the first matching `<pjax>` tag, falling back to the first `.pjax` class. The element must have an `id`:

```html
<main id="pjax" class="pjax">…</main>
<!-- or -->
<pjax id="pjax">…</pjax>
```

The container's `id` is also what the response HTML must match — `setPageBody` queries the response for `#<pjaxNode.id>` and morphs that subtree in.

### Custom confirm modals
By default `pjax-confirm` calls `window.confirm`. Override `Pjax.confirm` to wire up a custom modal. The hook receives the message and the trigger node, and may return a boolean **or a Promise**:

```javascript
Pjax.confirm = (message, node) => {
  // any attribute on the node is yours to read
  const yes = node.getAttribute('pjax-yes') || 'Confirm'
  const no  = node.getAttribute('pjax-no')  || 'Cancel'
  return new Promise(resolve => {
    myModal.show({ message, yes, no, onConfirm: () => resolve(true), onCancel: () => resolve(false) })
  })
}
```

```html
<a href="/users/42"
   pjax-confirm="Delete this user?"
   pjax-yes="Delete" pjax-no="Keep">Delete</a>
```

When the hook returns a Promise, the click is held; once it resolves, the navigation either proceeds or is dropped silently.

### Lifecycle events
Two events bubble from `document`:

- **`pjax:start`** — fires right before `XMLHttpRequest.send()`. Useful for showing a top progress bar / spinner.
- **`pjax:render`** — fires once per navigation, after the response has been applied (or after the request failed). Useful for analytics, focus management, post-render bootstrapping.

`event.detail` shape:

| Field | When | Type | Description |
| --- | --- | --- | --- |
| `from` | both | `string \| null` | Previous path; `null` on initial load. |
| `to` | both | `string` | The path being navigated to. |
| `mode` | both | `string` | `'full'`, `'target'`, or `'ajax'` — which swap path is being used. |
| `opts` | both | `object` | The original options bag the navigation was started with. |
| `status` | render only | `number` | HTTP status code, or `0` for network/timeout errors. |
| `error` | render only | `string \| null` | `null` on success; `'network'`, `'timeout'`, `'status'`, or `'apply'` on failure. |
| `duration` | render only | `number` | Wall-clock ms from request start to render. |

```js
document.addEventListener('pjax:start', (e) => {
  showSpinner(e.detail.to)
})

document.addEventListener('pjax:render', (e) => {
  hideSpinner()
  const { status, error, to, mode, duration } = e.detail
  if (error) console.warn('navigation failed:', error, status, to)
  else       console.log('rendered', to, 'in', duration, 'ms')
})
```

To **cancel** a navigation before it starts, override `Pjax.before(href, opts)` and return `false` (see the API table above). Cancelled navigations fire neither `pjax:start` nor `pjax:render`.

### DOM helpers
- `Pjax.parseScripts(htmlOrNode)` replays inline scripts (respecting the `pjax-delay` attribute for deferred execution via `requestAnimationFrame`).
- `Pjax.sendGlobalEvent()` emits `pjax:render` with default detail (used internally for the initial page load).
- `Pjax.emit(name, detail)` dispatches a cancellable custom `pjax:<name>` event and returns `false` if a listener called `preventDefault()`. Useful for app-level events; the lib itself only emits `pjax:render`.
- The module keeps a small in-memory cache (`Pjax.historyData`) that powers instant back/forward restores.

### Inline script execution order
Inline `<script>` tags inside a response run **after** history has been committed, but **before** the new HTML is morphed into the live document. That means scripts can read the new `location.pathname + location.search` while still seeding globals/state that the rendered markup will consume on `pjax:render`. Per-DOM wiring (querying or attaching to the freshly inserted nodes) should be done in a `pjax:render` listener, or in a script tagged with `pjax-delay` — those run on the next animation frame, after the morph.

## Development
```bash
# Install dependencies
npm install

# One-off compile to dist/
npm run build

# Rebuild on change (ESM, CJS, global bundles)
npm run dev

# Run the mocha/jsdom suite
npm test

# Launch the browser demo
npm run demo
```
Tests live in `test/pjax.test.coffee` and cover module exports, option normalization, targeted refreshes, load/reload behavior, script parsing, lifecycle hooks, history management, and DOM updates.

## Project status
- **Language**: CoffeeScript (compiled to JavaScript via esbuild)
- **Entry points**: `dist/index.js` (ESM), `dist/index.cjs` (CJS), `dist/pjax.global.js` (browser global)
- **License**: MIT

Feel free to open issues or PRs if you need additional hooks or improvements.
