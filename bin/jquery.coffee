page = new WebPage()

page.onConsoleMessage = (msg) ->
    if /Error/.test(msg)
        console.log(msg)

url = phantom.args[0] || "http://localhost:3000"

page.open url, (status) ->
    if status != 'success'
        console.log("Failed to load page.")
