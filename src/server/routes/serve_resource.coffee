{getMountPoint} = require('./route_helpers')

module.exports = (req, res, next) ->
    CBServer   = require('../')
    appManager = CBServer.getAppManager()
    mountPoint = getMountPoint(req.url)
    resourceID = req.params.resourceID
    decoded = decodeURIComponent(req.params.browserID)
    bserver = appManager.find(mountPoint)?.browsers.find(decoded)
    # Note: fetch calls res.end()
    bserver?.resources.fetch(resourceID, res)
