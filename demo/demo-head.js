// Shared head boilerplate for every demo page.
// Loaded synchronously from <head> via <script src="demo-head.js"> (or
// "demo/demo-head.js" from index.html). document.write keeps the inserted
// scripts in load order so fez.js boots before the <script fez="..."> tags
// are scanned.
//
// Self-adapting deployment root: derive the root prefix from this script's
// own URL so the demo works at "/" (local `npx serve`) and at "/<repo>/"
// (GitHub Pages) without per-page edits. Every asset path written below
// is prefixed with that root, and demo-menu.fez reads the same prefix
// off `window.DEMO_ROOT` for its links.
//
// Why not <base href="..."> ? It looks tempting, but <base> only affects
// DOM-level URL resolution (anchors, XHR). history.pushState resolves
// against the current document URL, ignoring <base> - so clicking
// 'demo/refresh.html' from '/<repo>/demo/load.html' would push
// '/<repo>/demo/demo/refresh.html'. Prefixing absolute paths sidesteps
// that mismatch.
;(function () {
  var src = document.currentScript.src                       // .../demo/demo-head.js
  var root = new URL(src).pathname.replace(/demo\/demo-head\.js$/, '')  // .../  (path only, same-origin)
  window.DEMO_ROOT = root

  document.write(
    '<meta name="viewport" content="width=device-width, initial-scale=1" />' +
    '<link rel="stylesheet" href="' + root + 'demo/styles.css" />' +
    '<script src="https://dux.github.io/fez/dist/fez.js"><\/script>' +
    '<script fez="' + root + 'demo/components/demo-menu.fez"><\/script>' +
    '<script fez="' + root + 'demo/components/demo-api.fez"><\/script>' +
    '<script fez="' + root + 'demo/components/demo-event-log.fez"><\/script>' +
    '<script fez="' + root + 'demo/components/demo-counter.fez"><\/script>' +
    '<script fez="' + root + 'demo/components/demo-confirm.fez"><\/script>' +
    '<script fez="' + root + 'demo/components/random-str.fez"><\/script>' +
    '<script defer src="' + root + 'dist/pjax.global.js"><\/script>' +
    '<script defer src="' + root + 'demo/demo-boot.js"><\/script>'
  )
})()
