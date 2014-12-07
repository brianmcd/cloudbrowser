function ChatManager(){
}

var initialize = function (options) {
    options.appInstanceProvider = {
        create : function(){
            return new ChatManager();
        }
    }
};


module.exports = {
    initialize : initialize
};
