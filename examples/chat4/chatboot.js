module.exports = {
    initialize : function (options) {
        options.appInstanceProvider = {
            create : function(){
                return {
                    messages : [],
                    users : {}
                }
            }
        }
    }
}
