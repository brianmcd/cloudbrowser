module.exports =
    user             : require('./user')
    logout           : require('./logout')
    browser          : require('./browser')
    guiDeploy        : require('./gui_deploy')
    clientEngine     : require('./client_engine')
    routeHelpers     : require('./route_helpers')
    serveResource    : require('./serve_resource')
    serveAppInstance : require('./serve_application_instance')
    authStrategies :
        google : require('./authentication_strategies/google')
