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

  it 'defers scripts with delay attribute via requestAnimationFrame', ->
    Pjax = loadPjax()
    window.__delayTest = 0
    html = '<div><script delay="true">window.__delayTest = 1</script></div>'
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
    window.pjaxOnclickBinded = undefined

    Pjax.onDocumentClick()
    expect(window.pjaxOnclickBinded).to.equal true

    # calling again should not throw or rebind
    Pjax.onDocumentClick()
    expect(window.pjaxOnclickBinded).to.equal true

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
