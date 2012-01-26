page = new WebPage()

page.onConsoleMessage = (msg) ->
    if /Error/.test(msg)
        console.log(msg)

page.open "http://localhost:3000", (status) ->
    if status != 'success'
        console.log("Failed to load page.")
