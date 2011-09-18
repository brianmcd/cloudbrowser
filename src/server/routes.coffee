fs   = require('fs')
eco  = require('eco')
path = require('path')
# Sets up the routes for our front end express HTTP server.
# server is the instance of the Server class.
# http is the express web server.
exports.applyRoutes = (server, http) ->
    # Routes
    http.get '/', (req, res) =>
        fs.readdir server.staticDir, (err, files) ->
            throw err if err
            indexPath = path.join(__dirname, '..', '..', 'views', 'index.html.eco')
            fs.readFile indexPath, 'utf8', (err, str) ->
                throw err if err
                tmpl = eco.render str,
                    browsers : server.browsers.browsers
                    files : files.filter((file) -> /\.html$/.test(file)).sort()
                res.send(tmpl)

    http.get '/browsers/:browserid/index.html', (req, res) ->
        # TODO: permissions checking and making sure browserid exists would
        # go here.
        id = decodeURIComponent(req.params.browserid)
        console.log "Joining: #{id}"
        res.render 'base.jade', browserid : id

    http.get '/browsers/:browserid/:resourceid', (req, res) =>
        resourceid = req.params.resourceid
        browser = server.browsers.find(decodeURIComponent(req.params.browserid))
        # Note: fetch calles res.end()
        browser.resources.fetch(resourceid, res)

    http.get '/getHTML/:browserid', (req, res) =>
        console.log "browserID: #{req.params.browserid}"
        browser = server.browsers.find(decodeURIComponent(req.params.browserid))
        res.send(browser.window.document.outerHTML)

    http.get '/getText/:browserid', (req, res) =>
        console.log "browserID: #{req.params.browserid}"
        browser = server.browsers.find(decodeURIComponent(req.params.browserid))
        res.contentType('text/plain')
        res.send(browser.window.document.outerHTML)

    http.get '/browserList', (req, res) =>
        res.writeHead(200, {'Content-Type' : 'application/json'})
        # TODO: this should be cached in BrowserManager instead of scanning
        # browsers object each time.
        browsers= []
        for browserid, browser of server.browsers.browsers
            browsers.push(browserid)
        res.end(JSON.stringify(browsers))

    http.post '/create', (req, res) =>
        browserInfo = req.body.browser
        id = browserInfo.id
        runscripts = (browserInfo.runscripts? && (browserInfo.runscripts == 'yes'))
        resource = null
        if typeof browserInfo.url != 'string' || browserInfo.url == ''
            resource = "http://localhost:3001/#{browserInfo.localfile}"
        else
            resource = browserInfo.url
        console.log "Creating id=#{id} Loading url= #{resource}"
        try
            server.browsers.create(id, resource)
            console.log 'BrowserInstance loaded.'
            res.writeHead(301, {'Location' : "/browsers/#{id}/index.html"})
            res.end()
        catch e
            console.log "browsers.create failed"
            console.log e
            console.log e.stack
            send500Error(res)

    send500Error = (res) ->
        res.writeHead 500, {'Content-type': 'text/html'}
        res.end()
