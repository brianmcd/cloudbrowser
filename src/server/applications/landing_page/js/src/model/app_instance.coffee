class AppInstance
    constructor : (appInstanceConfig, @format) ->
        @api  = appInstanceConfig
        @id   = appInstanceConfig.getID()
        @name = appInstanceConfig.getName()
        @dateCreated = @format.date(appInstanceConfig.getDateCreated())
        @browserMgr = new CRUDManager(@format, Browser)
        @owner = null
        @collaborators = []

    removeCollaborator : (user) ->
        for c in @collaborators
            if c.email is user.email and c.ns is user.ns
                idx = @collaborators.indexOf(c)
                @collaborators.splice(idx, 1)
                break

    roles : [
        {
            name : 'can edit'
            , perm : 'readwrite'
            , checkMethods : ['isReaderWriter', 'isOwner']
            , grantMethod : 'addReaderWriter'
        }
    ]

    defaultRoleIndex : 0

# Exporting
this.AppInstance = AppInstance
