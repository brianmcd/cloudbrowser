# This class is needed to clone the browser object so that
# angular can attach its $$hashkey custom properties on the
# cloned browser object instead of on the frozen browser object
class Browser
    constructor : (browserConfig, format) ->
        @id            = browserConfig.getID()
        @workerId      = browserConfig.getWorkerID()
        @api           = browserConfig
        @name          = browserConfig.getName()
        @dateCreated   = format.date(browserConfig.getDateCreated())
        @appInstanceID = browserConfig.getAppInstanceId()
        @connectedClientMgr = new POJOListManager(null, 'address')
        # Note: assignment not equality check
        if (clients = browserConfig.getConnectedClients())
            @connectedClientMgr.add(client) for client in clients
        if browserConfig.getAppConfig().isAuthConfigured()
            @creator = browserConfig.getCreator()
            @updateUsers()

    updateUsers : () ->
        @owners        = @api.getOwners()
        @readers       = @api.getReaders()
        @readerwriters = @api.getReaderWriters()

# Exporting
this.Browser = Browser
