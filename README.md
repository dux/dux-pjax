# dux-pjax

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
- **Inline script support** – replays inline `<script>` tags (with optional `delay` attribute for deferred execution) when new markup is inserted.
- **Scroll management** – preserves scroll position for refreshes, enforces top-of-page jumps for reloads, and exposes an opt-in view-transition mode.
- **Form handling** – any `<form data-pjax="true">` (or target selector) automatically uses PJAX instead of a hard submit.

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
| `Pjax.refresh(targetOrPath, opts?)` | Keeps scroll position, skips history changes for selector-based calls, and can refresh `.ajax` regions. |
| `Pjax.reload(opts?)` | Forces a no-cache request and scrolls to the top once content is swapped. |
| `Pjax.onDocumentClick()` | Installs the shared handler that intercepts link clicks. |
| `Pjax.before / Pjax.after` | Lifecycle hooks you can override; return `false` in `before` to cancel navigation. |
| `Pjax.qs(key, value, opts)` | Helper for updating query parameters and optionally pushing a new state. |
| `Pjax.config` | Feature flags for skipping PJAX on certain paths/classes, defining `.ajax` selectors, and scroll suppression classes. |

### Request options
`Pjax.getOpts` understands the following keys:
- `path` / `href` – URL or query string to load (defaults to the current `location`).
- `target` – CSS selector or DOM node to swap in place (history + scroll disabled automatically).
- `ajax` – DOM node inside an `.ajax` container that should receive the response.
- `form` – HTMLFormElement to serialize and append to the request path.
- `done` – callback invoked after HTML is applied.
- `scroll` – set to `false` to keep the current scroll when inserting full-page HTML.
- `history` – set to `false` to avoid pushing browser history entries.
- `cache` – set to `false` to add `cache-control: no-cache` to the request.
- `replacePath` – alternate URL to push to history once loading completes.

### Link attributes
The shared click handler honors a few attributes on `<a>` and `[click]` nodes:
- `data-confirm="Are you sure?"` – prompts before navigating; cancel aborts the click. See [Custom confirm modals](#custom-confirm-modals) below.
- `data-replace` – uses `history.replaceState` instead of `pushState` (no new back-stack entry).
- `hx-target="#selector"` – swaps the response into the selector instead of the main pjax container.
- classes from `Pjax.config.no_pjax_class` (`no-pjax`, `direct` by default) – bypass PJAX entirely.

### Custom confirm modals
By default `data-confirm` calls `window.confirm`. Override `Pjax.confirm` to wire up a custom modal. The hook receives the message and the trigger node, and may return a boolean **or a Promise**:

```javascript
Pjax.confirm = (message, node) => {
  // any data-* on the node is yours to read
  const yes = node.getAttribute('data-yes') || 'Confirm'
  const no  = node.getAttribute('data-no')  || 'Cancel'
  return new Promise(resolve => {
    myModal.show({ message, yes, no, onConfirm: () => resolve(true), onCancel: () => resolve(false) })
  })
}
```

```html
<a href="/users/42" data-method="delete"
   data-confirm="Delete this user?"
   data-yes="Delete" data-no="Keep">Delete</a>
```

When the hook returns a Promise, the click is held; once it resolves, the navigation either proceeds or is dropped silently.

### Lifecycle events
All events bubble from `document`. `pjax:before` is cancellable — call `event.preventDefault()` to abort the navigation.

| Event | When | `event.detail` |
| --- | --- | --- |
| `pjax:before` | After click/form intercept, before XHR fires | `{ href, opts }` |
| `pjax:start` | Right before `XMLHttpRequest.send()` | `{ href, opts }` |
| `pjax:success` | After response applied successfully | `{ href, opts, status }` |
| `pjax:error` | Network error, timeout, non-200, or apply failure | `{ href, opts, reason, status? }` |
| `pjax:complete` | Always, after success or error | `{ href, opts }` |
| `pjax:render` | After DOM swap completes (full or targeted) | – |

### DOM helpers
- `Pjax.parseScripts(htmlOrNode)` replays inline scripts (respecting the `delay` attribute for deferred execution via `requestAnimationFrame`).
- `Pjax.sendGlobalEvent()` emits `pjax:render` on `document` after a successful render.
- `Pjax.emit(name, detail)` dispatches a cancellable `pjax:<name>` event and returns `false` if a listener prevented it.
- The module keeps a small in-memory cache (`Pjax.historyData`) that powers instant back/forward restores.

### Inline script execution order
Inline `<script>` tags inside a response run **before** the new HTML is morphed into the live document. The intent is to let scripts seed globals/state that the rendered markup will then consume on `pjax:render`. Per-DOM wiring (querying or attaching to the freshly inserted nodes) should be done in a `pjax:render` listener, or in a script tagged with `delay="true"` — those run on the next animation frame, after the morph.

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
