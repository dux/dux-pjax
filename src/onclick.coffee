PjaxOnClick =
  main: (event) ->
    node = event.target.closest('*[click]:not([click=""]), *[href]:not([href=""]), *[pjax-refresh]:not([pjax-refresh=""])')
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

    if confirmMsg = node.getAttribute('pjax-confirm')
      result = Pjax.confirm(confirmMsg, node)
      if result and typeof result.then == 'function'
        result
          .then((ok) -> proceed() if ok)
          .catch (err) -> Pjax.error "confirm rejected: #{err}"
        return
      return unless result

    proceed()

  execute: (ctx) ->
    node = ctx.node

    if click = node.getAttribute('click')
      return (new Function(click)).bind(node)()

    href = node.getAttribute 'href'
    replace = node.hasAttribute('pjax-replace')

    if pjaxRefresh = node.getAttribute('pjax-refresh')
      targetNode = document.querySelector(pjaxRefresh)
      unless targetNode
        Pjax.error "pjax-refresh selector did not match: #{pjaxRefresh}"
        return
      Pjax.refresh pjaxRefresh
      return

    if pjaxTarget = node.getAttribute('pjax-target')
      targetNode = document.querySelector(pjaxTarget)
      unless targetNode
        Pjax.error "pjax-target selector did not match: #{pjaxTarget}"
        return
      Pjax.load href, target: targetNode, replace: replace
      return

    # middle-click / cmd-click is a user gesture to open a new tab, regardless
    # of the link's own target.
    if ctx.which == 2 || ctx.metaKey
      return window.open href

    target = node.getAttribute('target')

    # Opt out of pjax when the link, or any ancestor, carries a no-pjax class
    # (e.g. `direct`, `no-pjax`). closest() walks up the tree so a wrapper opting
    # out covers everything inside it.
    noPjaxSel = (".#{cls}" for cls in Pjax.config.no_pjax_class).join(', ')
    if noPjaxSel and node.closest(noPjaxSel)
      return PjaxOnClick.leave(href, target)

    if /^javascript:/.test(href)
      return (new Function href.replace(/^javascript:/, ''))()

    # Scheme links (mailto:, tel:, external http, vscode:) or links asking for a
    # named target leave pjax too.
    if /^\w+:/.test(href) || target
      return PjaxOnClick.leave(href, target)

    Pjax.load href, ajax: node, replace: replace
    false

  # Leave the SPA. Open a new window only when the link declares a `target`;
  # otherwise navigate the current tab. Kept as a seam so tests can stub it -
  # jsdom forbids assigning window.location.
  leave: (href, target) ->
    if target then window.open(href, target) else window.location.href = href

if typeof module != 'undefined' && module.exports
  module.exports = PjaxOnClick
