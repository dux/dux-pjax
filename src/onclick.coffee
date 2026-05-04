PjaxOnClick =
  main: (event) ->
    node = event.target.closest('*[click]:not([click=""]), *[href]:not([href=""])')
    return unless node

    event.stopPropagation()
    event.preventDefault()

    if click = node.getAttribute('click')
      return (new Function(click)).bind(node)()

    href = node.getAttribute 'href'

    if hxTarget = node.getAttribute('hx-target')
      if hxNode = document.querySelector(hxTarget)
        Pjax.load href, target: hxNode
        return

    if href.slice(0, 2) == '//'
      href = href.replace '/', ''
      return window.open(window.location.origin + href, node.getAttribute('target') || href.replace(/[^\w]/g, ''))

    if event.which == 2 || event.metaKey
      return window.open href

    for el in Pjax.config.no_pjax_class
      if node.classList.contains(el)
        return if /^http/.test(href) then window.open(href) else window.location.href = href

    if /^javascript:/.test(href)
      return (new Function href.replace(/^javascript:/, ''))()

    if /^\w/.test(href) || node.getAttribute('target')
      return window.location.href = href if /^vscode:/.test(href)
      return window.open(href, node.getAttribute('target') || href.replace(/[^\w]/g, ''))

    Pjax.load href, ajax: node
    false

if typeof module != 'undefined' && module.exports
  module.exports = PjaxOnClick
