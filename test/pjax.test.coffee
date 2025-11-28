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
