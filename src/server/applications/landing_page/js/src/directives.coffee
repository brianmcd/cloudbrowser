Async    = require('async')
NwGlobal = require('nwglobal')

app = angular.module('CBLandingPage.directives', [])
curVB = cloudbrowser.currentBrowser
appConfig = curVB.getAppConfig()

app.directive 'cbTypeahead', () ->

    pruneList = (users, scope) ->
        newList = []
        {role, entity} = scope.shareForm

        # Synchronous version of pruning
        shouldAdd = true
        for user in users
            if user is scope.user then continue
            for method in role.checkMethods
                if entity.api[method](user)
                    shouldAdd = false
                    break
            if shouldAdd then newList.push(user)
        return newList
        ###
        # Asynchronous version of pruning
        Async.each users, (user, callback) ->
            waterfallMethods = NwGlobal.Array()
            # Removing self from list
            waterfallMethods.push (next) ->
                if scope.user is user then callback(null, false)
                else next(null, true)

            for method in role.checkMethods
                do (method) ->
                    waterfallMethods.push (dontIncludeInList, next) ->
                        entity.api[method](user, next)
                    waterfallMethods.push (dontIncludeInList, next) ->
                        if dontIncludeInList then callback(null, false)
                        # Required for the final callback to check if it must include
                        # the user in the list or not
                        else next(null, true)

            Async.waterfall waterfallMethods, (err, include) ->
                return callback(err) if err
                if include then newList.push(user)
                callback(null)
        , (err) ->
            callback(err, newList)
        ###

    return (scope, element, attrs) ->
        $(element).typeahead
            source : (query, process) ->
                appConfig.getUsers (err, users) ->
                    if err then scope.safeApply -> scope.setError(err)
                    else process(pruneList(users, scope))
            updater : (item) ->
                scope.$apply(attrs.ngModel + " = '#{item}'")
                return item

app.directive 'cbHasfocus', () ->
    return (scope, element, attrs) ->
        scope.$watch attrs.cbHasfocus, (nVal, oVal) ->
            if (nVal) then element[0].focus()
        element.bind 'blur', () ->
            scope.$apply(
                attrs.cbHasfocus + " = false"
                scope.browser.api.rename(scope.browser.name)
            )
        element.bind 'keydown', (e) ->
            if e.which is 13 then scope.$apply(
                attrs.cbHasfocus + " = false"
                scope.browser.api.rename(scope.browser.name)
            )
