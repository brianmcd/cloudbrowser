$ ->
    $("#box").append("TESTING")
    $("#box2").load 'http://localhost:3001/ajax.html', (responseText, textStatus, xhr) ->
        console.log "AJAX load finished."
        console.log "responseText: #{responseText}"
        console.log "textStatus: #{textStatus}"
        console.log "xhr:"
        console.log xhr
        console.log xhr.getAllResponseHeaders()
