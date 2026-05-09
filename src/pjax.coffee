PjaxOnClick = require('./onclick.coffee')

class Pjax
  @config =
    is_silent: !location.port || parseInt(location.port) < 1000
    no_scroll_selector: ['.no-scroll']
    paths_to_skip: []
    no_pjax_class: ['no-pjax', 'direct']
    no_ajax_class: ['ajax-skip', 'skip-ajax', 'no-ajax', 'top']
    ajax_selector: '.ajax'
    timeout: 10000
    history_max: 20

  @historyData = {}

  # --- public class methods ---

  @onDocumentClick: ->
    unless @_clickBound
      @_clickBound = true
      window.addEventListener 'click', PjaxOnClick.main

  @load: (href, opts) ->
    @fetch @getOpts(href, opts)

  @refresh: (func, opts) ->
    if typeof func == 'string' && func[0] == '#'
      opts ||= {}
      opts.target = func
      func = @path()
      opts.history = false

    opts = @getOpts func, opts
    opts.scroll ||= false
    opts.force = true
    @fetch opts

  @reload: (opts) ->
    opts = @getOpts opts
    opts.cache = false
    opts.force = true
    @fetch opts

  @refreshed: ->
    return false unless @pastHref
    @pastHref == @lastHref

  @path: ->
    location.pathname + location.search

  @last: ->
    @lastHref || @path()

  @node: ->
    el = document.getElementsByTagName('pjax')[0] || document.getElementsByClassName('pjax')[0]
    unless el
      @error '.pjax or <pjax> not found'
      return
    if el.nodeName == 'BODY'
      @error 'You cant bind PJAX to body'
      return
    el

  @console: (msg) ->
    console.log msg if @DEV || !@config.is_silent

  @before: -> true
  @after: -> true
  @confirm: (message, node) -> window.confirm(message)

  @error: (msg) ->
    console.error "Pjax error: #{msg}"

  @pushState: (href) ->
    window.history.pushState {}, document.title, href

  @push: (href) -> @pushState href

  @replace: (href) ->
    window.history.replaceState {}, document.title, href

  @sendGlobalEvent: ->
    Pjax._dispatchRender
      from:     null
      to:       Pjax.path()
      status:   200
      error:    null
      duration: 0
      mode:     'full'
      opts:     {}

  @_dispatchRender: (detail) ->
    document.dispatchEvent new CustomEvent('pjax:render', bubbles: true, detail: detail)

  @emit: (name, detail) ->
    event = new CustomEvent("pjax:#{name}", bubbles: true, cancelable: true, detail: detail)
    document.dispatchEvent event
    not event.defaultPrevented

  # --- option normalization ---

  @getOpts = (path, opts) ->
    opts = @_resolveArgs path, opts
    @_resolveAjax opts if opts.ajax
    @_resolveTarget opts if opts.target
    @_resolvePath opts
    opts

  @_resolveArgs = (path, opts) ->
    opts ||= {}
    opts = target: opts if typeof opts == 'string'

    if typeof path == 'object'
      if path.nodeName then opts.ajax = path else opts = path
    else if typeof path == 'function'
      opts.done = path
    else
      opts.path = path

    if opts.href
      opts.path = opts.href
      delete opts.href

    opts.path ||= @path()

    if opts.form
      params = new URLSearchParams(new FormData(opts.form)).toString()
      if params
        opts.path += if opts.path.includes('?') then '&' else '?'
        opts.path += params

    opts

  @_resolveAjax = (opts) ->
    opts.node = opts.ajax
    opts.node = document.querySelector(opts.node) if typeof opts.node == 'string'

    return delete opts.ajax unless opts.node

    skip = false
    for el in @config.no_ajax_class
      skip = true if opts.node.closest(".#{el}")

    unless skip
      if ajax_node = opts.node.closest(@config.ajax_selector)
        opts.ajax_node = ajax_node
        opts.scroll ||= false

    delete opts.ajax

  @_resolveTarget = (opts) ->
    opts.target = document.querySelector(opts.target) if typeof opts.target == 'string'
    opts.node = opts.target
    opts.scroll ||= false

  @_resolvePath = (opts) ->
    if opts.path[0] == '?'
      if opts.ajax_node
        ajax_path = opts.ajax_node.getAttribute('data-path') || opts.ajax_node.getAttribute('path')
        opts.path = ajax_path.split('?')[0] + opts.path if ajax_path

      opts.path = location.pathname + opts.path if opts.path[0] == '?'

    if opts.replacePath && opts.replacePath[0] == '?'
      opts.replacePath = location.pathname + opts.replacePath

  # --- scroll management ---

  @shouldSkipScroll: (node) ->
    return unless node && node.closest
    for el in @config.no_scroll_selector
      return true if node.closest(el)
    false

  @scrollLock: ->
    now = Date.now()
    return if @_scrollLockTime && now - @_scrollLockTime < 1000
    @_scrollLockTime = now

    scrollPosition = window.scrollY
    body = document.body
    body.style.height = window.getComputedStyle(body).height
    window.scrollTo 0, scrollPosition

    window.requestAnimationFrame =>
      body.style.height = ''
      window.scrollTo 0, scrollPosition

  # --- page rendering ---

  @setPageBody: (node, href) ->
    title = node.querySelector('title')?.innerHTML
    document.title = title || 'no page title (pjax)'
    @scrollLock()
    pjaxNode = @node()
    return false unless pjaxNode
    if new_body = @findById node, pjaxNode.id
      finish = =>
        @morphInto pjaxNode, @parseScripts(new_body)
        @after href

      if @useViewTransition && document.startViewTransition
        document.startViewTransition finish
        true
      else
        finish()
        true
    else
      false

  @morphInto: (target, html) ->
    if window.Fez?.nodeMorph
      window.Fez.nodeMorph target, html
    else
      target.innerHTML = html

  @parseScripts: (node) ->
    if typeof node == 'string'
      div = document.createElement 'div'
      div.innerHTML = node
      node = div

    for script_tag in node.getElementsByTagName('script')
      continue unless script_tag
      continue if script_tag.getAttribute('src')
      type = script_tag.getAttribute('type') || 'javascript'
      continue unless type.includes('javascript')

      unless script_tag.id
        @script_cnt ||= 0
        script_tag.id = "app-sc-#{++@script_cnt}"

      # Scripts run BEFORE the new HTML is morphed into the live document.
      # Rationale: inline scripts in a response typically set globals/state that
      # the rendered markup will then consume on `pjax:render`. Running them
      # against a still-detached DOM also avoids a flash where new nodes appear
      # before their setup ran.
      # Side effect: a script cannot `document.querySelector` siblings in the
      # same response (they aren't in `document` yet) — do per-DOM wiring in a
      # `pjax:render` listener, or tag the script `pjax-delay` to defer it to
      # the next animation frame (after the morph completes).
      func = new Function(script_tag.textContent)
      script_tag.text = 1
      if script_tag.hasAttribute('pjax-delay') then requestAnimationFrame(func) else func()

    node.innerHTML

  @findById: (root, id) ->
    return unless root && id
    if root.getElementById
      root.getElementById id
    else
      for node in root.querySelectorAll('[id]')
        return node if node.id == id
      null

  # --- querystring helper ---

  @qs: (key, value, opts = {}) ->
    parts = location.search.replace(/^\?/, '').split('&').map (el) -> el.split('=', 2)

    if typeof value == 'undefined'
      parts.forEach (el) ->
        value = decodeURIComponent(el[1]) if el[0] == key
      value
    else
      qs = {}
      parts.forEach (el) -> qs[el[0]] = el[1] if el[0]

      if value == null || value == false
        delete qs[key]
      else
        qs[key] = encodeURIComponent value

      remaining = Object.keys(qs)
      if remaining.length
        data = remaining.map((k) => "#{k}=#{qs[k]}").join('&')
        href = location.pathname + '?' + data
      else
        href = location.pathname

      if opts.push
        @push href
      else if opts.href
        href
      else
        @load href

  # --- history management ---

  @_addHistoryEntry = (html) ->
    keys = Object.keys(@historyData)
    max = @config.history_max || 20
    delete @historyData[keys[0]] if keys.length >= max
    @historyData[@path()] = html: html, scrollY: 0

  # --- internal ---

  @fetch: (opts) ->
    pjax = new Pjax(opts)
    pjax.load()

  # --- instance methods ---

  constructor: (@opts) ->
    @href = @opts.href || @opts.path

  redirect: ->
    @href ||= location.href
    if @href.slice(0, 4) == 'http' && !@href.includes(location.host)
      window.open @href
    else
      location.href = @href
    false

  swapMode: ->
    return 'target' if @opts.target
    return 'ajax'   if @opts.ajax_node
    'full'

  emitDone: (extra = {}) ->
    duration = if @opts.req_start_time then Date.now() - @opts.req_start_time else 0
    detail = Object.assign(
      from:     Pjax.pastHref || null
      to:       @href
      status:   null
      error:    null
      duration: duration
      mode:     @swapMode()
      opts:     @opts
    , extra)
    Pjax._dispatchRender(detail)

  load: ->
    return false unless @href

    now = Date.now()
    unless @opts.force
      return false if Pjax.lastHref == @href && now - (Pjax._lastLoadTime || 0) < 2000
    Pjax._lastLoadTime = now

    # save scroll position of current page before navigating
    currentEntry = Pjax.historyData[Pjax.path()]
    currentEntry.scrollY = window.scrollY if currentEntry

    Pjax.pastHref = Pjax.lastHref
    Pjax.lastHref = @href

    e = window.event
    if e && !e.key && (e.which == 2 || e.metaKey)
      return window.open @href

    return if Pjax.before(@href, @opts) == false
    return if location.hash && location.pathname == @href

    if @href.startsWith('#')
      return if @href == '#'
      if node = document.querySelector("a[name=#{@href.replace('#', '')}]")
        node.scrollIntoView behavior: 'smooth', block: 'start'
        return false

    return @redirect() if /^http/.test(@href) || /#/.test(@href)

    for el in Pjax.config.paths_to_skip
      switch typeof el
        when 'object' then return @redirect() if el.test(@href)
        when 'function' then return @redirect() if el(@href)
        else return @redirect() if @href.startsWith(el)

    Pjax.request.abort() if Pjax.request
    @sendRequest()
    false

  sendRequest: ->
    @opts.req_start_time = Date.now()
    @opts.path = @href

    Pjax.emit 'start',
      from: Pjax.pastHref || null
      to:   @href
      mode: @swapMode()
      opts: @opts

    headers = 'x-requested-with': 'XMLHttpRequest'
    headers['cache-control'] = 'no-cache' if @opts.cache == false

    Pjax.request = @req = new XMLHttpRequest()
    @req.timeout = Pjax.config.timeout || 10000

    @req.onerror = (e) =>
      Pjax.request = null if Pjax.request == @req
      Pjax.error 'Net error: Server response not received (Pjax)'
      console.error e
      @emitDone status: 0, error: 'network'

    @req.onabort = =>
      Pjax.request = null if Pjax.request == @req
      @emitDone status: 0, error: 'abort'

    @req.ontimeout = =>
      Pjax.request = null
      Pjax.error "Request timeout: #{@href}"
      @emitDone status: 0, error: 'timeout'
      @redirect()

    @req.open 'GET', @href
    @req.setRequestHeader k, v for k, v of headers
    @req.onload = => @handleResponse()
    @req.send()

  handleResponse: ->
    Pjax.request = null
    @response = @req.responseText

    time_diff = Date.now() - @opts.req_start_time
    log_data = "Pjax.load #{@href}"
    log_data += ' (back trigger)' if @opts.history == false
    Pjax.console "#{log_data} (app #{@req.getResponseHeader('x-lux-speed') || 'n/a'}, real #{time_diff}ms, status #{@req.status})"

    if @req.status != 200
      @emitDone status: @req.status, error: 'status'
      return @redirect()

    if rul = @req.responseURL
      parsed = new URL(rul)
      @href = parsed.pathname + parsed.search

    try
      applied = @applyLoadedData()
    catch err
      Pjax.error "Apply failed: #{err?.message || err}"
      console.error err
      applied = false

    unless applied
      @emitDone status: @req.status, error: 'apply'
      return @redirect()

    @historyAddCurrent @opts.replacePath || @href
    @opts.done() if typeof @opts.done == 'function'
    @emitDone status: @req.status

    unless @opts.scroll == false || Pjax.shouldSkipScroll(@opts.node)
      window.requestAnimationFrame ->
        window.scrollTo top: 0, left: 0, behavior: 'smooth'
    else
      Pjax.scrollLock()

  applyLoadedData: ->
    @pjaxNode = Pjax.node()
    return unless @pjaxNode
    return Pjax.error('No ID attribute on pjax node') unless @pjaxNode.id

    @rroot = document.createElement('div')
    @rroot.innerHTML = @response

    return true if @opts.target && @applyTarget()
    return @applyAjax() if @opts.ajax_node
    @applyFullSwap()

  applyTarget: ->
    id = @opts.target.getAttribute('id')
    unless id
      Pjax.error 'ID attribute not found on Pjax target'
      return false

    rtarget = Pjax.findById @rroot, id
    return false unless rtarget

    Pjax.scrollLock()
    Pjax.morphInto @opts.target, Pjax.parseScripts(rtarget.innerHTML)
    true

  applyAjax: ->
    ajax_node = @opts.ajax_node
    ajax_node.setAttribute 'data-path', @href
    ajax_node.removeAttribute 'path'
    ajax_id = ajax_node.getAttribute('id') || Pjax.error('Pjax .ajax node has no ID')
    ajax_data = Pjax.findById(@rroot, ajax_id)?.innerHTML || @response
    Pjax.morphInto ajax_node, Pjax.parseScripts(ajax_data)
    true

  applyFullSwap: ->
    Pjax._addHistoryEntry @response
    Pjax.setPageBody @rroot, @href

  historyAddCurrent: (href) ->
    return if @opts.history == false || (@opts.ajax_node && !@opts.target)
    return if @history_added
    @history_added = true

    if @opts.replace || Pjax._lastHrefCheck == href
      window.history.replaceState {}, document.title, href
      Pjax._lastHrefCheck = href
    else
      window.history.pushState {}, document.title, href
      Pjax._lastHrefCheck = href

# --- window-level event handlers ---

window.onpopstate = (event) ->
  window.requestAnimationFrame ->
    path = Pjax.path()
    if entry = Pjax.historyData[path]
      Pjax.console "from history: #{path}"
      rroot = document.createElement('div')
      rroot.innerHTML = entry.html
      Pjax.setPageBody rroot, path
      window.scrollTo(0, entry.scrollY) if entry.scrollY
    else
      Pjax.load path, history: false

bindPjaxBoot = ->
  return if Pjax._booted
  Pjax._booted = true
  setTimeout Pjax.sendGlobalEvent, 0

  document.body.addEventListener 'submit', (e) ->
    form = e.target
    if is_pjax = form.getAttribute('data-pjax')
      e.preventDefault()
      pjax_target = if is_pjax == 'true' then null else is_pjax
      Pjax.load form.getAttribute('action'), form: form, target: pjax_target

if document.readyState == 'loading'
  window.addEventListener 'DOMContentLoaded', bindPjaxBoot
else
  bindPjaxBoot()

if typeof module != 'undefined' && module.exports
  module.exports = Pjax

window.Pjax = Pjax
