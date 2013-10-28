module.exports =
    user             : require('./user')
    logout           : require('./logout')
    browser          : require('./browser')
    fileUpload       : require('./file_upload')
    clientEngine     : require('./client_engine')
    serveResource    : require('./serve_resource')
    serveAppInstance : require('./serve_application_instance')
    authStrategies :
        google : require('./authentication_strategies/google')
