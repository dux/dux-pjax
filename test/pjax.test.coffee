{expect} = require 'chai'

# Ensure requestAnimationFrame exists for code paths that expect it
setupRAF = ->
  unless window.requestAnimationFrame
    window.requestAnimationFrame = (cb) -> cb()
  global.requestAnimationFrame = window.requestAnimationFrame

  window.scrollTo = ->
  global.scrollTo = window.scrollTo

setupDOM = ->
  document.body.innerHTML = '''
    <main class="pjax" id="pjax">
      <div class="ajax" id="ajax-node" data-path="/dialog">
        <a href="/next" class="ajax-trigger">Next</a>
      </div>
    </main>
  '''

setupGlobals = ->
  setupRAF()
  setupDOM()

setupGlobals()

# The module attaches itself to window.Pjax. Re-require per test to avoid stale state.
loadPjax = ->
  delete require.cache[require.resolve('../src/pjax.coffee')]
  require '../src/pjax.coffee'

describe 'Pjax module', ->
  beforeEach ->
    setupGlobals()

  it 'exports the same class via window and CommonJS', ->
    Pjax = loadPjax()
    expect(Pjax).to.equal(window.Pjax)
    expect(Pjax.config.ajax_selector).to.equal '.ajax'

  it 'derives ajax context when DOM node provided', ->
    Pjax = loadPjax()
    ajaxNode = document.getElementById('ajax-node')
    opts = Pjax.getOpts '?foo=bar', ajax: ajaxNode
    expect(opts.ajax_node).to.equal ajaxNode
    expect(opts.scroll).to.equal false
    expect(opts.path).to.equal '/dialog?foo=bar'

  it 'executes inline scripts through parseScripts', ->
    Pjax = loadPjax()
    window.__pjaxTestCounter = 0
    html = '<div><script>window.__pjaxTestCounter += 1</script></div>'
    Pjax.parseScripts html
    expect(window.__pjaxTestCounter).to.equal 1

  it 'refreshes a targeted node when selector passed', ->
    Pjax = loadPjax()
    target = document.createElement 'div'
    target.id = 'some-div'
    target.innerHTML = 'Old content'
    document.getElementById('pjax').appendChild target

    response = '''
      <main class="pjax" id="pjax">
        <div id="some-div">New content</div>
      </main>
    '''

    originalFetch = Pjax.fetch
    Pjax.fetch = (opts) ->
      pjax = new Pjax(opts)
      pjax.response = response
      pjax.applyLoadedData()
    try
      Pjax.refresh '#some-div'
    finally
      Pjax.fetch = originalFetch

    expect(document.getElementById('some-div').innerHTML).to.equal 'New content'

  it 'normalizes options before fetching when calling load', ->
    Pjax = loadPjax()
    normalized = { path: '/users' }
    calls = []
    originalGetOpts = Pjax.getOpts
    originalFetch = Pjax.fetch

    Pjax.getOpts = (href, opts) ->
      calls.push 'getOpts'
      expect(href).to.equal '/users'
      expect(opts.extra).to.equal true
      normalized

    Pjax.fetch = (opts) ->
      calls.push 'fetch'
      expect(opts).to.equal normalized

    try
      Pjax.load '/users', extra: true
      expect(calls).to.deep.equal ['getOpts', 'fetch']
    finally
      Pjax.getOpts = originalGetOpts
      Pjax.fetch = originalFetch

  it 'forces selector refreshes to skip history and scrolling', ->
    Pjax = loadPjax()
    target = document.createElement 'div'
    target.id = 'panel'
    document.getElementById('pjax').appendChild target

    originalPath = Pjax.path
    originalGetOpts = Pjax.getOpts
    originalFetch = Pjax.fetch
    normalized = {}

    Pjax.path = -> '/current'

    Pjax.getOpts = (func, opts) ->
      expect(func).to.equal '/current'
      result = originalGetOpts.call(Pjax, func, opts)
      expect(result.target).to.equal target
      expect(result.history).to.equal false
      normalized

    Pjax.fetch = (opts) ->
      expect(opts.scroll).to.equal false
      expect(opts).to.equal normalized

    try
      Pjax.refresh '#panel'
    finally
      Pjax.path = originalPath
      Pjax.getOpts = originalGetOpts
      Pjax.fetch = originalFetch

  it 'disables cache when calling reload', ->
    Pjax = loadPjax()
    originalGetOpts = Pjax.getOpts
    originalFetch = Pjax.fetch

    Pjax.getOpts = (arg) ->
      expect(arg).to.be.undefined
      {}

    Pjax.fetch = (opts) ->
      expect(opts.cache).to.equal false

    try
      Pjax.reload()
    finally
      Pjax.getOpts = originalGetOpts
      Pjax.fetch = originalFetch

  it 'normalizes replacePath with query-only value using pathname', ->
    Pjax = loadPjax()
    opts = Pjax.getOpts '/users', replacePath: '?sort=asc'
    expect(opts.replacePath).to.equal location.pathname + '?sort=asc'

  it 'returns last href or current path from last()', ->
    Pjax = loadPjax()
    originalPath = Pjax.path
    Pjax.path = -> '/current'

    try
      # before any navigation, last() returns current path
      Pjax.lastHref = undefined
      expect(Pjax.last()).to.equal '/current'

      # after navigation, last() returns the stored href
      Pjax.lastHref = '/previous'
      expect(Pjax.last()).to.equal '/previous'
    finally
      Pjax.path = originalPath

  it 'detects page refresh vs navigation via refreshed()', ->
    Pjax = loadPjax()

    # no past href yet
    expect(Pjax.refreshed()).to.equal false

    # simulate two navigations to different pages
    Pjax.pastHref = '/page1'
    Pjax.lastHref = '/page2'
    expect(Pjax.refreshed()).to.equal false

    # simulate refresh (same page twice)
    Pjax.pastHref = '/page1'
    Pjax.lastHref = '/page1'
    expect(Pjax.refreshed()).to.equal true

  it 'dispatches pjax:render custom event via sendGlobalEvent', ->
    Pjax = loadPjax()
    fired = false
    handler = -> fired = true
    document.addEventListener 'pjax:render', handler

    try
      Pjax.sendGlobalEvent()
      expect(fired).to.equal true
    finally
      document.removeEventListener 'pjax:render', handler

  it 'skips external scripts in parseScripts', ->
    Pjax = loadPjax()
    window.__externalTest = 0
    html = '<div><script src="external.js">window.__externalTest = 1</script></div>'
    Pjax.parseScripts html
    expect(window.__externalTest).to.equal 0

  it 'defers scripts with pjax-delay attribute via requestAnimationFrame', ->
    Pjax = loadPjax()
    window.__delayTest = 0
    html = '<div><script pjax-delay>window.__delayTest = 1</script></div>'
    Pjax.parseScripts html
    # requestAnimationFrame is sync in test env, so it runs immediately
    expect(window.__delayTest).to.equal 1

  it 'handles target as string selector in getOpts', ->
    Pjax = loadPjax()
    node = document.getElementById('ajax-node')
    opts = Pjax.getOpts '/test', target: '#ajax-node'
    expect(opts.target).to.equal node
    expect(opts.node).to.equal node
    expect(opts.scroll).to.equal false

  it 'binds click handler only once via onDocumentClick', ->
    Pjax = loadPjax()
    Pjax._clickBound = undefined

    Pjax.onDocumentClick()
    expect(Pjax._clickBound).to.equal true

    # calling again should not throw or rebind
    Pjax.onDocumentClick()
    expect(Pjax._clickBound).to.equal true

  it 'pushes state to history via pushState', ->
    Pjax = loadPjax()
    originalPushState = window.history.pushState
    pushed = null
    window.history.pushState = (state, title, url) -> pushed = url

    try
      Pjax.pushState '/new-path'
      expect(pushed).to.equal '/new-path'
    finally
      window.history.pushState = originalPushState

  it 'setPageBody updates title and container innerHTML', ->
    Pjax = loadPjax()
    node = document.createElement 'div'
    node.innerHTML = '<title>New Title</title><main class="pjax" id="pjax"><p>New body</p></main>'
    afterCalled = false
    Pjax.after = -> afterCalled = true

    Pjax.setPageBody node, '/test'

    expect(document.title).to.equal 'New Title'
    expect(document.getElementById('pjax').innerHTML).to.include 'New body'
    expect(afterCalled).to.equal true

  # --- getOpts additional branches ---

  it 'getOpts treats function arg as done callback', ->
    Pjax = loadPjax()
    fn = ->
    opts = Pjax.getOpts fn
    expect(opts.done).to.equal fn
    expect(opts.path).to.equal Pjax.path()

  it 'getOpts treats plain object arg as opts', ->
    Pjax = loadPjax()
    opts = Pjax.getOpts { path: '/foo', scroll: false }
    expect(opts.path).to.equal '/foo'
    expect(opts.scroll).to.equal false

  it 'getOpts converts href alias to path', ->
    Pjax = loadPjax()
    opts = Pjax.getOpts { href: '/aliased' }
    expect(opts.path).to.equal '/aliased'
    expect(opts.href).to.be.undefined

  it 'getOpts treats string second arg as target', ->
    Pjax = loadPjax()
    node = document.getElementById('ajax-node')
    opts = Pjax.getOpts '/page', '#ajax-node'
    expect(opts.target).to.equal node
    expect(opts.node).to.equal node

  it 'getOpts prepends pathname for query-only path without ajax node', ->
    Pjax = loadPjax()
    opts = Pjax.getOpts '?search=hello'
    expect(opts.path).to.equal location.pathname + '?search=hello'

  it 'getOpts skips ajax_node when parent has no_ajax_class', ->
    Pjax = loadPjax()
    document.body.innerHTML = '''
      <main class="pjax" id="pjax">
        <div class="no-ajax">
          <div class="ajax" id="inner-ajax">
            <a href="/link" id="skip-link">Link</a>
          </div>
        </div>
      </main>
    '''
    link = document.getElementById('skip-link')
    opts = Pjax.getOpts '/test', ajax: link
    expect(opts.ajax_node).to.be.undefined

  it 'getOpts uses path attribute as fallback for data-path on ajax node', ->
    Pjax = loadPjax()
    document.body.innerHTML = '''
      <main class="pjax" id="pjax">
        <div class="ajax" id="path-ajax" path="/alt-path">
          <a href="/x" id="path-link">Link</a>
        </div>
      </main>
    '''
    link = document.getElementById('path-link')
    opts = Pjax.getOpts '?q=1', ajax: link
    expect(opts.path).to.equal '/alt-path?q=1'

  # --- noScrollCheck ---

  it 'shouldSkipScroll returns true when node matches no_scroll_selector', ->
    Pjax = loadPjax()
    div = document.createElement 'div'
    div.className = 'no-scroll'
    document.body.appendChild div
    span = document.createElement 'span'
    div.appendChild span

    expect(Pjax.shouldSkipScroll(span)).to.equal true

  it 'shouldSkipScroll returns false when node does not match', ->
    Pjax = loadPjax()
    div = document.createElement 'div'
    document.body.appendChild div
    expect(Pjax.shouldSkipScroll(div)).to.equal false

  it 'shouldSkipScroll handles null node gracefully', ->
    Pjax = loadPjax()
    expect(Pjax.shouldSkipScroll(null)).to.be.undefined
    expect(Pjax.shouldSkipScroll(undefined)).to.be.undefined

  # --- scrollLock ---

  it 'scrollLock debounces calls within 1 second', ->
    Pjax = loadPjax()
    Pjax._scrollLockTime = undefined
    Pjax.scrollLock()
    firstTime = Pjax._scrollLockTime
    expect(firstTime).to.be.a 'number'

    Pjax.scrollLock()
    expect(Pjax._scrollLockTime).to.equal firstTime

  # --- parseScripts edge cases ---

  it 'parseScripts skips non-javascript type scripts', ->
    Pjax = loadPjax()
    window.__jsonTest = 0
    html = '<div><script type="application/json">window.__jsonTest = 1</script></div>'
    Pjax.parseScripts html
    expect(window.__jsonTest).to.equal 0

  it 'parseScripts accepts DOM node directly', ->
    Pjax = loadPjax()
    window.__domNodeTest = 0
    div = document.createElement 'div'
    div.innerHTML = '<script>window.__domNodeTest = 5</script>'
    Pjax.parseScripts div
    expect(window.__domNodeTest).to.equal 5

  it 'parseScripts auto-assigns ids to scripts without one', ->
    Pjax = loadPjax()
    Pjax.script_cnt = 0
    html = '<div><script>void 0</script></div>'
    div = document.createElement 'div'
    div.innerHTML = html
    Pjax.parseScripts div
    script = div.querySelector('script')
    expect(script.id).to.match /^app-sc-/

  # --- qs (querystring helper) ---

  it 'qs setter with href option returns URL string without navigating', ->
    Pjax = loadPjax()
    result = Pjax.qs 'color', 'blue', href: true
    expect(result).to.include 'color=blue'
    expect(result).to.include location.pathname

  it 'qs setter triggers Pjax.load by default', ->
    Pjax = loadPjax()
    loadedHref = null
    originalLoad = Pjax.load
    Pjax.load = (href) -> loadedHref = href

    try
      Pjax.qs 'page', '2'
      expect(loadedHref).to.include 'page=2'
    finally
      Pjax.load = originalLoad

  it 'qs setter with push option calls Pjax.push', ->
    Pjax = loadPjax()
    pushedHref = null
    originalPush = Pjax.push
    Pjax.push = (href) -> pushedHref = href

    try
      Pjax.qs 'tab', 'info', push: true
      expect(pushedHref).to.include 'tab=info'
    finally
      Pjax.push = originalPush

  # --- applyLoadedData ---

  it 'applyLoadedData in ajax_node mode replaces container and sets data-path', ->
    Pjax = loadPjax()
    ajaxNode = document.getElementById('ajax-node')
    pjax = new Pjax(path: '/new-dialog', ajax_node: ajaxNode)
    pjax.response = '<div id="ajax-node"><p>Updated ajax</p></div>'
    pjax.applyLoadedData()

    expect(ajaxNode.innerHTML).to.include 'Updated ajax'
    expect(ajaxNode.getAttribute('data-path')).to.equal '/new-dialog'

  it 'applyLoadedData in ajax_node mode uses full response when no matching id', ->
    Pjax = loadPjax()
    ajaxNode = document.getElementById('ajax-node')
    pjax = new Pjax(path: '/fallback', ajax_node: ajaxNode)
    pjax.response = '<p>Full response fallback</p>'
    pjax.applyLoadedData()

    expect(ajaxNode.innerHTML).to.include 'Full response fallback'

  it 'applyLoadedData matches target ids containing selector metacharacters', ->
    Pjax = loadPjax()
    target = document.createElement 'div'
    target.id = 'user:42.panel'
    target.innerHTML = 'Old'
    document.getElementById('pjax').appendChild target

    pjax = new Pjax(path: '/special-id', target: target)
    pjax.response = '<main class="pjax" id="pjax"><div id="user:42.panel">New</div></main>'
    result = pjax.applyLoadedData()

    expect(result).to.equal true
    expect(target.innerHTML).to.equal 'New'

  it 'applyLoadedData in full swap mode stores response by destination href', ->
    Pjax = loadPjax()
    originalPush = window.history.pushState
    originalReplace = window.history.replaceState
    window.history.pushState = ->
    window.history.replaceState = ->

    try
      response = '<title>Stored</title><main class="pjax" id="pjax"><p>Cached</p></main>'
      pjax = new Pjax(path: '/cached-page')
      pjax.response = response
      pjax.applyLoadedData()
      expect(Pjax.historyData['/cached-page'].html).to.equal response
    finally
      window.history.pushState = originalPush
      window.history.replaceState = originalReplace

  # --- historyAddCurrent ---

  it 'historyAddCurrent skips when history is false', ->
    Pjax = loadPjax()
    pushCalled = false
    originalPush = window.history.pushState
    window.history.pushState = -> pushCalled = true

    try
      pjax = new Pjax(path: '/skip', history: false)
      pjax.historyAddCurrent('/skip')
      expect(pushCalled).to.equal false
    finally
      window.history.pushState = originalPush

  it 'historyAddCurrent skips when ajax_node set without target', ->
    Pjax = loadPjax()
    pushCalled = false
    originalPush = window.history.pushState
    window.history.pushState = -> pushCalled = true

    try
      ajaxNode = document.getElementById('ajax-node')
      pjax = new Pjax(path: '/ajax', ajax_node: ajaxNode)
      pjax.historyAddCurrent('/ajax')
      expect(pushCalled).to.equal false
    finally
      window.history.pushState = originalPush

  it 'historyAddCurrent uses replaceState on duplicate href', ->
    Pjax = loadPjax()
    replaced = null
    pushed = null
    originalPush = window.history.pushState
    originalReplace = window.history.replaceState
    window.history.pushState = (s, t, url) -> pushed = url
    window.history.replaceState = (s, t, url) -> replaced = url

    try
      Pjax._lastHrefCheck = '/same-page'
      pjax = new Pjax(path: '/same-page')
      pjax.historyAddCurrent('/same-page')
      expect(replaced).to.equal '/same-page'
      expect(pushed).to.be.null
    finally
      window.history.pushState = originalPush
      window.history.replaceState = originalReplace

  it 'historyAddCurrent uses pushState on new href', ->
    Pjax = loadPjax()
    pushed = null
    originalPush = window.history.pushState
    window.history.pushState = (s, t, url) -> pushed = url

    try
      Pjax._lastHrefCheck = '/old-page'
      pjax = new Pjax(path: '/new-page')
      pjax.historyAddCurrent('/new-page')
      expect(pushed).to.equal '/new-page'
      expect(Pjax._lastHrefCheck).to.equal '/new-page'
    finally
      window.history.pushState = originalPush

  # --- instance load() ---

  it 'instance load returns false when href is empty', ->
    Pjax = loadPjax()
    pjax = new Pjax(path: '')
    global.event = undefined
    result = pjax.load()
    expect(result).to.equal false

  it 'instance load aborts when before() returns false', ->
    Pjax = loadPjax()
    Pjax.before = -> false
    global.event = undefined
    pjax = new Pjax(path: '/blocked')
    result = pjax.load()
    expect(result).to.be.undefined

  it 'instance load tracks pastHref and lastHref', ->
    Pjax = loadPjax()
    Pjax.lastHref = '/previous'
    Pjax.before = -> false
    global.event = undefined
    pjax = new Pjax(path: '/current')
    pjax.load()
    expect(Pjax.pastHref).to.equal '/previous'
    expect(Pjax.lastHref).to.equal '/current'

  it 'instance load redirects for paths_to_skip string match', ->
    Pjax = loadPjax()
    global.event = undefined
    Pjax.config.paths_to_skip = ['/admin']
    redirected = false
    pjax = new Pjax(path: '/admin/users')
    pjax.redirect = -> redirected = true
    pjax.load()
    expect(redirected).to.equal true
    Pjax.config.paths_to_skip = []

  it 'instance load redirects for paths_to_skip regex match', ->
    Pjax = loadPjax()
    global.event = undefined
    Pjax.config.paths_to_skip = [/^\/api/]
    redirected = false
    pjax = new Pjax(path: '/api/v1/data')
    pjax.redirect = -> redirected = true
    pjax.load()
    expect(redirected).to.equal true
    Pjax.config.paths_to_skip = []

  it 'instance load redirects for paths_to_skip function match', ->
    Pjax = loadPjax()
    global.event = undefined
    Pjax.config.paths_to_skip = [(href) -> href.includes('skip')]
    redirected = false
    pjax = new Pjax(path: '/please-skip-this')
    pjax.redirect = -> redirected = true
    pjax.load()
    expect(redirected).to.equal true
    Pjax.config.paths_to_skip = []

  it 'instance load redirects for URLs with http prefix', ->
    Pjax = loadPjax()
    global.event = undefined
    redirected = false
    pjax = new Pjax(path: 'https://example.com')
    pjax.redirect = -> redirected = true
    pjax.load()
    expect(redirected).to.equal true

  it 'instance load redirects for URLs containing hash', ->
    Pjax = loadPjax()
    global.event = undefined
    redirected = false
    pjax = new Pjax(path: '/page#section')
    pjax.redirect = -> redirected = true
    pjax.load()
    expect(redirected).to.equal true

  it 'instance load aborts previous in-flight request', ->
    Pjax = loadPjax()
    global.event = undefined
    aborted = false
    Pjax.request = { abort: -> aborted = true }

    MockXHR = class
      open: ->
      setRequestHeader: ->
      send: ->
    OrigXHR = global.XMLHttpRequest
    global.XMLHttpRequest = MockXHR

    try
      pjax = new Pjax(path: '/new')
      pjax.load()
      expect(aborted).to.equal true
    finally
      global.XMLHttpRequest = OrigXHR

  it 'instance load sends XHR with correct headers and timeout', ->
    Pjax = loadPjax()
    global.event = undefined
    Pjax.request = null
    headers = {}
    timeoutSet = null
    MockXHR = class
      open: ->
      setRequestHeader: (k, v) -> headers[k] = v
      send: ->
    OrigXHR = global.XMLHttpRequest
    global.XMLHttpRequest = MockXHR

    try
      pjax = new Pjax(path: '/headers-test', cache: false)
      pjax.load()
      expect(headers['x-requested-with']).to.equal 'XMLHttpRequest'
      expect(headers['cache-control']).to.equal 'no-cache'
      expect(Pjax.request.timeout).to.equal 10000
    finally
      global.XMLHttpRequest = OrigXHR

  # --- redirect ---

  it 'redirect returns false', ->
    Pjax = loadPjax()
    opened = null
    originalOpen = window.open
    window.open = (url) -> opened = url

    try
      pjax = new Pjax(path: 'https://external.com/page')
      result = pjax.redirect()
      expect(result).to.equal false
    finally
      window.open = originalOpen

  # --- setPageBody edge cases ---

  it 'setPageBody defaults title when none found in response', ->
    Pjax = loadPjax()
    node = document.createElement 'div'
    node.innerHTML = '<main class="pjax" id="pjax"><p>No title</p></main>'
    Pjax.after = ->
    Pjax.setPageBody node, '/no-title'
    expect(document.title).to.equal 'no page title (pjax)'

  it 'setPageBody morphs new body in', ->
    Pjax = loadPjax()
    node = document.createElement 'div'
    node.innerHTML = '<title>T</title><main class="pjax" id="pjax"><p>Body</p></main>'
    Pjax.after = ->
    Pjax.setPageBody node, '/event-test'
    pjaxNode = Pjax.node()
    expect(pjaxNode.querySelector('p')?.textContent).to.equal 'Body'

  it 'morphInto keeps a single wrapper child when Fez.nodeMorph is present', ->
    Pjax = loadPjax()
    target = document.getElementById('pjax')
    target.innerHTML = '<div class="old-wrapper"><p>Old</p></div>'

    originalFez = window.Fez
    window.Fez =
      nodeMorph: (target, src) ->
        if src?.nodeType == 11
          wrapper = document.createElement target.tagName.toLowerCase()
          wrapper.appendChild src
          target.innerHTML = wrapper.innerHTML
        else
          wrapper = document.createElement target.tagName.toLowerCase()
          wrapper.innerHTML = src.trim()
          if wrapper.children.length == 1 && wrapper.firstElementChild.tagName == target.tagName
            target.innerHTML = wrapper.firstElementChild.innerHTML
          else
            target.innerHTML = wrapper.innerHTML

    try
      Pjax.morphInto target, '<div class="flex"><p>Body</p></div>'
      expect(target.children.length).to.equal 1
      expect(target.firstElementChild.className).to.equal 'flex'
      expect(target.querySelector('.flex p')?.textContent).to.equal 'Body'
    finally
      window.Fez = originalFez

  # --- push alias ---

  it 'push is an alias for pushState', ->
    Pjax = loadPjax()
    pushed = null
    originalPush = window.history.pushState
    window.history.pushState = (s, t, url) -> pushed = url

    try
      Pjax.push '/alias-test'
      expect(pushed).to.equal '/alias-test'
    finally
      window.history.pushState = originalPush

  # --- config defaults ---

  it 'has sensible default config values', ->
    Pjax = loadPjax()
    expect(Pjax.config.no_scroll_selector).to.deep.equal ['.no-scroll']
    expect(Pjax.config.paths_to_skip).to.deep.equal []
    expect(Pjax.config.no_pjax_class).to.deep.equal ['no-pjax', 'direct']
    expect(Pjax.config.no_ajax_class).to.deep.equal ['ajax-skip', 'skip-ajax', 'no-ajax', 'top']
    expect(Pjax.config.ajax_selector).to.equal '.ajax'
    expect(Pjax.config.timeout).to.equal 10000
    expect(Pjax.config.history_max).to.equal 20

  # --- refresh without selector ---

  it 'refresh without selector uses current path and disables scroll', ->
    Pjax = loadPjax()
    fetchedOpts = null
    originalFetch = Pjax.fetch

    Pjax.fetch = (opts) -> fetchedOpts = opts

    try
      Pjax.refresh()
      expect(fetchedOpts.scroll).to.equal false
      expect(fetchedOpts.path).to.equal Pjax.path()
    finally
      Pjax.fetch = originalFetch

  # --- console logging ---

  it 'console logs when not silent and suppresses when silent', ->
    Pjax = loadPjax()
    logged = null
    originalLog = console.log
    console.log = (msg) -> logged = msg

    try
      Pjax.config.is_silent = false
      Pjax.console 'test message'
      expect(logged).to.equal 'test message'

      logged = null
      Pjax.config.is_silent = true
      Pjax.console 'should not appear'
      expect(logged).to.be.null
    finally
      console.log = originalLog

  it 'Pjax.DEV overrides is_silent', ->
    Pjax = loadPjax()
    logged = null
    originalLog = console.log
    console.log = (msg) -> logged = msg

    try
      Pjax.config.is_silent = true
      Pjax.DEV = true
      Pjax.console 'forced via DEV'
      expect(logged).to.equal 'forced via DEV'
    finally
      console.log = originalLog
      Pjax.DEV = undefined

  # --- replace ---

  it 'replace uses replaceState', ->
    Pjax = loadPjax()
    replaced = null
    originalReplace = window.history.replaceState
    window.history.replaceState = (s, t, url) -> replaced = url

    try
      Pjax.replace '/replaced-path'
      expect(replaced).to.equal '/replaced-path'
    finally
      window.history.replaceState = originalReplace

  # --- qs null/false removal ---

  it 'qs removes param when value is null', ->
    Pjax = loadPjax()
    result = Pjax.qs 'remove_me', null, href: true
    expect(result).to.not.include 'remove_me'

  it 'qs removes param when value is false', ->
    Pjax = loadPjax()
    result = Pjax.qs 'gone', false, href: true
    expect(result).to.not.include 'gone'

  # --- history cap ---

  it '_addHistoryEntry caps entries at history_max', ->
    Pjax = loadPjax()
    Pjax.config.history_max = 3
    callCount = 0
    originalPath = Pjax.path
    Pjax.path = -> "/page-#{++callCount}"
    try
      Pjax._addHistoryEntry 'page1'
      Pjax._addHistoryEntry 'page2'
      Pjax._addHistoryEntry 'page3'
      expect(Object.keys(Pjax.historyData).length).to.equal 3
      Pjax._addHistoryEntry 'page4'
      expect(Object.keys(Pjax.historyData).length).to.equal 3
      expect(Pjax.historyData['/page-1']).to.be.undefined
    finally
      Pjax.path = originalPath

  it '_addHistoryEntry stores html and scrollY', ->
    Pjax = loadPjax()
    Pjax._addHistoryEntry '<p>test</p>'
    entry = Pjax.historyData[Pjax.path()]
    expect(entry.html).to.equal '<p>test</p>'
    expect(entry.scrollY).to.equal 0

  # --- scroll position save ---

  it 'instance load saves scroll position of current page before navigating', ->
    Pjax = loadPjax()
    global.event = undefined
    Pjax.before = -> false
    Pjax.historyData[Pjax.path()] = html: '<p>old</p>', scrollY: 0
    Object.defineProperty window, 'scrollY', value: 150, writable: true, configurable: true

    try
      pjax = new Pjax(path: '/next')
      pjax.load()
      expect(Pjax.historyData[Pjax.path()].scrollY).to.equal 150
    finally
      Object.defineProperty window, 'scrollY', value: 0, writable: true, configurable: true

  # --- onclick module ---

describe 'PjaxOnClick', ->
  beforeEach ->
    setupGlobals()

  loadModules = ->
    delete require.cache[require.resolve('../src/pjax.coffee')]
    delete require.cache[require.resolve('../src/onclick.coffee')]
    Pjax = require '../src/pjax.coffee'
    global.Pjax = Pjax
    PjaxOnClick = require '../src/onclick.coffee'
    { Pjax, PjaxOnClick }

  createClickEvent = (overrides = {}) ->
    e = new window.MouseEvent('click', bubbles: true, cancelable: true)
    for k, v of overrides
      Object.defineProperty e, k, value: v
    e

  it 'dispatches click attribute as inline JS bound to the element', ->
    { Pjax, PjaxOnClick } = loadModules()
    document.body.innerHTML = '<div click="this.dataset.ran = \'yes\'" id="clicker">Click me</div>'
    node = document.getElementById('clicker')
    event = createClickEvent()
    node.dispatchEvent event
    PjaxOnClick.main(event)

    node2 = document.getElementById('clicker')
    e2 = createClickEvent(target: node2)
    PjaxOnClick.main(e2)
    expect(node2.dataset.ran).to.equal 'yes'

  it 'calls Pjax.load with ajax context for regular href clicks', ->
    { Pjax, PjaxOnClick } = loadModules()
    document.body.innerHTML = '''
      <main class="pjax" id="pjax">
        <a href="/clicked-page" id="link">Go</a>
      </main>
    '''
    loadedArgs = null
    Pjax.load = (href, opts) -> loadedArgs = { href, opts }

    link = document.getElementById('link')
    e = createClickEvent(target: link)
    PjaxOnClick.main(e)

    expect(loadedArgs).to.not.be.null
    expect(loadedArgs.href).to.equal '/clicked-page'
    expect(loadedArgs.opts.ajax).to.equal link

  it 'uses pjax-target to load into a specific element', ->
    { Pjax, PjaxOnClick } = loadModules()
    document.body.innerHTML = '''
      <main class="pjax" id="pjax">
        <div id="target-box">Old</div>
        <a href="/target-page" pjax-target="#target-box" id="t-link">Load</a>
      </main>
    '''
    loadedArgs = null
    Pjax.load = (href, opts) -> loadedArgs = { href, opts }

    link = document.getElementById('t-link')
    e = createClickEvent(target: link)
    PjaxOnClick.main(e)

    expect(loadedArgs.href).to.equal '/target-page'
    expect(loadedArgs.opts.target).to.equal document.getElementById('target-box')

  it 'uses pjax-refresh to refresh a specific element without href', ->
    { Pjax, PjaxOnClick } = loadModules()
    document.body.innerHTML = '''
      <main class="pjax" id="pjax">
        <div id="target-box">Old</div>
        <button pjax-refresh="#target-box" id="refresh-button">Refresh</button>
      </main>
    '''
    refreshedTarget = null
    Pjax.refresh = (target) -> refreshedTarget = target

    button = document.getElementById('refresh-button')
    e = createClickEvent(target: button)
    PjaxOnClick.main(e)

    expect(refreshedTarget).to.equal '#target-box'

  it 'aborts and logs error when pjax-refresh selector matches nothing', ->
    { Pjax, PjaxOnClick } = loadModules()
    document.body.innerHTML = '''
      <main class="pjax" id="pjax">
        <button pjax-refresh="#missing" id="refresh-button">Refresh</button>
      </main>
    '''
    refreshCalled = false
    Pjax.refresh = -> refreshCalled = true
    errs = []
    originalError = Pjax.error
    Pjax.error = (msg) -> errs.push msg

    try
      button = document.getElementById('refresh-button')
      e = createClickEvent(target: button)
      PjaxOnClick.main(e)

      expect(refreshCalled).to.equal false
      expect(errs[0]).to.include 'pjax-refresh'
    finally
      Pjax.error = originalError

  it 'aborts and logs error when pjax-target selector matches nothing', ->
    { Pjax, PjaxOnClick } = loadModules()
    document.body.innerHTML = '''
      <main class="pjax" id="pjax">
        <a href="/x" pjax-target="#missing" id="miss-link">Load</a>
      </main>
    '''
    loadCalled = false
    Pjax.load = -> loadCalled = true
    opened = null
    originalOpen = window.open
    window.open = (url) -> opened = url

    errs = []
    originalError = Pjax.error
    Pjax.error = (msg) -> errs.push msg

    try
      link = document.getElementById('miss-link')
      e = createClickEvent(target: link)
      PjaxOnClick.main(e)
      expect(loadCalled).to.equal false
      expect(opened).to.be.null
      expect(errs[0]).to.include 'pjax-target'
    finally
      window.open = originalOpen
      Pjax.error = originalError

  it 'no-pjax link without target navigates the current tab, not a new window', ->
    { Pjax, PjaxOnClick } = loadModules()
    document.body.innerHTML = '<a href="https://example.com" class="no-pjax" id="ext">Ext</a>'

    opened = null
    left = null
    originalOpen = window.open
    window.open = (url) -> opened = url
    PjaxOnClick.leave = (href, target) -> left = { href, target }

    try
      e = createClickEvent(target: document.getElementById('ext'))
      PjaxOnClick.main(e)
      expect(opened).to.be.null
      expect(left.href).to.equal 'https://example.com'
      expect(left.target).to.be.null
    finally
      window.open = originalOpen

  it 'no-pjax link with target opens a new window', ->
    { Pjax, PjaxOnClick } = loadModules()
    document.body.innerHTML = '<a href="https://example.com" target="_blank" class="no-pjax" id="ext">Ext</a>'

    opened = null
    openedTarget = null
    originalOpen = window.open
    window.open = (url, target) -> opened = url; openedTarget = target

    try
      e = createClickEvent(target: document.getElementById('ext'))
      PjaxOnClick.main(e)
      expect(opened).to.equal 'https://example.com'
      expect(openedTarget).to.equal '_blank'
    finally
      window.open = originalOpen

  it 'opts out of pjax when an ancestor carries a no-pjax class', ->
    { Pjax, PjaxOnClick } = loadModules()
    document.body.innerHTML = '''
      <div class="direct">
        <a href="/inner-page" id="nested">Go</a>
      </div>
    '''
    left = null
    loadCalled = false
    Pjax.load = -> loadCalled = true
    PjaxOnClick.leave = (href, target) -> left = { href, target }

    e = createClickEvent(target: document.getElementById('nested'))
    PjaxOnClick.main(e)
    expect(loadCalled).to.equal false
    expect(left.href).to.equal '/inner-page'
    expect(left.target).to.be.null

  it 'external scheme link without target stays in the current tab', ->
    { Pjax, PjaxOnClick } = loadModules()
    document.body.innerHTML = '<a href="https://other.example/path" id="scheme">Out</a>'

    opened = null
    left = null
    originalOpen = window.open
    window.open = (url) -> opened = url
    PjaxOnClick.leave = (href, target) -> left = { href, target }

    try
      e = createClickEvent(target: document.getElementById('scheme'))
      PjaxOnClick.main(e)
      expect(opened).to.be.null
      expect(left.href).to.equal 'https://other.example/path'
      expect(left.target).to.be.null
    finally
      window.open = originalOpen

  it 'executes javascript: href as inline function', ->
    { Pjax, PjaxOnClick } = loadModules()
    window.__jsHrefTest = 0
    document.body.innerHTML = '<a href="javascript:window.__jsHrefTest=99" id="js-link">Run</a>'

    link = document.getElementById('js-link')
    e = createClickEvent(target: link)
    PjaxOnClick.main(e)
    expect(window.__jsHrefTest).to.equal 99

  it 'ignores elements without click or href attributes', ->
    { Pjax, PjaxOnClick } = loadModules()
    document.body.innerHTML = '<div id="plain">No action</div>'
    loadCalled = false
    Pjax.load = -> loadCalled = true

    div = document.getElementById('plain')
    e = createClickEvent(target: div)
    PjaxOnClick.main(e)
    expect(loadCalled).to.equal false

  it 'opens links with target attribute in named window', ->
    { Pjax, PjaxOnClick } = loadModules()
    document.body.innerHTML = '<a href="mailto:test@x.com" target="_blank" id="target-link">Mail</a>'

    opened = null
    openedTarget = null
    originalOpen = window.open
    window.open = (url, target) -> opened = url; openedTarget = target

    try
      link = document.getElementById('target-link')
      e = createClickEvent(target: link)
      PjaxOnClick.main(e)
      expect(opened).to.equal 'mailto:test@x.com'
      expect(openedTarget).to.equal '_blank'
    finally
      window.open = originalOpen

  it 'treats relative path without scheme as pjax navigation', ->
    { Pjax, PjaxOnClick } = loadModules()
    document.body.innerHTML = '''
      <main class="pjax" id="pjax">
        <a href="users" id="rel-link">Users</a>
      </main>
    '''
    loadedArgs = null
    opened = null
    originalOpen = window.open
    window.open = (url) -> opened = url
    Pjax.load = (href, opts) -> loadedArgs = { href, opts }

    try
      link = document.getElementById('rel-link')
      e = createClickEvent(target: link)
      PjaxOnClick.main(e)
      expect(opened).to.be.null
      expect(loadedArgs).to.not.be.null
      expect(loadedArgs.href).to.equal 'users'
    finally
      window.open = originalOpen

  it 'pjax-confirm aborts navigation when confirm returns false', ->
    { Pjax, PjaxOnClick } = loadModules()
    document.body.innerHTML = '''
      <main class="pjax" id="pjax">
        <a href="/danger" pjax-confirm="Sure?" id="confirm-link">Delete</a>
      </main>
    '''
    loadCalled = false
    Pjax.load = -> loadCalled = true
    originalConfirm = window.confirm
    confirmedWith = null
    window.confirm = (msg) -> confirmedWith = msg; false

    try
      link = document.getElementById('confirm-link')
      e = createClickEvent(target: link)
      PjaxOnClick.main(e)
      expect(confirmedWith).to.equal 'Sure?'
      expect(loadCalled).to.equal false
    finally
      window.confirm = originalConfirm

  it 'pjax-confirm proceeds with navigation when confirm returns true', ->
    { Pjax, PjaxOnClick } = loadModules()
    document.body.innerHTML = '''
      <main class="pjax" id="pjax">
        <a href="/ok" pjax-confirm="Sure?" id="confirm-ok">Go</a>
      </main>
    '''
    loadedHref = null
    Pjax.load = (href) -> loadedHref = href
    originalConfirm = window.confirm
    window.confirm = -> true

    try
      link = document.getElementById('confirm-ok')
      e = createClickEvent(target: link)
      PjaxOnClick.main(e)
      expect(loadedHref).to.equal '/ok'
    finally
      window.confirm = originalConfirm

  it 'pjax-replace passes replace flag through to Pjax.load', ->
    { Pjax, PjaxOnClick } = loadModules()
    document.body.innerHTML = '''
      <main class="pjax" id="pjax">
        <a href="/replace-me" pjax-replace id="rep-link">Tab</a>
      </main>
    '''
    loadedOpts = null
    Pjax.load = (href, opts) -> loadedOpts = opts

    link = document.getElementById('rep-link')
    e = createClickEvent(target: link)
    PjaxOnClick.main(e)
    expect(loadedOpts.replace).to.equal true

  it 'main works when invoked as a bare function (addEventListener style)', ->
    { Pjax, PjaxOnClick } = loadModules()
    document.body.innerHTML = '''
      <main class="pjax" id="pjax">
        <a href="/bare" id="bare-link">X</a>
      </main>
    '''
    loadedHref = null
    Pjax.load = (href) -> loadedHref = href

    fn = PjaxOnClick.main
    link = document.getElementById('bare-link')
    e = createClickEvent(target: link)
    fn(e)
    expect(loadedHref).to.equal '/bare'

  it 'Pjax.confirm receives message and trigger node', ->
    { Pjax, PjaxOnClick } = loadModules()
    document.body.innerHTML = '''
      <main class="pjax" id="pjax">
        <a href="/del" pjax-confirm="Sure?" pjax-yes="Delete" id="hooked">X</a>
      </main>
    '''
    Pjax.load = ->
    captured = null
    Pjax.confirm = (msg, node) ->
      captured = { msg, yesAttr: node.getAttribute('pjax-yes'), id: node.id }
      false

    link = document.getElementById('hooked')
    e = createClickEvent(target: link)
    PjaxOnClick.main(e)
    expect(captured.msg).to.equal 'Sure?'
    expect(captured.yesAttr).to.equal 'Delete'
    expect(captured.id).to.equal 'hooked'

  it 'Pjax.confirm Promise resolution defers navigation', (done) ->
    { Pjax, PjaxOnClick } = loadModules()
    document.body.innerHTML = '''
      <main class="pjax" id="pjax">
        <a href="/async" pjax-confirm="?" id="async-link">X</a>
      </main>
    '''
    loadCalledWith = null
    Pjax.load = (href) -> loadCalledWith = href

    resolveFn = null
    Pjax.confirm = -> new Promise (resolve) -> resolveFn = resolve

    link = document.getElementById('async-link')
    e = createClickEvent(target: link)
    PjaxOnClick.main(e)
    expect(loadCalledWith).to.be.null
    resolveFn(true)
    setTimeout (->
      expect(loadCalledWith).to.equal '/async'
      done()
    ), 0

  it 'Pjax.confirm Promise resolving false drops navigation', (done) ->
    { Pjax, PjaxOnClick } = loadModules()
    document.body.innerHTML = '''
      <main class="pjax" id="pjax">
        <a href="/no-go" pjax-confirm="?" id="no-link">X</a>
      </main>
    '''
    loadCalled = false
    Pjax.load = -> loadCalled = true

    Pjax.confirm = -> Promise.resolve(false)

    link = document.getElementById('no-link')
    e = createClickEvent(target: link)
    PjaxOnClick.main(e)
    setTimeout (->
      expect(loadCalled).to.equal false
      done()
    ), 0

describe 'Pjax lifecycle events', ->
  beforeEach ->
    setupGlobals()

  loadPjaxFresh = ->
    delete require.cache[require.resolve('../src/pjax.coffee')]
    require '../src/pjax.coffee'

  it 'emit returns false when listener calls preventDefault', ->
    Pjax = loadPjaxFresh()
    handler = (e) -> e.preventDefault()
    document.addEventListener 'pjax:before', handler

    try
      result = Pjax.emit 'before', href: '/x'
      expect(result).to.equal false
    finally
      document.removeEventListener 'pjax:before', handler

  it 'emit returns true when no listener prevents', ->
    Pjax = loadPjaxFresh()
    expect(Pjax.emit('before', href: '/x')).to.equal true

  it 'follows a same-origin redirect in place instead of hard navigating', ->
    Pjax = loadPjaxFresh()
    sent = false
    redirected = false

    pjax = new Pjax(path: '/dev/login_as?user_hash=abc')
    pjax.sendRequest = -> sent = true
    pjax.redirect = -> redirected = true
    pjax.req =
      status: 302
      getResponseHeader: (name) -> if name == 'Location' then '/dev/login_as?_r=1' else null
    pjax.opts.req_start_time = Date.now() - 50
    pjax.handleResponse()

    expect(sent).to.equal true
    expect(redirected).to.equal false
    expect(pjax.href).to.equal '/dev/login_as?_r=1'
    expect(pjax.opts.replace).to.equal true

  it 'pjax:render carries error detail on non-200 response', ->
    Pjax = loadPjaxFresh()
    captured = null
    handler = (e) -> captured = e.detail
    document.addEventListener 'pjax:render', handler

    try
      pjax = new Pjax(path: '/missing')
      pjax.req =
        status: 404
        getResponseHeader: -> null
      pjax.opts.req_start_time = Date.now() - 50
      pjax.redirect = ->
      pjax.handleResponse()
      expect(captured.status).to.equal 404
      expect(captured.error).to.equal 'status'
      expect(captured.to).to.equal '/missing'
      expect(captured.mode).to.equal 'full'
      expect(typeof captured.duration).to.equal 'number'
    finally
      document.removeEventListener 'pjax:render', handler

  it 'pjax:render carries ok detail on successful response', ->
    Pjax = loadPjaxFresh()
    originalPush = window.history.pushState
    originalReplace = window.history.replaceState
    window.history.pushState = ->
    window.history.replaceState = ->

    captured = null
    handler = (e) -> captured = e.detail
    document.addEventListener 'pjax:render', handler

    try
      pjax = new Pjax(path: '/ok')
      pjax.fromHref = '/from-ok'
      pjax.req =
        status: 200
        responseText: '<main class="pjax" id="pjax"><p>ok</p></main>'
        getResponseHeader: -> null
        responseURL: ''
      pjax.opts.req_start_time = Date.now() - 50
      pjax.handleResponse()
      expect(captured.status).to.equal 200
      expect(captured.error).to.equal null
      expect(captured.from).to.equal '/from-ok'
      expect(captured.to).to.equal '/ok'
      expect(captured.mode).to.equal 'full'
    finally
      document.removeEventListener 'pjax:render', handler
      window.history.pushState = originalPush
      window.history.replaceState = originalReplace

  it 'pjax:render to uses replacePath when history uses replacePath', ->
    Pjax = loadPjaxFresh()
    originalPush = window.history.pushState
    originalReplace = window.history.replaceState
    window.history.pushState = ->
    window.history.replaceState = ->

    captured = null
    handler = (e) -> captured = e.detail
    document.addEventListener 'pjax:render', handler

    try
      pjax = new Pjax(path: '/internal', replacePath: '/visible')
      pjax.fromHref = '/before'
      pjax.req =
        status: 200
        responseText: '<main class="pjax" id="pjax"><p>ok</p></main>'
        getResponseHeader: -> null
        responseURL: ''
      pjax.opts.req_start_time = Date.now() - 50
      pjax.handleResponse()
      expect(captured.from).to.equal '/before'
      expect(captured.to).to.equal '/visible'
    finally
      document.removeEventListener 'pjax:render', handler
      window.history.pushState = originalPush
      window.history.replaceState = originalReplace

  it 'commits history before applying a successful response', ->
    Pjax = loadPjaxFresh()
    originalPush = window.history.pushState
    window.history.pushState = ->

    calls = []

    try
      pjax = new Pjax(path: '/ordered')
      pjax.req =
        status: 200
        responseText: '<main class="pjax" id="pjax"><p>ok</p></main>'
        getResponseHeader: -> null
        responseURL: ''
      pjax.historyAddCurrent = (href) ->
        calls.push "history:#{href}"
      pjax.applyLoadedData = ->
        calls.push 'apply'
        true

      pjax.handleResponse()
      expect(calls).to.deep.equal ['history:/ordered', 'apply']
    finally
      window.history.pushState = originalPush

  it 'runs response scripts after history has been committed', ->
    Pjax = loadPjaxFresh()
    originalPush = window.history.pushState
    window.history.pushState = ->

    try
      window.__historyCommittedHref = null
      window.__scriptSawHistoryHref = null
      pjax = new Pjax(path: '/script-path')
      pjax.req =
        status: 200
        responseText: '<main class="pjax" id="pjax"><script>window.__scriptSawHistoryHref = window.__historyCommittedHref</script><p>ok</p></main>'
        getResponseHeader: -> null
        responseURL: ''
      pjax.historyAddCurrent = (href) ->
        window.__historyCommittedHref = href

      pjax.handleResponse()
      expect(window.__scriptSawHistoryHref).to.equal '/script-path'
    finally
      delete window.__historyCommittedHref
      delete window.__scriptSawHistoryHref
      window.history.pushState = originalPush

  it 'sendRequest emits pjax:start with from/to/mode/opts', ->
    Pjax = loadPjaxFresh()
    captured = null
    handler = (e) -> captured = e.detail
    document.addEventListener 'pjax:start', handler

    OrigXHR = global.XMLHttpRequest
    class MockXHR
      open: ->
      setRequestHeader: ->
      send: ->
    global.XMLHttpRequest = MockXHR

    try
      Pjax.pastHref = '/from'
      pjax = new Pjax(path: '/to')
      pjax.sendRequest()
      expect(captured.from).to.equal '/from'
      expect(captured.to).to.equal '/to'
      expect(captured.mode).to.equal 'full'
      expect(captured.opts).to.equal pjax.opts
      expect(captured.status).to.equal undefined
    finally
      global.XMLHttpRequest = OrigXHR
      document.removeEventListener 'pjax:start', handler

  it 'pjax:render carries error:network when XHR onerror fires', ->
    Pjax = loadPjaxFresh()
    captured = null
    handler = (e) -> captured = e.detail
    document.addEventListener 'pjax:render', handler

    OrigXHR = global.XMLHttpRequest
    capturedXHR = null
    class MockXHR
      constructor: ->
        capturedXHR = this
      open: ->
      setRequestHeader: ->
      send: ->

    global.XMLHttpRequest = MockXHR

    try
      pjax = new Pjax(path: '/dead')
      pjax.sendRequest()
      capturedXHR.onerror(new Error 'boom')
      expect(captured.error).to.equal 'network'
      expect(captured.status).to.equal 0
      expect(captured.to).to.equal '/dead'
    finally
      global.XMLHttpRequest = OrigXHR
      document.removeEventListener 'pjax:render', handler

  it 'pjax:render carries error:abort when XHR onabort fires', ->
    Pjax = loadPjaxFresh()
    captured = null
    handler = (e) -> captured = e.detail
    document.addEventListener 'pjax:render', handler

    OrigXHR = global.XMLHttpRequest
    capturedXHR = null
    class MockXHR
      constructor: ->
        capturedXHR = this
      open: ->
      setRequestHeader: ->
      send: ->

    global.XMLHttpRequest = MockXHR

    try
      pjax = new Pjax(path: '/aborted')
      pjax.sendRequest()
      capturedXHR.onabort()
      expect(captured.error).to.equal 'abort'
      expect(captured.status).to.equal 0
      expect(captured.to).to.equal '/aborted'
    finally
      global.XMLHttpRequest = OrigXHR
      document.removeEventListener 'pjax:render', handler

  it 'commits history before redirecting when response apply fails', ->
    Pjax = loadPjaxFresh()
    pushed = false
    redirected = false
    originalPush = window.history.pushState
    window.history.pushState = -> pushed = true

    try
      pjax = new Pjax(path: '/missing-container')
      pjax.req =
        status: 200
        responseText: '<main class="pjax" id="other"><p>wrong container</p></main>'
        getResponseHeader: -> null
        responseURL: ''
      pjax.redirect = -> redirected = true
      pjax.handleResponse()
      expect(pushed).to.equal true
      expect(redirected).to.equal true
    finally
      window.history.pushState = originalPush

  it 'reports apply error when inline script throws before morph', ->
    Pjax = loadPjaxFresh()
    captured = null
    pushed = false
    redirected = false
    handler = (e) -> captured = e.detail
    document.addEventListener 'pjax:render', handler
    originalPush = window.history.pushState
    window.history.pushState = -> pushed = true

    try
      pjax = new Pjax(path: '/bad-script')
      pjax.req =
        status: 200
        responseText: '<main class="pjax" id="pjax"><script>throw new Error("boom")</script></main>'
        getResponseHeader: -> null
        responseURL: ''
      pjax.redirect = -> redirected = true
      pjax.handleResponse()
      expect(captured.error).to.equal 'apply'
      expect(captured.status).to.equal 200
      expect(pushed).to.equal true
      expect(redirected).to.equal true
    finally
      window.history.pushState = originalPush
      document.removeEventListener 'pjax:render', handler

  it 'opts.replace forces replaceState instead of pushState', ->
    Pjax = loadPjaxFresh()
    pushed = null
    replaced = null
    originalPush = window.history.pushState
    originalReplace = window.history.replaceState
    window.history.pushState = (s, t, url) -> pushed = url
    window.history.replaceState = (s, t, url) -> replaced = url

    try
      Pjax._lastHrefCheck = '/something-else'
      pjax = new Pjax(path: '/replace-target', replace: true)
      pjax.historyAddCurrent('/replace-target')
      expect(replaced).to.equal '/replace-target'
      expect(pushed).to.be.null
    finally
      window.history.pushState = originalPush
      window.history.replaceState = originalReplace

describe 'Pjax.refresh and Pjax.reload bypass debounce', ->
  beforeEach ->
    setupGlobals()

  loadPjaxFresh = ->
    delete require.cache[require.resolve('../src/pjax.coffee')]
    require '../src/pjax.coffee'

  it 'instance load skips debounce when opts.force is true', ->
    Pjax = loadPjaxFresh()
    global.event = undefined
    Pjax.before = -> false
    Pjax.lastHref = '/same'
    Pjax._lastLoadTime = Date.now()
    pjax = new Pjax(path: '/same', force: true)
    result = pjax.load()
    expect(result).to.not.equal false
    expect(Pjax.lastHref).to.equal '/same'

  it 'instance load still debounces when opts.force is unset', ->
    Pjax = loadPjaxFresh()
    global.event = undefined
    Pjax.before = -> false
    Pjax.lastHref = '/same'
    Pjax._lastLoadTime = Date.now()
    pjax = new Pjax(path: '/same')
    result = pjax.load()
    expect(result).to.equal false

  it 'refresh adds force flag', ->
    Pjax = loadPjaxFresh()
    fetched = null
    Pjax.fetch = (opts) -> fetched = opts
    Pjax.refresh()
    expect(fetched.force).to.equal true

  it 'reload adds force flag', ->
    Pjax = loadPjaxFresh()
    fetched = null
    Pjax.fetch = (opts) -> fetched = opts
    Pjax.reload()
    expect(fetched.force).to.equal true

describe 'Form serialization (no Z dependency)', ->
  beforeEach ->
    setupGlobals()

  it 'getOpts serializes form with native FormData', ->
    delete require.cache[require.resolve('../src/pjax.coffee')]
    Pjax = require '../src/pjax.coffee'
    document.body.innerHTML = '''
      <main class="pjax" id="pjax">
        <form id="f" action="/submit">
          <input name="name" value="Anna">
          <input name="age" value="33">
        </form>
      </main>
    '''
    form = document.getElementById('f')
    opts = Pjax.getOpts '/submit', form: form
    expect(opts.path).to.include 'name=Anna'
    expect(opts.path).to.include 'age=33'
