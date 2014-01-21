document.addEventListener 'DOMContentLoaded', (e) ->
  opts =
    onError: (err) ->
      console.log err
    onResult: (data) ->
      console.log data

  comp = (Wit.Recorder opts)
  React.renderComponent comp, document.getElementById('recorder')

  comp.auth("d617e4bc-07b4-45ba-b7f3-5f6dc396ffc6")
