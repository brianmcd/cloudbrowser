Weak              = require('weak')
User              = require("./user")
serverAPI         = require("./server_API")
applicationAPI    = require("./application_API")
authenticationAPI = require("./authentication_API")
componentAPI      = require("./component_API")

# The CloudBrowser API
#
# Instance Variables
# ------------------
# @property [ApplicationAPI]    `app`    - The {ApplicationAPI} namespace.     
#
# @property [AuthenticationAPI] `auth`   - The {AuthenticationAPI} namespace.      
#
# @property [ServerAPI]         `server` - The {ServerAPI} namespace.        
#
# @property [ComponentAPI]      `component` - The {ComponentAPI} namespace.
#
# @method #User(email, namespace)
#   Creates a new CloudBrowser {User}.
#   @param [String] email The email ID of the user.
#   @param [String] namespace The namespace of the user. Permissible values are "local" and "google".
#   @return [User] The CloudBrowser User.
class CloudBrowser

    # Constructs an instance of the CloudBrowser API
    # @param [Browser] browser The JSDOM browser object corresponding to the current browser
    # @param [Browser_Server] bserver The object corresponding to the current browser
    # @private
    constructor : (browser, bserver, cleaned) ->
        @app       = (new applicationAPI(bserver)).app
        @server    = (new serverAPI(bserver)).server
        @auth      = (new authenticationAPI(bserver)).auth
        @component = (new componentAPI(browser, cleaned)).component
        @User      = (email, namespace) -> return new User(email, namespace)

    # Is this secure?
    Model       : require('./model')
    PageManager : require('./page_manager')

module.exports = (browser, bserver) ->
    cleaned = false
    # TODO: is this weak ref required?
    window = Weak(browser.window, () -> cleaned = true)
    browser = Weak(browser, () -> cleaned = true)

    window.CloudBrowser = new CloudBrowser(browser, bserver, cleaned)
