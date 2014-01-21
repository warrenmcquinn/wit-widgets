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
    if not token
      return
      
    # websocket
    conn = new WebSocket(WEBSOCKET_HOST)
    conn.onopen = (e) =>
      @setState(connected: true)
      conn.send(JSON.stringify(["auth", token]))
    conn.onclose = (e) ->
      @setState(connected: false)
    conn.onmessage = @handleMessage

    @state.conn = conn
  toggleRecord: (e) ->
    if not @isConnected()
      return

    if not @isRecording()
      on_stream = (stream) =>
        @state.conn.send(JSON.stringify(["start"]))

        ctx  = new AudioContext()
        src  = ctx.createMediaStreamSource(stream)
        proc = (ctx.createScriptProcessor || ctx.createJavascriptNode).call(ctx, 4096, 1, 1)
        proc.onaudioprocess = (e) =>
          bytes = e.inputBuffer.getChannelData(0)
          @state.conn.send(bytes)

        src.connect(proc)
        proc.connect(ctx.destination)

        if _.isFunction(f = @props.onStartRecording)
          f()

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
    else
      if _.isFunction(f = @state.cleanup)
        f()
        @state.cleanup = null

      @state.conn.send(JSON.stringify(["stop"]))

      if _.isFunction(f = @props.onStopRecording)
        f()

      @setState(state: 'processing')

  # Private API
  displayName: 'Recorder'
  getInitialState: ->
    state: 'wait'
  componentWillMount: ->
    yes
  componentDidMount: (rootNode) ->
    if _.isFunction(f = @props.onComponentDidMount)
      f(rootNode)
  isConnected: -> !!@state.connected
  isRecording: -> @state.state == 'recording'
  isProcessing: -> @state.state == 'processing'
  handleError: (e) ->
    if _.isFunction(f = @props.onError)
      f(e)
    else
      console.error('Something went wrong', e)
  handleMessage: (e) ->
    data = JSON.parse(e.data)
    # if not once
    #   data =
    #     msg_body: "Order fooooood"
    #     msg_id: "fooo"
    #     outcome:
    #       intent: "order"
    #       entities:
    #         item: [
    #           {
    #             name: "Margherita Pizza"
    #             price: 10.99
    #             qty: 1
    #           },
    #           {
    #             name: "Chicken Wings"
    #             price: 2
    #             qty: 6
    #           }
    #         ]
    #   once = true
    # else
    #   data =
    #     msg_body: "I live in Palo Alto"
    #     msg_id: "fooo"
    #     outcome:
    #       intent: "location"
    #       entities:
    #         location:
    #           body: "Palo Alto"
    #           value: "Palo Alto"

    if data.fail
      @handleError(new WitError('Wit did not recognize intent', {data: data}))
      @setState(state: 'wait')
      return

    @props.onResult(data)
    @setState(state: 'wait')
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

    status = if not @isConnected()
      "disconnected"
    else if @isRecording()
      "recording..."
    else if @isProcessing()
      "processing..."
    else
      "click"

    ch.push(span {key: 'status', className: 'mic-status'}, status)

    (div {className: 'recorder'}, ch)
})

# utils
_.isFunction = (x) -> (typeof x) == 'function'
