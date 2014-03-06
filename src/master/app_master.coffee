class AppMaster
    constructor: (dependencies, callback) ->
        # ...
    
    getRequestAppInfo : (path) ->
        instanceAssigned = /\/browsers\/[0-9]+\//.test(path)
        matchAppStr = /\/[A-z|0-9]+/.exec(path)
        defaultPage = matchAppStr[0]
        {instanceAssigned:instanceAssigned, defaultPage : defaultPage}