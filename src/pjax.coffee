# Import the DOM click helper (esbuild resolves require, mocha uses coffeescript/register)
PjaxOnClick = require('./onclick.coffee')

# Pjax will replace only contents of MAIN HTML tag
# HTML <main> Tag
# https://www.w3schools.com/tags/tag_main.asp

# How to use?

# Pjax.load('/some/page', opts)
# Pjax.refresh()
# Pjax.refresh('#some-node')
#   -> node can have data-path="/..." attribute to define custom path (defaults to current location.href)
# Pjax.useViewTransition = true -> use viewTransition if supported

# Pjax.error = (msg) -> Info.error msg
# Pjax.before = ->
#   Dialog.close()
#   InlineDialog.close()
# Pjax.after = ->
#   Dialog.close() if window.Dialog
# Pjax.load('/users/new', no_history: bool, no_scroll: bool, done: ()=>{...})

# to refresh link in container, pass current node and have ajax node ready, with id and path
# .ajax{ id: :foo, path: '/some_dialog_path' }
#   ...
#   .div{ onclick: Pjax.load('?q=search_term', node: this) }

# opts: {
#   path: what path to load
#   replacePath: path to replace path with (on ajax state change, to have back button on different path)
#   done: function to execute on done
#   target: dom node to refresh
#   form: pass form attributes
#   ajax: ajax dom node to refresh, finds closest
#   scroll: set to false if you want to have no scroll (default for Pjax.refresh)
#   history: set to false if you dont want to add state change to history
#   cache: set to false if you want to force no-cache header
# }

class Pjax
  @config = {
    # should Pjax log info to console
    is_silent : parseInt(location.port) < 1000,

    # do not scroll to top, use refresh() and not reload() on node with selectors
    no_scroll_selector : ['.no-scroll'],

    # skip pjax on following links and do location.href = target
    # you can add function, regexp or string (checks for starts with)
    paths_to_skip : [],

    # if link has any of these classes, Pjax will be skipped and link will be followed
    # Example: %a.direct{ href '/somewhere' } somewhere
    no_pjax_class : ['no-pjax', 'direct'],
    no_ajax_class : ['ajax-skip', 'skip-ajax', 'no-ajax', 'top']

    # if parent id found with this class, ajax response data will be loaded in this class
    # you can add ID for better targeting. If no ID given to .ajax class
    #  * if response contains .ajax, first node found will be selected and it innerHTML will be used for replacement
    #  * if there is no .ajax in response, full page response will be used
    # Example: all links in "some_template" will refresh ".ajax" block only
    # .ajax
    #   = render 'some_template'
    ajax_selector  : '.ajax',
  }

  # stores raw HTML responses keyed by path, used for instant back-button navigation
  @historyData = {}

  # you have to call this if you want to capture clicks on document level
  # Example: Pjax.onDocumentClick()
  @onDocumentClick: ->
    unless window.pjaxOnclickBinded
      window.pjaxOnclickBinded = true
      window.addEventListener 'click', PjaxOnClick.main

  # base class method to load page
  # history: bool
  # scroll: bool
  # cache: bool
  # done: ()=>{...}
  @load: (href, opts) ->
    opts = @getOpts href, opts
    @fetch(opts)

  # refresh page, keep scroll
  @refresh: (func, opts) ->
    if typeof func == 'string' && func[0] == '#'
      opts ||= {}
      opts.target = func
      func = Pjax.path()
      # opts.href = Pjax.lastHref # if we want to refresh inline dialogs, s-ajax will set Pjax.lastHref and this will work
      opts.history = false

    opts = @getOpts func, opts
    opts.scroll ||= false
    # opts.cache ||= false

    @fetch(opts)

  # reload, jump to top, no_cache http request forced
  @reload: (opts) ->
    opts = @getOpts opts
    opts.cache ||= false
    @fetch(opts)

  # returns true if the last two navigations were to the same URL (page was refreshed, not changed)
  @refreshed: ->
    return false unless @pastHref
    @pastHref == @lastHref

  # normalize options
  @getOpts = (path, opts) ->
    opts ||= {}

    if typeof(path) == 'object'
      if path.nodeName
        opts.ajax = path
      else
        opts = path
    else if typeof(path) == 'function'
      opts.done = path
    else
      opts.path = path

    if opts.href
      opts.path = opts.href
      delete opts.href

    opts.path ||= @path()

    if opts.form
      for key, value of Z(opts.form).serializeHash()
        opts.path += if opts.path.includes('?') then '&' else '?'
        opts.path += "#{key}=#{encodeURIComponent(value)}"

    if opts.ajax
      opts.node = opts.ajax
      opts.node = document.querySelector(opts.node) if typeof opts.node == 'string'

      skip_ajax = false
      for el in @config.no_ajax_class
        skip_ajax = true if opts.ajax.closest(".#{el}")

      unless skip_ajax
        if ajax_node = opts.node.closest(Pjax.config.ajax_selector)
          opts.ajax_node = ajax_node
          opts.scroll ||= false

      delete opts.ajax

    if opts.target
      if typeof opts.target == 'string'
        opts.target = document.querySelector(opts.target)
      opts.node = opts.target
      opts.scroll ||= false

    if opts.path[0] == '?'
      # if href starts with ?
      if opts.ajax_node
        # and we are in ajax node
        ajax_path = opts.ajax_node.getAttribute('data-path') || opts.ajax_node.getAttribute('path')

        if ajax_path
          # and ajax path is defined, use it to create full url
          opts.path = ajax_path.split('?')[0] + opts.path

      if opts.path[0] == '?'
        # if not modified, use base url
        opts.path = location.pathname + opts.path

    if opts.replacePath
      if opts.replacePath[0] == '?'
        opts.replacePath = location.pathname + opts.replacePath

    opts

  # creates a new Pjax instance with normalized opts and starts the XHR load
  @fetch: (opts) ->
    pjax = new Pjax(opts)
    pjax.load()

  # used to get full page path
  @path: ->
    location.pathname+location.search

  # finds the main pjax container DOM node (<pjax> tag or .pjax class)
  # this is the element whose innerHTML gets replaced on navigation
  @node: ->
    el = document.getElementsByTagName('pjax')[0] || document.getElementsByClassName('pjax')[0] || alert('.pjax or #pjax not found')
    alert 'You cant bind PJAX to body' if el.nodeName == 'BODY'
    el

  # debug logger - only outputs when not in silent mode (non-production ports)
  @console: (msg) ->
    unless @config.is_silent
      console.log msg

  # execute action before pjax load and do not proceed if return is false
  # example, load dialog links inside the dialog
  # Pjax.before = (href, opts) ->
  #   if opts.node
  #     if opts.node.closest('.in-popup')
  #       Dialog.load href
  #       return false
  #   true
  @before: () ->
    true

  # execute action after pjax load
  @after: () ->
    true

  # error logger, replace as fitting
  @error: (msg) ->
    console.error "Pjax error: #{msg}"

  # executes a single inline script by id, then marks it as executed (text=1)
  # img param is a trigger element (e.g. tracking pixel) that gets removed after firing
  @parseSingleScript: (id, img) ->
    img.remove()
    if node = document.getElementById(id)
      func = new Function node.innerText
      func()
      node.text = 1

  # finds and executes all inline <script> tags inside node (string or DOM element)
  # skips external scripts (with src attribute) and non-javascript types
  # scripts with 'delay' attribute are deferred via requestAnimationFrame
  # returns the processed innerHTML
  @parseScripts: (node) ->
    # wrap string HTML in a temporary div so we can query it
    if typeof node == 'string'
      duplicate = node
      node = document.createElement "div"
      node.innerHTML = duplicate

    for script_tag in node.getElementsByTagName('script')
      if script_tag
        unless script_tag.getAttribute('src')
          type = script_tag.getAttribute('type') || 'javascript'

          if type.indexOf('javascript') > -1
            unless script_tag.id
              @script_cnt ||= 0
              script_tag.id = "app-sc-#{++@script_cnt}"

            # never remove this, must no be requestAnimationFrame by default
            # why? if you set window.app.user = {...} you want nodes inserted that are fast rendered, to have this info
            func = new Function(script_tag.textContent)
            script_tag.text = 1
            if script_tag.getAttribute('delay')
              requestAnimationFrame(func)
            else
              func()

    node.innerHTML

  # internal
  @noScrollCheck: (node) ->
    return unless node && node.closest

    for el in @config.no_scroll_selector
      return true if node.closest(el)

    false

  # returns the last loaded href, or the current path if no navigation happened yet
  @last: ->
    @lastHref || @path()

  # dispatches 'pjax:render' custom event on document so other code can react to page changes
  @sendGlobalEvent: ->
    document.dispatchEvent new CustomEvent('pjax:render')

  # push a new entry to browser history without triggering navigation
  @pushState: (href) ->
    window.history.pushState({}, document.title, href);

  # alias for pushState
  @push: (href) -> @pushState(href)

  # locks page scrolling to prevent jump to top of the page on refresh
  @scrollLock: ->
    now = Date.now()
    return if @_scrollLockTime && now - @_scrollLockTime < 1000
    @_scrollLockTime = now

    scrollPosition = window.scrollY
    body = document.body
    body.style.height = window.getComputedStyle(body).height
    window.scrollTo(0, scrollPosition) # Forces exact position

    window.requestAnimationFrame =>
      body.style.height = ''
      window.scrollTo(0, scrollPosition) # Forces exact position again

  # prevent page flicker on refresh by fixing main node height
  # replaces pjax container innerHTML with new content, updates document title,
  # executes inline scripts, fires after() hook and 'pjax:render' event
  # supports View Transitions API when Pjax.useViewTransition is set
  @setPageBody: (node, href) ->
    title = node.querySelector('title')?.innerHTML
    document.title = title || 'no page title (pjax)'
    Pjax.scrollLock()
    pjaxNode = Pjax.node()
    if new_body = node.querySelector('#' + pjaxNode.id)
      if Pjax.useViewTransition && document.startViewTransition
        document.startViewTransition () =>
          pjaxNode.innerHTML = Pjax.parseScripts(new_body)
      else
        pjaxNode.innerHTML = Pjax.parseScripts(new_body)

      Pjax.after(href, @opts)
      Pjax.sendGlobalEvent()

  # gets or sets a querystring parameter and optionally triggers navigation
  # getter: Pjax.qs('place') -> returns current value of ?place=...
  # setter: Pjax.qs('place', 'ny') -> sets ?place=ny and triggers Pjax.load
  # Pjax.qs('place', el.name, { push: true })
  # opts.push  - push to history without pjax load
  # opts.mock  - push only, skip Pjax.push (for testing)
  # opts.href  - return the new URL string instead of navigating
  @qs: (key, value, opts = {}) ->
    # parse current querystring into [key, value] pairs
    parts = location.search.replace(/^\?/, '').split('&').map (el) -> el.split('=', 2)

    if typeof value == 'undefined'
      # getter mode - find and return the value for the given key
      parts.forEach (el) ->
        value = decodeURIComponent(el[1]) if el[0] == key
      value
    else
      # setter mode - rebuild querystring with updated key
      qs = {}
      parts.forEach (el) ->
        qs[el[0]] = el[1] if el[0]

      qs[key] = encodeURIComponent value
      data = Object.keys(qs).map((key)=> "#{key}=#{qs[key]}").join('&')
      href = location.pathname + '?' + data

      if opts.push
        Pjax.push href unless opts.mock
      else if opts.href
        href
      else
        Pjax.load href

  # --- instance methods ---

  # initialize with normalized options, extract the target href
  constructor: (@opts) ->
    @href = @opts.href || @opts.path

  # fallback navigation - opens foreign URLs in new window, same-origin URLs via full page load
  redirect: ->
    @href ||= location.href

    if @href.slice(0, 4) == 'http' && !@href.includes(location.host)
      # if page is on a foreign server, open it in new window
      window.open @href
    else
      location.href = @href

    false

  # main instance method - performs XHR GET to @href, handles:
  # - cmd/ctrl+click -> open in new tab
  # - before() hook -> can cancel navigation
  # - hash-only links -> smooth scroll to anchor
  # - external/hash/disabled links -> redirect() fallback
  # - paths_to_skip config -> redirect() fallback
  # - aborts any in-flight pjax request before starting new one
  # - on success: injects response via applyLoadedData(), scrolls to top
  # - on non-200: falls back to redirect()
  load: ->
    return false unless @href

    # if Pjax.lastHref == @href && Pjax.lastTime && (new Date() - 1000) > Pjax.lastTime
    #   LOG 'skipped'
    #   return
    # else if Pjax.lastTime
    #   console.log Pjax.lastHref == @href, (new Date() - 1000) > Pjax.lastTime
    # else
    #   console.log 'lt', Pjax.lastTime

    # Pjax.lastTime = new Date()
    Pjax.pastHref = Pjax.lastHref
    Pjax.lastHref = @href

    # if ctrl or cmd button is pressed, open in new window
    if event && !event.key && (event.which == 2 || event.metaKey)
      return window.open @href

    if Pjax.before(@href, @opts) == false
      return

    if (location.hash && location.pathname == @href)
      return

    # handle %a{ href: '#top' } go to top
    if @href.startsWith('#')
      return if @href == '#'
      if node = document.querySelector("a[name=#{@href.replace('#', '')}]")
        node.scrollIntoView({behavior: 'smooth', block: 'start'});
        return false

    if /^http/.test(@href) || /#/.test(@href) || @is_disabled
      return @redirect()

    for el in Pjax.config.paths_to_skip
      switch typeof el
        when 'object' then return @redirect() if el.test(@href)
        when 'function' then return @redirect() if el(@href)
        else return @redirect() if @href.startsWith(el)

    @opts.req_start_time = Date.now()
    @opts.path = @href

    headers = {}
    headers['cache-control'] = 'no-cache' if @opts.cache == false
    headers['x-requested-with'] = 'XMLHttpRequest'

    if Pjax.request
      Pjax.request.abort()

    Pjax.request = @req = new XMLHttpRequest()

    @req.onerror = (e) ->
      Pjax.error 'Net error: Server response not received (Pjax)'
      console.error(e)

    @req.open('GET', @href)
    @req.setRequestHeader k, v for k,v of headers

    @req.onload = (e) =>
      Pjax.request = null
      @response  = @req.responseText

      # console log
      time_diff = Date.now() - @opts.req_start_time
      log_data  = "Pjax.load #{@href}"
      log_data += if @opts.history == false then ' (back trigger)' else ''
      Pjax.console "#{log_data} (app #{@req.getResponseHeader('x-lux-speed') || 'n/a'}, real #{time_diff}ms, status #{@req.status})"

      # if not 200, redirect to page to show the error
      if @req.status != 200
        @redirect()
      else
        # fix href because of redirects - extract pathname + search from response URL
        if rul = @req.responseURL
          parsed = new URL(rul)
          @href = parsed.pathname + parsed.search

        # inject response in current page and process if ok
        if @applyLoadedData()
          # trigger opts['done'] function
          @opts.done() if typeof(@opts.done) == 'function'

          # scroll to top of the page unless defined otherwise
          unless @opts.scroll == false || Pjax.noScrollCheck(@opts.node)
            window.requestAnimationFrame ->
              window.scrollTo({ top: 0, left: 0, behavior: 'smooth' })
          else
            Pjax.scrollLock()
        else
          # document.write @response is buggy and unsafe
          # do full reload
          @redirect()

    @req.send()

    false

  # injects the XHR response HTML into the page
  # handles three modes:
  #   1. opts.target - replace a specific DOM element by id match in response
  #   2. opts.ajax_node - replace the closest .ajax container with matching response fragment
  #   3. default - full pjax swap via setPageBody (replace main container, update title, run scripts)
  # returns true on success, falsy on failure (triggers redirect fallback)
  applyLoadedData: ->
    @pjaxNode = Pjax.node()

    unless @pjaxNode
      Pjax.error 'template_id mismatch, full page load (use no-pjax as a class name)'
      return

    unless @pjaxNode.id
      alert 'No ID attribute on pjax node'
      return

    @historyAddCurrent(@opts.replacePath || @href)

    # parse response into a temporary DOM tree for querying
    @rroot = document.createElement('div')
    @rroot.innerHTML = @response

    # mode 1: targeted element refresh - find matching element by id in response
    if @opts.target
      if id = @opts.target.getAttribute('id')
        rtarget = @rroot.querySelector('#'+id)
        if rtarget
          Pjax.scrollLock()
          @opts.target.innerHTML = Pjax.parseScripts(rtarget.innerHTML)
          return true
      else
        alert('ID attribute not found on Pjax target')

    # mode 2: ajax container refresh - update .ajax block with matching fragment from response
    if ajax_node = @opts.ajax_node
      ajax_node.setAttribute('data-path', @href)
      ajax_node.removeAttribute('path')
      ajax_id = ajax_node.getAttribute('id') || alert('Pjax .ajax node has no ID')
      ajax_data = @rroot.querySelector('#'+ajax_id)?.innerHTML || @response
      ajax_node.innerHTML = Pjax.parseScripts(ajax_data)
      return true

    # mode 3: full page swap - store response for back-button cache, replace main container
    Pjax.historyData[Pjax.path()] = @response

    Pjax.setPageBody(@rroot, @href)

  # private

  # add current page to history
  historyAddCurrent: (href) ->
    return if @opts.history == false || (@opts.ajax_node && ! @opts.target)
    return if @history_added; @history_added = true

    if Pjax._lastHrefCheck == href
      window.history.replaceState({}, document.title, href);
    else
      window.history.pushState({}, document.title, href)
      Pjax._lastHrefCheck = href

# --- window-level event handlers ---

# handle back button gracefully
# tries cached response from historyData first for instant restore,
# falls back to pjax load without adding a new history entry
window.onpopstate = (event) ->
  window.requestAnimationFrame ->
    path = Pjax.path()
    if hdata = Pjax.historyData[path]
      console.log "from history: #{path}"
      rroot = document.createElement('div')
      rroot.innerHTML = hdata
      Pjax.setPageBody(rroot, path)
    else
      Pjax.load path, history: false

# on page ready: fire initial pjax:render event and bind form submission handler
window.addEventListener 'DOMContentLoaded', () ->
  setTimeout(Pjax.sendGlobalEvent, 0)

  # forms with data-pjax attribute are submitted via pjax instead of full page post
  # <form action="/search" data-pjax="true"> -> refresh full page
  # <form action="/search" data-pjax="#search"> -> refresh search block only
  document.body.addEventListener 'submit', (e) ->
    form = e.target
    if is_pjax = form.getAttribute('data-pjax')
      e.preventDefault()
      pjax_target = if is_pjax == 'true' then null else is_pjax
      Pjax.load form.getAttribute('action'), form: form, target: pjax_target

# --- exports ---

# CommonJS export for bundlers
if typeof module != 'undefined' && module.exports
  module.exports = Pjax

# global export for script tag usage
window.Pjax = Pjax
