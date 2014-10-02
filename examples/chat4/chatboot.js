function ChatManager(){
    this.messages = [];
    this.users = {};
    this.version = 0;
}
ChatManager.prototype.addMessage = function(msgObj) {
    this.messages.push(msgObj)
    // performance is really bad when the cap is 500, 1000
    if(this.messages.length > 100){
        this.messages.splice(0, 50)
    }
    this.version++;
};

ChatManager.prototype.getVersion = function(){
    return this.version;
};


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
