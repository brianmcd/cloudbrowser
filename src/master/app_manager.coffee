###
the master side counterpart of application manager
###

class AppInstance
    constructor: (@_workerManager, @id, @workerId) ->
        @_browserMap = {}
    # appInstance could only reside on one machine, so no need to pass workerId    
    addBrowser : (bid, callback) ->
        @_browserMap[bid] = true
        callback null


class Application
    constructor: (@_workerManager, remoteApplication) ->
        {@mountPoint} = remoteApplication
        #@workers = {}
        @_appInstanceWorkerMap = {}
        @_appInstanceMap ={}
    
    #TODO register listeners in one call    
    registerAppInstance: (workerId, appInstanceId, callback) ->
        @_appInstanceWorkerMap[appInstanceId] = workerId
        @_appInstanceMap[appInstanceId] = new AppInstance(@_workerManager, appInstanceId, workerId)
        @_workerManager.registerAppInstance(@_appInstanceMap[appInstanceId])
        callback null, @_appInstanceMap[appInstanceId]

    addSubApp : (subApp) ->
        if not @subApps
            @subApps = {}
        @subApps[subApp.mountPoint]=subApp

    setParent : (parentApp)->
        @parentApp=parentApp

        



class AppManager
    constructor: (dependencies, callback) ->
        @_workerManager = dependencies.workerManager
        @_workerAppMap = {}
        # a map of mountPoint to applications
        @_applications ={}
        callback null, this

    #TODO register listeners in one call
    regsiterApp: (workerId, application, callback) ->
        # set some events on application
        @_workerAppMap[workerId]= application
        mountPoint = application.mountPoint
        if not @_applications[mountPoint]?
            #TODO need to setup parentApp/subApps etc..
            localApp = new Application(@_workerManager, application)
            if application.subApps?
                for subApp in application.subApps
                    localSubApp = new Application(@_workerManager, subApp)
                    @_applications[subApp.mountPoint] = localSubApp
                    localSubApp.setParent(localApp)
                    localApp.addSubApp(localSubApp)
                    @_workerManager.setupRoute(localSubApp)

            @_applications[mountPoint] = localApp
            
            @_workerManager.setupRoute(localApp)
        # right now every worker has the same set of applications
        #applications[mountPoint].registerWorker(workerId)
        # return the master side application
        callback null, localApp
        
    
module.exports = (dependencies, callback) ->
    new AppManager(dependencies, callback)