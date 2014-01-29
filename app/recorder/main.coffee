document.addEventListener 'DOMContentLoaded', (e) ->
  opts =
    verbose: true
    onError: (err) ->
      console.log err
    onResult: (data) ->
      console.log data
    onReady: ->
      console.log "ready"
    onRecording: ->
      console.log "record"
    onProcessing: ->
      console.log "proces"

  comp = (Wit.Recorder opts)
  React.renderComponent comp, document.getElementById('recorder')

  token = localStorage.getItem('wit_token')
  console.log "Auth with #{token}"
  comp.auth(token)
