{i, img, p, span, a, input, textarea, div, table, tbody, tr, td, ul, li} = React.DOM

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

window._   ||= {}
window.Wit ||= {}

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

Wit.Recorder = React.createClass({
  # Public API
  auth: (token) ->
    @fsm('auth', token)
  toggleRecord: (e) ->
    @fsm('toggle_record')

  # Private API
  displayName: 'Recorder'
  propTypes:
    onResult: React.PropTypes.func.isRequired
  getDefaultProps: ->
    verbose: false
  getInitialState: ->
    state: 'disconnected'
  componentWillMount: ->
    @state.ctx = new AudioContext()
    yes
  componentDidMount: (rootNode) ->
    if _.isFunction(f = @props.onComponentDidMount)
      f(rootNode)
  componentWillUpdate: (nextProps, nextState) ->
    next_state = nextState.state
    if @state.state != next_state
      handler = 'on' + next_state[0].toUpperCase() + next_state[1..]
      if _.isFunction(f = @props[handler])
        f()
  isReady: -> @state.state == 'ready'
  isRecording: -> @state.state == 'recording'
  isProcessing: -> @state.state == 'processing'
  fsmMap:
    disconnected:
      auth: (token) ->
        if not token
          @handleError('No token provided')

        # websocket
        conn = new WebSocket(WEBSOCKET_HOST)
        conn.onopen = (e) =>
          @setState(state: 'connected')
          conn.send(JSON.stringify(["auth", token]))
        conn.onclose = (e) =>
          @setState(state: 'disconnected')
        conn.onmessage = (e) =>
          [type, data] = JSON.parse(e.data)
          log "> Message", type, data

          if type == "error"
            @handleError(new WitError('Wit did not recognize intent', {data: data}))
            @setState(state: 'ready')
          else
            @fsm.call(this, type, data)

        @setState(conn: conn)
    connected:
      'auth-ok': -> 'ready'
    ready:
      toggle_record: ->
        on_stream = (stream) =>
          @state.conn.send(JSON.stringify(["start"]))

          ctx  = @state.ctx
          src  = ctx.createMediaStreamSource(stream)
          proc = (ctx.createScriptProcessor || ctx.createJavascriptNode).call(ctx, 4096, 1, 1)
          proc.onaudioprocess = (e) =>
            bytes = e.inputBuffer.getChannelData(0)
            @state.conn.send(bytes)

          src.connect(proc)
          proc.connect(ctx.destination)

          @state.cleanup = ->
            src.disconnect()
            proc.disconnect()
            stream.stop()

          @setState(state: 'recording')

        navigator.getUserMedia(
          { audio: true },
          on_stream,
          @handleError
        )
    recording:
      toggle_record: ->
        if _.isFunction(f = @state.cleanup)
          f()
          @state.cleanup = null

        @state.conn.send(JSON.stringify(["stop"]))
        'processing'
    processing:
      diag: (data) ->
        @props.onResult(data)
        'ready'
  fsm: (cmd) ->
    if _.isFunction(f = @fsmMap[@state.state]?[cmd])
      args = Array.prototype.slice.call(arguments, 1)
      new_state = f.apply(this, args)
      if _.isString(new_state)
        log "fsm: #{@state.state} + #{cmd} -> #{new_state}"
        @setState(state: new_state)
      else
        log "fsm: #{@state.state} + #{cmd}"
    else
      log "fsm: #{@state.state} + #{cmd}"
  handleError: (e) ->
    if _.isFunction(f = @props.onError)
      f(e)
    else
      console.error('Something went wrong', e)
  render: ->
    classes = if @isRecording()
      "icon-microphone active"
    else
      "icon-microphone"

    ch = [
      (div
        key: 'mic'
        className: "mic #{classes}"
        onClick: @toggleRecord)
    ]

    if @props.verbose
      ch.push(span {key: 'status', className: 'mic-status'}, @state.state)

    (div {className: 'recorder'}, ch)
})

# utils
_.isFunction = (x) -> (typeof x) == 'function'
_.isString = (obj) -> toString.call(obj) == '[object String]'
