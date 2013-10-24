filters = angular.module('CBLandingPage.filters', [])
# Is going to be turned into a directive
browserFilter = (app) ->
    return () ->
        return (list, arg) =>
            filterType = arg.type
            user = new app.User(arg.user.email, arg.user.ns)
            modifiedList = []
            switch filterType
                when 'owned'
                    (do(vb) ->
                        Async.waterfall NwGlobal.Array(
                            (next) ->
                                vb.api.isOwner(user, next)
                            (isOwner, next) ->
                                if isOwner then modifiedList.push(vb)
                        ), (err) ->
                            if err then $scope.safeApply -> $scope.setError(err)
                    ) for vb in list
                when 'notOwned'
                    (do(vb) ->
                        Async.waterfall NwGlobal.Array(
                            (next) ->
                                vb.api.isOwner(user, next)
                            (isOwner, next) ->
                                if not isOwner then modifiedList.push(vb)
                                next(null)
                        ), (err) ->
                            if err then $scope.safeApply -> $scope.setError(err)
                    ) for vb in list
                when 'shared'
                    (do(vb) ->
                        Async.waterfall NwGlobal.Array(
                            (next) ->
                                vb.api.getNumReaderWriters(next)
                            (numReaderWriters, next) ->
                                if numReaderWriters
                                    modifiedList.push(vb)
                                    # Bypass the waterfall
                                    callback(null)
                                else
                                    vb.api.getNumOwners(next)
                            (numOwners, next) ->
                                if numOwners > 1 then modifiedList.push(vb)
                                next(null)
                        ), (err) ->
                            if err then $scope.safeApply -> $scope.setError(err)
                    ) for vb in list
                when 'notShared'
                    (do(vb) ->
                        Async.waterfall NwGlobal.Array(
                            (next) ->
                                vb.api.getNumOwners(next)
                            (numOwners, next) ->
                                if numOwners is 1
                                    vb.api.getNumReaderWriters(next)
                                # Bypass the waterfall
                                else callback(null)
                            (numReaderWriters, next) ->
                                if not numReaderWriters then modifiedList.push(vb)
                                next(null)
                        ), (err) ->
                            if err then $scope.safeApply -> $scope.setError(err)
                            else return modifiedList
                    ) for vb in list
                when 'all'
                    modifiedList = list
            return modifiedList
