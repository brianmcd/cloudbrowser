class AppMaster
    constructor: (dependencies, callback) ->
        callback null, this
    
    getRequestAppInfo : (path) ->
        instanceAssigned = /\/browsers\/[0-9]+\//.test(path)
        if (not path?) or path is '/' or path.length ==0
            defaultPage = '/'
        else
            matchAppStr = /\/[A-z|0-9]+/.exec(path)
            if matchAppStr?
                defaultPage = matchAppStr[0]
            else
                # paths like 'a.html, b.jpg'
                defaultPage = path
            
            
        {instanceAssigned:instanceAssigned, defaultPage : defaultPage}

module.exports = (dependencies, callback) ->
    new AppMaster(dependencies, callback)