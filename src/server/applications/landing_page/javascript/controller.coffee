CBLandingPage           = angular.module("CBLandingPage", [])
Util                    = require('util')
#API
baseURL                 = "http://" + server.config.domain + ":" + server.config.port

CBLandingPage.controller "UserCtrl", ($scope, $timeout) ->

    Months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec']

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

    # When some other user deletes a browser co-owned or shared by this user
    # update the $scope.selected array too
    getBrowsers = (browserList, user, mp) ->
        server.permissionManager.getBrowserPermRecs user, mp, (browserRecs) ->
            for browserId, browserRec of browserRecs
                browser = app.browsers.find(browserId)
                browser.date = formatDate(browser.dateCreated)
                browser.collaborators = getCollaborators(browser)
                browserList[browserId] = browser

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
            outstanding = $scope.selected.number
            for browserID in $scope.selected.browserIDs
                server.permissionManager.findBrowserPermRec {email:$scope.email, ns:namespace},
                $scope.mountPoint, browserID, (browserRec) ->
                    if not browserRec or not browserRec.permissions.own
                        callback(false)
                    else outstanding--

            process.nextTick () ->
                if not outstanding
                    callback(true)
                else process.nextTick(arguments.callee)

        # combine both isOwner and canRemove to one function
        canRemove = (callback) ->
            outstanding = $scope.selected.number
            for browserID in $scope.selected.browserIDs
                server.permissionManager.findBrowserPermRec {email:$scope.email, ns:namespace},
                $scope.mountPoint, browserID, (browserRec) ->
                    if not browserRec or not (browserRec.permissions.own or browserRec.permissions.remove)
                        callback(false)
                    else outstanding--

            process.nextTick () ->
                if not outstanding
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
    namespace           = query.ns
    app                 = server.applicationManager.find $scope.mountPoint
    $scope.description  = app.description
    # Email is obtained from the query parameters of the url
    # User details can not be obtained at the time of creation
    # as the user connects to the virtual browser only after
    # the browser has been created and initialized
    $scope.email        = query.user

    $scope.isDisabled   = {open:true, share:true, del:true, rename:true}
    # Is the second level object really required?
    $scope.selected     = {browserIDs:[], number:0}
    # Array not Object
    $scope.browserList  = {}
    $scope.addingCollaborator = false

    # Get the browsers associated with the user
    repeatedlyGetBrowsers = () ->
        $timeout ->
            $scope.browserList = {}
            getBrowsers($scope.browserList, {email:$scope.email, ns:namespace}, $scope.mountPoint)
            repeatedlyGetBrowsers()
            null        # avoid memory leak, see https://github.com/angular/angular.js/issues/1522#issuecomment-15921753
        , 100

    repeatedlyGetBrowsers()

    # Is number really required?
    $scope.$watch 'selected.number', (newValue, oldValue) ->
        toggleEnabledDisabled(newValue, oldValue)

    # Create a virtual browser
    $scope.createVB = () ->
        if $scope.email
            # Make an object for current user using API
            app.browsers.create app, "", {email:$scope.email, ns:namespace}, (bsvr) ->
                if bsvr
                    bsvr.date = formatDate(bsvr.dateCreated)
                    $scope.browserList[bsvr.id] = bsvr
                else
                    $scope.error = "Permission Denied"
        else
            $scope.error = "Permission Denied"

    # API
    $scope.logout = () ->
        bserver.redirect baseURL + $scope.mountPoint + "/logout"

    # Change behaviour based on type of click
    $scope.open = () ->

        openNewTab = (browserID) ->
            url = baseURL + $scope.mountPoint + "/browsers/" + browserID + "/index"
            win = window.open(url, '_blank')
            return

        for browserID in $scope.selected.browserIDs
            openNewTab(browserID)

    $scope.remove = () ->

        findBrowser = (app, browserID) ->
            vb = app.browsers.find(browserID)
            return vb

        rm = (browserID, user)->
            app.browsers.close findBrowser(app, browserID), user, (err) ->
                if not err
                    delete $scope.browserList[browserID]
                    $scope.selected.browserIDs.splice(0, 1)
                    $scope.selected.number--
                else
                    $scope.error = err

        while $scope.selected.browserIDs.length > 0
            browserToBeDeleted = $scope.selected.browserIDs[0]
            if $scope.email?
                rm(browserToBeDeleted, {email:$scope.email, ns:namespace})

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
                            for browserID in $scope.selected.browserIDs
                                for ownerRec in $scope.browserList[browserID].getUsersInList('own')
                                    if users.length then findAndRemove(ownerRec.user, users)
                                    else break
                                for readwriterRec in $scope.browserList[browserID].getUsersInList('readwrite')
                                    if users.length then findAndRemove(readwriterRec.user, users)
                                    else break
                        
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
        for browserID in $scope.selected.browserIDs
            browser = $scope.browserList[browserID]
            # Only if the user owns the browser allow adding of collaborators
            if isOwner(browser, {email:$scope.email, ns:namespace})
                server.permissionManager.addBrowserPermRec $scope.selectedCollaborator,
                $scope.mountPoint, browserID, {readwrite:true},
                (browserRec) ->
                    if browserRec
                        browser = $scope.browserList[browserRec.id]
                        browser.addUserToLists $scope.selectedCollaborator, {readwrite:true}, () ->
                            $scope.boxMessage = "The selected browsers are now shared with " + $scope.selectedCollaborator
                            $scope.openCollaborateForm()
                    else
                        $scope.error = "Error"
            else
                $scope.error = "Permission Denied"

    # Combine openAddOwnerForm and openCollaborateForm
    $scope.openAddOwnerForm = () ->
        #toggle form
        getProspectiveOwners = () ->
            server.db.collection app.dbName, (err, collection) ->
                collection.find {}, (err, cursor) ->
                    cursor.toArray (err, users) ->
                        throw err if err
                        if users?
                            for browserID in $scope.selected.browserIDs
                                for ownerRec in $scope.browserList[browserID].getUsersInList('own')
                                    if users.length then findAndRemove(ownerRec.user, users)
                                    else break
                        
                        $scope.owners = users

        #toggle form
        $scope.addingOwner = !$scope.addingOwner
        if $scope.addingOwner
            $scope.addingCollaborator = false
            getProspectiveOwners()

    #combine addOwner addCollaborator
    $scope.addOwner = () ->
        for browserID in $scope.selected.browserIDs
            browser = $scope.browserList[browserID]
            # Only if the user owns the browser allow adding of owners
            if isOwner(browser, {email:$scope.email, ns:namespace})
                server.permissionManager.addBrowserPermRec $scope.selectedOwner,
                $scope.mountPoint, browserID, {own:true, remove:true, readwrite:true},
                (browserRec) ->
                    if browserRec
                        browser = $scope.browserList[browserRec.id]
                        browser.addUserToLists $scope.selectedOwner, {own:true, remove:true, readwrite:true}, () ->
                            $scope.boxMessage = "The selected browsers are now co-owned with " + $scope.selectedOwner
                            $scope.openAddOwnerForm()
                    else
                        $scope.error = "Error"
            else
                $scope.error = "Permission Denied"

    addToSelected = (browserID) ->
        if $scope.selected.browserIDs.indexOf(browserID) is -1
            $scope.selected.number++
            $scope.selected.browserIDs.push(browserID)

    removeFromSelected = (browserID) ->
        if $scope.selected.browserIDs.indexOf(browserID) isnt -1
            $scope.selected.number--
            $scope.selected.browserIDs.splice($scope.selected.browserIDs.indexOf(browserID), 1)

    $scope.select = ($event, browserID) ->
        checkbox = $event.target
        if checkbox.checked then addToSelected(browserID) else removeFromSelected(browserID)

    $scope.selectAll = ($event) ->
        checkbox = $event.target
        action = if checkbox.checked then addToSelected else removeFromSelected
        for browserID, browser of $scope.browserList
            action(browserID)

    $scope.getSelectedClass = (browserID) ->
        if $scope.isSelected(browserID)
            return 'highlight'
        else
            return ''

    $scope.isSelected = (browserID) ->
        return ($scope.selected.browserIDs.indexOf(browserID) >= 0)

    $scope.areAllSelected = () ->
        return $scope.selected.browserIDs.length is Object.keys($scope.browserList).length

    $scope.rename = () ->
        for browserID in $scope.selected.browserIDs
            $scope.browserList[browserID].editing = true

    $scope.clickRename = (browserID) ->
        browser = $scope.browserList[browserID]
        if isOwner(browser, {email:$scope.email,ns:namespace})
            browser.editing = true
        
CBLandingPage.filter "removeSlash", () ->
    return (input) ->
        mps = input.split('/')
        return mps[mps.length - 1]

CBLandingPage.filter "isNotEmpty", () ->
    return (input) ->
        if not input then return false
        else return Object.keys(input).length
