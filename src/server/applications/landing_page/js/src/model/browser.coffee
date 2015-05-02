# This class is needed to clone the browser object so that
# angular can attach its $$hashkey custom properties on the
# cloned browser object instead of on the frozen browser object
class Browser
    constructor : (browserConfig, format) ->
        @api  = browserConfig
        @id   = browserConfig.getID()
        @name = browserConfig.getName()
        @editing = false
        @redirect = () ->
            curVB = cloudbrowser.currentBrowser
            curVB.redirect(browserConfig.getURL())
        @dateCreated = format(browserConfig.getDateCreated())
        @owners        = @api.getOwners()
        @readers       = @api.getReaders()
        @readerwriters = @api.getReaderWriters()

    updateUsers : (callback) ->
        @api.getUsers((err,result)=>
            return callback(err) if err?
            {@owners, @readers, @readerwriters} =result
            callback null
        )
        
    roles : [
        {
            name : 'is owner'
            , perm : 'own'
            , checkMethods : ['isOwner']
            , grantMethod : 'addOwner'
        }
        {
            name : 'can edit'
            , perm : 'readwrite'
            , checkMethods : ['isReaderWriter', 'isOwner']
            , grantMethod : 'addReaderWriter'
        }
        {
            name : 'can read'
            , perm : 'readonly'
            , checkMethods : ['isReader', 'isReaderWriter', 'isOwner']
            , grantMethod : 'addReader'
        }
    ]

    defaultRoleIndex : 1

# Exporting
this.Browser = Browser
