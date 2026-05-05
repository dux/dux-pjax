PjaxOnClick =
  main: (event) ->
    node = event.target.closest('*[click]:not([click=""]), *[href]:not([href=""])')
    return unless node

    event.stopPropagation()
    event.preventDefault()

    # Snapshot the parts of the event we need; the post-confirm path may run
    # on a future tick (custom modal returning a Promise) when the original
    # MouseEvent is no longer trustworthy.
    ctx =
      node: node
      which: event.which
      metaKey: event.metaKey

    proceed = -> PjaxOnClick.execute(ctx)

    if confirmMsg = node.getAttribute('data-confirm')
      result = Pjax.confirm(confirmMsg, node)
      if result and typeof result.then == 'function'
        result.then (ok) -> proceed() if ok
        return
      return unless result

    proceed()

  execute: (ctx) ->
    node = ctx.node

    if click = node.getAttribute('click')
      return (new Function(click)).bind(node)()

    href = node.getAttribute 'href'
    replace = node.hasAttribute('data-replace')

    if hxTarget = node.getAttribute('hx-target')
      if hxNode = document.querySelector(hxTarget)
        Pjax.load href, target: hxNode, replace: replace
        return

    if href.slice(0, 2) == '//'
      href = href.replace '/', ''
      return window.open(window.location.origin + href, node.getAttribute('target') || href.replace(/[^\w]/g, ''))

    if ctx.which == 2 || ctx.metaKey
      return window.open href

    for el in Pjax.config.no_pjax_class
      if node.classList.contains(el)
        return if /^http/.test(href) then window.open(href) else window.location.href = href

    if /^javascript:/.test(href)
      return (new Function href.replace(/^javascript:/, ''))()

    if /^\w+:/.test(href) || node.getAttribute('target')
      return window.location.href = href if /^vscode:/.test(href)
      return window.open(href, node.getAttribute('target') || href.replace(/[^\w]/g, ''))

    Pjax.load href, ajax: node, replace: replace
    false

if typeof module != 'undefined' && module.exports
  module.exports = PjaxOnClick
