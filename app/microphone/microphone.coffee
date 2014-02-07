navigator.getUserMedia =
  navigator.getUserMedia ||
  navigator.webkitGetUserMedia ||
  navigator.mozGetUserMedia ||
  navigator.msGetUserMedia

window.AudioContext =
  window.AudioContext ||
  window.webkitAudioContext ||
  window.mozAudioContext ||
  window.msAudioContext

log = if /debug/.test(window.location.search)
  (-> console.log.apply(console, arguments))
else
  ->

WitError = (message, infos) ->
  @name = "WitError"
  @message = (message || "")
  @infos = infos
  return @
WitError.prototype = Error.prototype

WEBSOCKET_HOST = 'wss://api.wit.ai/speech_ws'

Microphone = (elem) ->
  # setup HTML element
  if elem
    @elem = elem

    elem.innerHTML = """
      <div class='mic icon-wit-mic'>
      </div>
    """
    elem.className = 'wit-microphone'
    elem.addEventListener 'click', (e) =>
      @fsm('toggle_record')

  # object state
  @conn  = null
  @ctx   = new AudioContext()
  @state = 'disconnected'

  # methods
  @handleError = (e) ->
    if _.isFunction(f = @onerror)
      err = if _.isString(e)
        e
      else if _.isString(e.message)
        e.message
      else
        "Something went wrong!"

      f.call(window, err)
  @handleResult = (res) ->
    if _.isFunction(f = @onresult)
      intent   = res.outcome.intent
      entities = res.outcome.entities
      f.call(window, intent, entities, res)

  # DOM methods
  @rmactive = ->
    if @elem
      @elem.firstChild.classList.remove('active')
  @mkactive = ->
    if @elem
      @elem.firstChild.classList.add('active')

  return this

states =
  disconnected:
    connect: (token) ->
      if not token
        @handleError('No token provided')

      # websocket
      conn = new WebSocket(WEBSOCKET_HOST)
      conn.onopen = (e) =>
        conn.send(JSON.stringify(["auth", token]))
      conn.onclose = (e) =>
        @fsm('socket_closed')
      conn.onmessage = (e) =>
        [type, data] = JSON.parse(e.data)

        if data
          @fsm.call(this, type, data)
        else
          @fsm.call(this, type)

      @conn = conn
      'connecting'
  connecting:
    'auth-ok': -> 'ready'
    error: (err) ->
      @handleError(err)
      'connecting'
    socket_closed: -> 'disconnected'
  ready:
    socket_closed: -> 'disconnected'
    start: -> @fsm('toggle_record')
    toggle_record: ->
      on_stream = (stream) =>
        @conn.send(JSON.stringify(["start"]))

        ctx  = @ctx
        src  = ctx.createMediaStreamSource(stream)
        proc = (ctx.createScriptProcessor || ctx.createJavascriptNode).call(ctx, 4096, 1, 1)
        proc.onaudioprocess = (e) =>
          bytes = e.inputBuffer.getChannelData(0)
          @conn.send(bytes)

        src.connect(proc)
        proc.connect(ctx.destination)

        @cleanup = ->
          src.disconnect()
          proc.disconnect()
          stream.stop()

        @fsm('got_stream')

      navigator.getUserMedia(
        { audio: true },
        on_stream,
        @handleError
      )
      'waiting_for_stream'
  waiting_for_stream:
    got_stream: ->
      @mkactive()
      'audiostart'
  audiostart:
    error: (data) ->
      @handleError(new WitError("Error during recording", data: data))
      'ready'
    socket_closed: ->
      @rmactive()
      'disconnected'
    stop: -> @fsm('toggle_record')
    toggle_record: ->
      if _.isFunction(f = @cleanup)
        f()
        @cleanup = null

      @rmactive()
      @conn.send(JSON.stringify(["stop"]))

      'audioend'
  audioend:
    socket_closed: -> 'disconnected'
    error: (data) ->
      @handleError(new WitError('Wit did not recognize intent', {data: data}))
      'ready'
    result: (data) ->
      @handleResult(data)
      'ready'

Microphone.prototype.fsm = (event) ->
  f   = states[@state]?[event]
  ary = Array.prototype.slice.call(arguments, 1)
  if _.isFunction(f)
    s   = f.apply(this, ary)
    log "fsm: #{@state} + #{event} -> #{s}", ary
    @state = s

    if s in ['audiostart', 'audioend', 'ready']
      if _.isFunction(f = this['on' + s])
        f.call(window)
  else
    log "fsm error: #{@state} + #{event}", ary

  s

Microphone.prototype.connect = (token) ->
  @fsm('connect', token)

Microphone.prototype.start = ->
  @fsm('start')

Microphone.prototype.stop = ->
  @fsm('stop')

# utils
window._     ||= {}
_.isFunction ||= (x) -> (typeof x) == 'function'
_.isString   ||= (obj) -> toString.call(obj) == '[object String]'

window.Wit   ||= {}
Wit.Microphone = Microphone
