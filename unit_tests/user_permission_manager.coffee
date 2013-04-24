# Before running this test, clear the database test and add one
# record {email:"findDbTest", ns:"local"} to the Permissions collection
# for the findSysPermRec test for an entry present in DB but not in cache.

PermissionManager = require('../src/server/user_permission_manager')
Mongo             = require('mongodb')
Util              = require('util')

@db_server  = new Mongo.Server('localhost', 27017, {auto_reconnect:true})
@db         = new Mongo.Db('test', @db_server)
@db.open (err, db) ->
    if !err
        console.log "Establised connection to the database."
    else throw err
users = []
users.push({email:'ashima13@vt.edu', ns:'local'})
users.push({email:'findDbTest', ns:'local'})
users.push({email:'ashimaathri@gmail.com', ns:'local'})
users.push({email:'ashimaathri@gmail.com', ns:'google'})

apps = []
apps.push("/app1")
apps.push("/app2")

browserIDs = []
browserIDs.push('1')
browserIDs.push('2')
browserIDs.push('3')

permissionManager = new PermissionManager(@db)

permissionManager.findSysPermRec users[0], (sysRec) ->
    #console.log("\nfindSysPermRec Non Existent")
    #console.log sysRec

permissionManager.findSysPermRec users[1], (sysRec) ->
    #console.log("\nfindSysPermRec Existing but not in cache")
    #console.log sysRec
    permissionManager.findSysPermRec users[1], (sysRec) ->
        #console.log("\nfindSysPermRec Existing and added to cache after first reference to it")
        #console.log sysRec
        permissionManager.rmSysPermRec users[1], (err) ->
            #if err then console.log(err)
            #else console.log("\nrmSysPermRec Existing user")

permissionManager.addSysPermRec users[2], {}, (sysRec) ->
    #console.log("\naddSysPermRec Without Permissions")
    #console.log Util.inspect(sysRec)
    permissionManager.addSysPermRec users[2], null, (sysRec) ->
        #console.log("\naddSysPermRec Existing + without Permissions")
        #console.log Util.inspect(sysRec)
        permissionManager.addSysPermRec users[2], {listapps:false}, (sysRec) ->
            #console.log("\naddSysPermRec Existing + with Permissions 1 {listapps:false}")
            #console.log Util.inspect(sysRec)
            permissionManager.addSysPermRec users[2], {listapps:true, mountapps:false}, (sysRec) ->
                #console.log("\naddSysPermRec Existing + with Permissions 2 {listapps:true, mountapps:false}")
                #console.log Util.inspect(sysRec)
                permissionManager.findSysPermRec users[2], (sysRec) ->
                    #console.log "\nfindSysPermRec Existing and in cache"
                    #console.log Util.inspect(sysRec)
                permissionManager.addSysPermRec users[2], {listapps:false, mountapps:false}, (sysRec) ->
                    #console.log("\naddSysPermRec Existing + with Permissions 3 {listapps:false, mountapps:false}")
                    #console.log Util.inspect(sysRec)
                    permissionManager.addSysPermRec users[2], {listapps:true, mountapps:true}, (sysRec) ->
                        #console.log("\naddSysPermRec Existing + with Permissions 4 {listapps:true, mountapps:true}")
                        #console.log Util.inspect(sysRec)
    permissionManager.addAppPermRec users[2], apps[0], null, (appRec) ->
        #console.log("\naddAppPermRec Without Permissions")
        #console.log(appRec)
        permissionManager.addAppPermRec users[2], apps[0], null, (appRec) ->
            #console.log("\naddAppPermRec Existing + Without Permissions")
            #console.log(appRec)
            permissionManager.addAppPermRec users[2], apps[0], {createbrowsers:true, unmount:true}, (appRec) ->
                #console.log("\naddAppPermRec Existing + With Permissions 1")
                #console.log(appRec)
                permissionManager.findAppPermRec users[2], apps[0], (appRec) ->
                    #console.log("\nfindAppPermRec Existing and in Cache")
                    #console.log(appRec)
                permissionManager.addAppPermRec users[2], apps[0], {listbrowser:true, unmount:false}, (appRec) ->
                    #console.log("\naddAppPermRec Existing + With Permissions 2")
                    #console.log(appRec)
                    permissionManager.addAppPermRec users[2], apps[0], {createbrowsers:false, own:false}, (appRec) ->
                        #console.log("\naddAppPermRec Existing + With Permissions 3")
                        #console.log(appRec)
            permissionManager.addBrowserPermRec users[2], apps[0], browserIDs[0], null, (browserRec) ->
                #console.log("\naddBrowserPermRec Without permissions")
                #console.log(browserRec)
                permissionManager.addBrowserPermRec users[2], apps[0], browserIDs[0], null, (browserRec) ->
                    #console.log("\naddBrowserPermRec Existing - without permissions")
                    #console.log(browserRec)
                permissionManager.addBrowserPermRec users[2], apps[0], browserIDs[0], {own:true, remove:true}, (browserRec) ->
                    #console.log("\naddBrowserPermRec Existing - with permissions 1")
                    #console.log(browserRec)
                    permissionManager.findBrowserPermRec users[2], apps[0], browserIDs[0], (browserRec) ->
                        #console.log("\nfindBrowserPermRec Existing")
                        #console.log(browserRec)
                    permissionManager.addBrowserPermRec users[2], apps[0], browserIDs[0], {own:false, readwrite:true}, (browserRec) ->
                        #console.log("\naddBrowserPermRec Existing - with permissions 2")
                        #console.log(browserRec)
            permissionManager.addBrowserPermRec users[2], apps[0], browserIDs[2], {own:true}, (browserRec) ->
                #console.log("\naddBrowserPermRec With permissions + second browser")
                #console.log(browserRec)
                permissionManager.findAppPermRec users[2], apps[0], (appRec) ->
                    #console.log("\nfindAppPermRec with multiple browsers")
                    #console.log appRec
                    permissionManager.rmBrowserPermRec users[2], apps[0], browserIDs[2], (err) ->
                        #console.log("\nrmBrowserPermRec Existing browser")
                        #if err then console.log err
                        #else console.log("Successfully removed")
                        permissionManager.findAppPermRec users[2], apps[0], (appRec) ->
                            #console.log("\nfindAppPermRec after deletion")
                            #console.log appRec
        permissionManager.addAppPermRec users[2], apps[1], {createbrowsers:true}, (appRec) ->
            #console.log("\naddAppPermRec + with permissions + second app")
            #console.log(appRec)

permissionManager.addAppPermRec users[1], apps[0], {createbrowsers:true, own:true, unmount:true}, (appRec) ->
    #console.log("\naddAppPermRec With Permissions - User Nonexistent Should Fail")
    #if not appRec
        #console.log("Could not add app permission record")
    #else console.log appRec

permissionManager.rmAppPermRec users[1], apps[0], (err) ->
    #console.log("\nrmAppPermRec - User Nonexistent Should Fail")
    #if err then console.log(err)
    #else console.log(appRec)

permissionManager.findBrowserPermRec users[2], apps[0], browserIDs[1], (browserRec) ->
    #console.log("\nfindBrowserPermRec NonExistent")
    #if browserRec then console.log(browserRec)
    #else console.log("Not found")

permissionManager.addSysPermRec users[3], {listapps:true, mountapps:true}, (sysRec) ->
    #console.log("\naddSysPermRec With Permissions {listapps:true, mountapps:true}")
    #console.log Util.inspect(sysRec)
    permissionManager.addAppPermRec users[3], apps[0], {createbrowsers:true, own:true, unmount:true}, (appRec) ->
        #console.log("\naddAppPermRec With Permissions")
        #console.log(appRec)
        permissionManager.rmAppPermRec users[3], apps[0], (err) ->
            #console.log("\nrmAppPermRec Existing app and user")
            #if err then console.log(err)
            #else console.log("successfully removed")

