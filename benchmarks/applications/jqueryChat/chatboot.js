//use observable pattern to inform other virtual browser to update its UI
function ObservableArray(){
    this._arr=[];
    this._observers=[];
    Object.defineProperty(this, 'length', {
        get : function(){
            return this._arr.length;
        }
    });
}
ObservableArray.prototype.pushObject = function(obj){
    var oldLen = this._arr.length;
    this._arr.push(obj);
    for (var i = 0; i < this._observers.length; i++) {
        this._observers[i].arrayDidChange(this._arr, oldLen, 0, 1);
    }
};

ObservableArray.prototype.removeAt = function(start, len){
    if (len<=0) {
        return;
    }
    this._arr.splice(start, len);
    for (var i = 0; i < this._observers.length; i++) {
        this._observers[i].arrayDidChange(this._arr, start, len, 0);
    }
};
ObservableArray.prototype.addArrayObserver = function(observer){
    this._observers.push(observer);
};
ObservableArray.prototype.val = function(){return this._arr;};



function ChatManager(){
    this.messages = new ObservableArray();
    this.users = {};
}

ChatManager.prototype.addMessage = function(msgObj){
    this.messages.pushObject(msgObj);
    if(this.messages.length >= 100){
        this.messages.removeAt(0, 50);
    }
};

ChatManager.prototype.addUser = function(browserId, name){
    this.users[browserId] = name;
};

ChatManager.prototype.isNameTaken = function(browserId, name){
    var taken = false;
    for (var k in this.users) {
        if (k != browserId && this.users[k] == name) {
            return true;
        }
    }
    return taken;
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
