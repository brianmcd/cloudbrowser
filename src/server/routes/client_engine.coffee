module.exports = (req, res, next) ->
    CBServer = require('../')
    httpServer = CBServer.getHttpServer()
    config     = CBServer.getConfig()
    res.statusCode = 200
    res.setHeader('Last-Modified', httpServer.getClientEngineModified())
    res.setHeader('Content-Type', 'text/javascript')
    if config.compressJS then res.setHeader('Content-Encoding', 'gzip')
    res.end(httpServer.getClientEngineJS())
