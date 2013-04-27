CBLandingPage           = angular.module("CBLandingPage", [])
Util                    = require('util')
#API
baseURL                 = "http://" + server.config.domain + ":" + server.config.port

CBLandingPage.controller "UserCtrl", ($scope, $timeout) ->

    Months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec']

    $scope.safeApply = (fn) ->
        phase = this.$root.$$phase
        if phase == '$apply' or phase == '$digest'
            if fn
                fn()
        else
            this.$apply(fn)

    formatDate = (date) ->
        if not date then return null
        month       = Months[date.getMonth()]
        day         = date.getDate()
        year        = date.getFullYear()
        hours       = date.getHours()
        timeSuffix  = if hours < 12 then 'am' else 'pm'
        hours       = hours % 12
        hours       = if hours then hours else 12
        minutes     = date.getMinutes()
        minutes     = if minutes > 10 then minutes else '0' + minutes
        time        = hours + ":" + minutes + " " + timeSuffix
        date        = day + " " + month + " " + year + " (" + time + ")"
        return date

    findInBrowserList = (id) ->
        browser = $.grep $scope.browserList, (element, index) ->
           (element.id is id)
        return browser[0]

    addToBrowserList = (browserId) ->
        if not findInBrowserList(browserId)
            browser = app.browsers.find(browserId)
            browser.date = formatDate(browser.dateCreated)
            browser.collaborators = getCollaborators(browser)
            browser.on 'UserAddedToList', (user, list) ->
                $scope.safeApply ->
                    browser.collaborators = getCollaborators(browser)
            $scope.safeApply ->
                $scope.browserList.push(browser)

    removeFromBrowserList = (id) ->
        $scope.safeApply ->
            $scope.browserList = $.grep $scope.browserList, (element, index) ->
                return(element.id isnt id)
            removeFromSelected(id)

    getCollaborators = (browser) ->
        # Must be in Utils
        inList = (user, list) ->
            userInList = list.filter (item) ->
                return(item.ns is user.ns and item.email is user.email)
            if userInList[0] then return userInList[0] else return null

        collaborators = []

        for readwriterRec in browser.getUsersInList('readwrite')

            #rename find to is?
            usr = browser.findUserInList(readwriterRec.user, 'own')

            if not usr and not inList(readwriterRec.user, collaborators)
                collaborators.push(readwriterRec.user)

        return collaborators

    toggleEnabledDisabled = (newValue, oldValue) ->
        # Make browserRec.permissions private
        isOwner = (callback) ->
            outstanding = $scope.selected.length
            for browserID in $scope.selected
                server.permissionManager.findBrowserPermRec $scope.user,
                $scope.mountPoint, browserID, (browserRec) ->
                    if not browserRec or not browserRec.permissions.own
                        $scope.safeApply ->
                            callback(false)
                    else outstanding--

            process.nextTick () ->
                if not outstanding
                    $scope.safeApply ->
                        callback(true)
                else process.nextTick(arguments.callee)

        # combine both isOwner and canRemove to one function
        canRemove = (callback) ->
            outstanding = $scope.selected.length
            for browserID in $scope.selected
                server.permissionManager.findBrowserPermRec $scope.user,
                $scope.mountPoint, browserID, (browserRec) ->
                    if not browserRec or not (browserRec.permissions.own or browserRec.permissions.remove)
                        $scope.safeApply ->
                            callback(false)
                    else outstanding--

            process.nextTick () ->
                if not outstanding
                    $scope.safeApply ->
                        callback(true)
                else process.nextTick(arguments.callee)

        if newValue > 0
            $scope.isDisabled.open          = false
            canRemove (val) ->
                if val
                    $scope.isDisabled.del           = false
                else
                    $scope.isDisabled.del           = true
            isOwner (val) ->
                if val
                    $scope.isDisabled.share         = false
                    $scope.isDisabled.rename        = false
                else
                    $scope.isDisabled.share         = true
                    $scope.isDisabled.rename        = true
        else
            $scope.isDisabled.open          = true
            $scope.isDisabled.del           = true
            $scope.isDisabled.rename        = true
            $scope.isDisabled.share         = true

    # API
    query               = Utils.searchStringtoJSON(location.search)
    $scope.domain       = server.config.domain
    $scope.port         = server.config.port
    $scope.mountPoint   = Utils.getAppMountPoint bserver.mountPoint, "landing_page"
    app                 = server.applicationManager.find $scope.mountPoint
    $scope.description  = app.description
    $scope.isDisabled   = {open:true, share:true, del:true, rename:true}
    $scope.browserList  = []
    $scope.selected     = []
    $scope.addingCollaborator = false
    $scope.predicate    = 'date'
    $scope.reverse      = true
    $scope.filterType   = 'all'
    # Email is obtained from the query parameters of the url
    # User details can not be obtained at the time of creation
    # as the user connects to the virtual browser only after
    # the browser has been created and initialized
    $scope.user         = {email:query.user, ns:query.ns}

    # Get the browsers associated with the user
    server.permissionManager.getBrowserPermRecs $scope.user, $scope.mountPoint, (browserRecs) ->
        for browserId, browserRec of browserRecs
            addToBrowserList(browserId)

    server.permissionManager.findAppPermRec $scope.user, $scope.mountPoint, (appRec) ->
        appRec.on 'ItemAdded', (id) ->
            addToBrowserList(id)
        appRec.on 'ItemRemoved', (id) ->
            removeFromBrowserList(id)

    $scope.$watch 'selected.length', (newValue, oldValue) ->
        toggleEnabledDisabled(newValue, oldValue)

    # Create a virtual browser
    $scope.createVB = () ->
        if $scope.user.email? and $scope.user.ns?
            # Make an object for current user using API
            app.browsers.create app, "", $scope.user, (err, bsvr) ->
                if err
                    $scope.safeApply ->
                        $scope.error = err.message
        else
            bserver.redirect baseURL + $scope.mountPoint + "/logout"

    # API
    $scope.logout = () ->
        bserver.redirect baseURL + $scope.mountPoint + "/logout"

    # Change behaviour based on type of click
    $scope.open = () ->

        openNewTab = (browserID) ->
            url = baseURL + $scope.mountPoint + "/browsers/" + browserID + "/index"
            win = window.open(url, '_blank')
            return

        for browserID in $scope.selected
            openNewTab(browserID)

    $scope.remove = () ->

        findBrowser = (app, browserID) ->
            vb = app.browsers.find(browserID)
            return vb

        rm = (browserID, user)->
            app.browsers.close findBrowser(app, browserID), user, (err) ->
                if not err
                    removeFromBrowserList(browserID)
                else
                    $scope.error = "You do not have the permission to perform this action"

        while $scope.selected.length > 0
            browserToBeDeleted = $scope.selected[0]
            if $scope.user.email? and $scope.user.ns?
                rm(browserToBeDeleted, $scope.user)
        $scope.confirmDelete = false

    findAndRemove = (user, list) ->
        for i in [0..list.length-1]
            if list[i].email is user.email and
            list[i].ns is user.ns
                break
        if i < list.length
            list.splice(i, 1)

    $scope.openCollaborateForm = () ->

        getProspectiveCollaborators = () ->
            server.db.collection app.dbName, (err, collection) ->
                collection.find {}, (err, cursor) ->
                    cursor.toArray (err, users) ->
                        throw err if err
                        if users?
                            for browserID in $scope.selected
                                for ownerRec in findInBrowserList(browserID).getUsersInList('own')
                                    if users.length then findAndRemove(ownerRec.user, users)
                                    else break
                                for readwriterRec in findInBrowserList(browserID).getUsersInList('readwrite')
                                    if users.length then findAndRemove(readwriterRec.user, users)
                                    else break
                        
                        $scope.safeApply ->
                            $scope.collaborators = users

        #toggle form
        $scope.addingCollaborator = !$scope.addingCollaborator
        if $scope.addingCollaborator
            $scope.addingOwner = false
            getProspectiveCollaborators()

    isOwner = (browser, user) ->
        if browser.findUserInList(user, 'own')
            return true
        else return false

    $scope.addCollaborator = () ->
        for browserID in $scope.selected
            browser = findInBrowserList(browserID)
            # Only if the user owns the browser allow adding of collaborators
            if isOwner(browser, $scope.user)
                server.permissionManager.addBrowserPermRec $scope.selectedCollaborator,
                $scope.mountPoint, browserID, {readwrite:true},
                (browserRec) ->
                    if browserRec
                        browser = findInBrowserList(browserRec.id)
                        browser.addUserToLists $scope.selectedCollaborator, {readwrite:true}, () ->
                            $scope.safeApply ->
                                $scope.boxMessage = "The selected browsers are now shared with " +
                                $scope.selectedCollaborator.email + " (" + $scope.selectedCollaborator.ns + ")"
                                $scope.addingCollaborator = false
                    else
                        throw new Error("Browser permission record for user " + $scope.user.email +
                        " (" + $scope.user.ns + ") and browser " + browserID + " not found")
            else
                $scope.error = "You do not have the permission to perform this action."

    # Combine openAddOwnerForm and openCollaborateForm
    $scope.openAddOwnerForm = () ->
        #toggle form
        getProspectiveOwners = () ->
            server.db.collection app.dbName, (err, collection) ->
                collection.find {}, (err, cursor) ->
                    cursor.toArray (err, users) ->
                        throw err if err
                        if users?
                            for browserID in $scope.selected
                                for ownerRec in findInBrowserList(browserID).getUsersInList('own')
                                    if users.length then findAndRemove(ownerRec.user, users)
                                    else break
                        
                        $scope.safeApply ->
                            $scope.owners = users

        #toggle form
        $scope.addingOwner = !$scope.addingOwner
        if $scope.addingOwner
            $scope.addingCollaborator = false
            getProspectiveOwners()

    #combine addOwner addCollaborator
    $scope.addOwner = () ->
        for browserID in $scope.selected
            browser = findInBrowserList(browserID)
            # Only if the user owns the browser allow adding of owners
            if isOwner(browser, $scope.user)
                server.permissionManager.addBrowserPermRec $scope.selectedOwner,
                $scope.mountPoint, browserID, {own:true, remove:true, readwrite:true},
                (browserRec) ->
                    if browserRec
                        browser = findInBrowserList(browserRec.id)
                        browser.addUserToLists $scope.selectedOwner, {own:true, remove:true, readwrite:true}, () ->
                            $scope.safeApply ->
                                $scope.boxMessage = "The selected browsers are now co-owned with " +
                                $scope.selectedOwner.email + " (" + $scope.selectedOwner.ns + ")"
                                $scope.addingOwner = false
                    else
                        throw new Error("Browser permission record for user " + $scope.user.email +
                        " (" + $scope.user.ns + ") and browser " + browserID + " not found")
            else
                $scope.error = "You do not have the permission to perform this action."

    addToSelected = (browserID) ->
        if $scope.selected.indexOf(browserID) is -1
            $scope.selected.push(browserID)

    removeFromSelected = (browserID) ->
        if $scope.selected.indexOf(browserID) isnt -1
            $scope.selected.splice($scope.selected.indexOf(browserID), 1)

    $scope.select = ($event, browserID) ->
        checkbox = $event.target
        if checkbox.checked then addToSelected(browserID) else removeFromSelected(browserID)

    $scope.selectAll = ($event) ->
        checkbox = $event.target
        action = if checkbox.checked then addToSelected else removeFromSelected
        for browser in $scope.browserList
            action(browser.id)

    $scope.getSelectedClass = (browserID) ->
        if $scope.isSelected(browserID)
            return 'highlight'
        else
            return ''

    $scope.isSelected = (browserID) ->
        return ($scope.selected.indexOf(browserID) >= 0)

    $scope.areAllSelected = () ->
        return $scope.selected.length is $scope.browserList.length

    $scope.rename = () ->
        for browserID in $scope.selected
            findInBrowserList(browserID).editing = true

    $scope.clickRename = (browserID) ->
        browser = findInBrowserList(browserID)
        if isOwner(browser, $scope.user)
            browser.editing = true
        
CBLandingPage.filter "removeSlash", () ->
    return (input) ->
        mps = input.split('/')
        return mps[mps.length - 1]

CBLandingPage.filter "browserFilter", () ->
    return (list, arg) =>
        filterType = arg.type
        user = arg.user
        modifiedList = []
        if filterType is 'owned'
            for browser in list
                if browser.findUserInList(user, 'own')
                    modifiedList.push(browser)
        if filterType is 'notOwned'
            for browser in list
                if browser.findUserInList(user, 'readwrite') and
                not browser.findUserInList(user, 'own')
                    modifiedList.push(browser)
        if filterType is 'shared'
            for browser in list
                if browser.getUsersInList('readwrite').length > 1 or
                browser.getUsersInList('own').length > 1
                    modifiedList.push(browser)
        if filterType is 'notShared'
            for browser in list
                if browser.getUsersInList('own').length is 1 and
                browser.getUsersInList('readwrite').length is 1
                    modifiedList.push(browser)
        if filterType is 'all'
            modifiedList = list
        return modifiedList

