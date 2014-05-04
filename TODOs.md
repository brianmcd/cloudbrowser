
# Some notes on TODOs.

Would like to chizzle away at jsdom patch to reduce it to zero.

- preClickActivationHandler clearly need to go in jsdom proper

- console.log on error output - shouldn't we instead override HTMLElement.raise or HTMLDocument.raise?

- __enclosingFrame:     is this really needed? Can't .parent be used?

- browser:  - can this be made generic.

- other patches: are they really needed (like documentFeatures, shouldn't they be
    settable from outside?)

    - unload etc. - shouldn't this go in jsdom proper?



## Refactor issues
- remove ugly bindings in applications 
@serveVirtualBrowserHandler = lodash.bind(@_serveVirtualBrowserHandler, this)

- change private property names

- consolidate classes for configs

- serverConfig.listApps  : for now, we assume every worker has full set of applications

- appConfig.listBrowsers : done

- application.closeBrowser, need to close the appInstance if needed

- app = appManager.find(rec.getMountPoint()) and get all apps in serverConfig should be async

- give non standalone app good names, or hide them from displayed in admin ui

### api 

- appConfig will directly change local app object, local app listen to masterApp change event....

- appIntanceConfig, has few attributes, directly use remote obj

- appInstanceConfig should have field of appConfig
- likewise, browser should have filed of appConfig, appInstanceConfig
- event registration in app
    + register add/remove appInstance in app object
    + add/remove browser in appInstance obj
- change the apis accordingly to reflect our current obj structure

## admin interface

- addUser. isOwner ... etc, change to async.
- addBrowser. getAppInstance, change to async.
- addBrowser. connect, disconnect, share events from browser

## landing page
- making instances from the same user go to the same machine
    + need no change to landing page code
    + hard to implement such mechanism  

## chat3

# issues

- will event listeners be a memory issue
    + the actual event register are done in api objects, we can do something there

- bug in landing_page, cb-typeahead in add_collaborator.html. Commented out

    item has no toLowerCase
    [[[0k0fzaksz3]]] item has no toLowerCase 

    object
    [[[0k0fzaksz3]]] object 

    { _email: 'panxiaozhong@gmail.com' }
    [[[0k0fzaksz3]]] [object Object] 

    JavaScript event handler error:
    TypeError: Object [object Object] has no method 'toLowerCase'
        at Typeahead.matcher (/Users/pan/git/cloudbrowser2/src/server/applications/landing_page/js/bootstrap.js:1946:20)
        at /Users/pan/git/cloudbrowser2/src/server/applications/landing_page/js/bootstrap.js:1923:21
        at Function.jQuery.extend.grep (/Users/pan/git/cloudbrowser2/src/server/applications/landing_page/js/jquery.js:753:15)
        at Typeahead.process (/Users/pan/git/cloudbrowser2/src/server/applications/landing_page/js/bootstrap.js:1922:17)
        at Typeahead.lookup (/Users/pan/git/cloudbrowser2/src/server/applications/landing_page/js/bootstrap.js:1916:27)
        at Typeahead.keyup (/Users/pan/git/cloudbrowser2/src/server/applications/landing_page/js/bootstrap.js:2088:16)
        at Object.proxy (/Users/pan/git/cloudbrowser2/src/server/applications/landing_page/js/jquery.js:818:14)
        at Object.jQuery.event.dispatch (/Users/pan/git/cloudbrowser2/src/server/applications/landing_page/js/jquery.js:3074:9)
        at Object.elemData.handle (/Users/pan/git/cloudbrowser2/src/server/applications/landing_page/js/jquery.js:2750:28)
        at Function.dispatch (/Users/pan/git/cloudbrowser2/node_modules/jsdom/lib/jsdom/level2/events.js:197:42)
    [TypeError: Object [object Object] has no method 'toLowerCase']


## Permission issues

- add permission for create app : done

- add permission for create appInstance : done

- permission checking for create browser -- should put this in appinstance

- addBrowserPermRec, should persist to DB

- a lot of implementation in permission manager are deviced on top of cache, need to change that


## Weird issues

- api, rename api for appInstance, no corresponding method in appInstance: deleted

Plan

- api/appConfig

- api/browserConfig


# method with both async and sync behaviors

- the object could be called remotely

- the object has been called synchronously as a local object, it would be hard to remove the sync behavior entirely

# refresh for virtual browser
