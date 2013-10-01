class SharedState
    constructor : (sharedStateConfig, @format, @scope) ->
        @api  = sharedStateConfig
        @id   = sharedStateConfig.getID()
        @name = sharedStateConfig.getName()
        @browsers = []
        @dateCreated = @format.date(sharedStateConfig.getDateCreated())
        @addBrowser  = () ->
            sharedStateConfig.createVirtualBrowser (err) =>
                if not err then return
                @scope.safeApply =>
                    @scope.setError(err)
                    @processing = false

        @api.getOwner (err, owner) =>
            @scope.safeApply =>
                if err then @scope.setError(err)
                else @owner = owner

        @api.getReaderWriters (err, readerWriters) =>
            @scope.safeApply =>
                if err then @scope.setError(err)
                else @collaborators = readerWriters

    addBrowserToList : (browserConfig, scope) ->
        browser = new Browser(browserConfig, scope, @format)
        @browsers.push(browser)

    removeBrowserFromList : (id) ->
        for b in @browsers when b.id is id
            idx = @browsers.indexOf(b)
            @browsers.splice(idx, 1)

    roles : [
        {
            name : 'can edit'
            , perm : 'readwrite'
            , checkMethods : ['isReaderWriter', 'isOwner']
            , grantMethod : 'addReaderWriter'
        }
    ]

    defaultRoleIndex : 0

class SharedStateManager
    constructor : (@scope, @format) ->
        @sharedStates = []

    find : (id) ->
        return s for s in @sharedStates when s.id is id

    add : (sharedStateConfig, scope) ->
        sharedState = @find(sharedStateConfig.getID())
        if sharedState then return sharedState

        sharedState = new SharedState(sharedStateConfig, @format, scope)
        @sharedStates.push(sharedState)

        return sharedState

    remove : (sharedState) ->
        sharedState.api.close (err) =>
            @scope.safeApply =>
                if err then @scope.setError(err)
                else
                    idx = @sharedStates.indexOf(sharedState)
                    return @sharedStates.splice(idx, 1)

    create : (scope) ->
        curVB = cloudbrowser.currentVirtualBrowser
        appConfig = curVB.getAppConfig()

        appConfig.createSharedState (err, sharedStateConfig) =>
            @scope.safeApply =>
                if err then @scope.setError(err)
                else @add(sharedStateConfig, scope)

# Exporting
this.SharedStateManager = SharedStateManager
