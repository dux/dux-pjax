PjaxOnClick =
  main: (event) ->
    # self or scoped href, as on %tr row element.
    # if you do not want parent onclick to trigger when using href, use "click" attribute on parent
    # %tr{ click: ""... }
    #   %td{ href: "/..." }
    if node = event.target.closest('*[click]:not([click=""]), *[href]:not([href=""])')
      event.stopPropagation()
      event.preventDefault()

      if click = node.getAttribute('click')
        (new Function(click)).bind(node)()
      else
        href = node.getAttribute 'href'

        # to make it work on mouse down
        # node.onclick = () => false

        # %a{ href: '...' hx-target: "#some-id" } -> will refresh target element, if one found
        if hxTarget = node.getAttribute('hx-target')
          if hxNode = document.querySelectorAll(hxTarget)[0]
            Pjax.load href, target: hxNode
            return

        if href.slice(0, 2) == '//'
          href = href.replace '/', ''
          return window.open(window.location.origin + href, node.getAttribute('target') || href.replace(/[^\w]/g, ''))

        # if ctrl or cmd button is pressed, open in new window
        if event.which == 2 || event.metaKey
          return window.open href

        # if direct link, do not use Pjax
        klass = ' ' + node.className + ' '
        for el in Pjax.config.no_pjax_class
          if klass.includes(" #{el} ")
            if /^http/.test(href)
              window.open(href)
            else
              return window.location.href = href

        # execute inline JS
        if /^javascript:/.test(href)
          func = new Function href.replace(/^javascript:/, '')
          return func()

        # disable bots
        # return if /bot|googlebot|crawler|spider|robot|crawling/i.test(navigator.userAgent)

        # if target attribute provided, open in new window
        if /^\w/.test(href) || node.getAttribute('target')
          return window.open(href, node.getAttribute('target') || href.replace(/[^\w]/g, ''))

        # if everything else fails, call Pjax
        Pjax.load href, ajax: node

        false

if typeof module != 'undefined' && module.exports
  module.exports = PjaxOnClick
