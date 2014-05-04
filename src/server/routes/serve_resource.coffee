{getMountPoint} = require('./route_helpers')

class ServeResourceRoute
    constructor: (@appManager) ->
        # ...
    
    handler : (req, res, next) ->
        mountPoint = getMountPoint(req.url)
        resourceID = req.params.resourceID
        decoded = decodeURIComponent(req.params.browserID)
        bserver = @appManager.find(mountPoint)?.browsers.find(decoded)
        # Note: fetch calls res.end()
        bserver?.resources.fetch(resourceID, res)

module.exports = ServeResourceRoute
