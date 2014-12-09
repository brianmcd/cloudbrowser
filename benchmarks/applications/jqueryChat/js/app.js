var browserId, chatManager;
if (typeof cloudbrowser !== 'undefined') {
    var currentBrowser = cloudbrowser.currentBrowser;
    browserId = currentBrowser.getID();
    chatManager = cloudbrowser.currentAppInstanceConfig.getObj();
}else{
    // for test
    browserId = "someid";
    chatManager = {};
}

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

if (!chatManager.addMessage) {
    chatManager.messages = new ObservableArray();
    chatManager.users = {};
    chatManager.addMessage = function(msgObj){
        this.messages.pushObject(msgObj);
        if(this.messages.length > 100){
            this.messages.removeAt(0, 50);
        }
    };
    chatManager.addUser = function(browserId, name){
        this.users[browserId] = name;
    };
    chatManager.isNameTaken = function(browserId, name){
        var taken = false;
        for (var k in this.users) {
            if (k != browserId && this.users[k] == name) {
                return true;
            }
        }
        return taken;
    };
}

// 'Oct 21, 2014 3:24:31 PM'
Handlebars.registerHelper('format-date', function(date) {
  return moment(date).format('MMM DD, YYYY h:mm:ss A');
});

Handlebars.registerHelper('msg-class', function(type) {
    if(type==='sys'){
        return 'class="alert alert-success"';
    }
    return '';
});

//trim to remove unnessary text elements
var msgItemTplFunc = Handlebars.templates['messageItem.tmpl'];

var chatMsgBox = $('#chatMessageBox');
var msgObserver = {
    arrayDidChange : function(observedObj, start, removeCount, addCount){
        if (addCount > 0) {
            var content = '';
            for (var i = 0; i < addCount; i++) {
                content += msgItemTplFunc(observedObj[start+i]);
            }
            chatMsgBox.append(content);
        }
        if (removeCount>0) {
            var removed = [];
            var msgBox = chatMsgBox[0];
            var childNodes = msgBox.childNodes;
            var childrenCount = childNodes.length;
            var toRemove = 0;
            for (var i = start; i<childrenCount; i++) {
                var child = childNodes[i];
                if (child.tagName === 'DIV') {
                    toRemove++;
                }
                removed.push(childNodes[i]);
                if (toRemove===removeCount) {
                    break;
                }
            }
            for (var i = 0; i < removed.length; i++) {
                msgBox.removeChild(removed[i]);
            }
        }
    }
};
msgObserver.arrayDidChange(chatManager.messages.val(), 0, 0, chatManager.messages.length);
chatManager.messages.addArrayObserver(msgObserver);


var userName = "Goose_" + browserId;

chatManager.addUser(browserId, userName);

function showUserName(){
    $('#welcomeSpan').text("Welcome "+ userName);
}

showUserName();

function toggleUserNameInput(){
    $("#userNameInputDiv").toggle();
}

function userNameInputKeyEvents(evt){
    if (evt.which == 13) {
        toggleUserNameInput();
        setUserName($("#userNameInput").val());
    }
}

function setUserName(name){
    if (!chatManager.isNameTaken(browserId, name)) {
        var oldName = userName;
        userName = name;
        chatManager.addUser(browserId, userName);
        showUserName();
        sendMessage(oldName+" is now "+name, 'sys');
    }else{
        //TODO implement alert messages
        $("#userNameInput").val('');
    }
}

function chatBoxKeyEvents(evt){
    if (evt.which == 13) {
        sendChatMsg();
    }
}

function sendChatMsg(){
    var msg = $('#chatText').val();
    sendMessage(msg);
    $('#chatText').val('');
}

function sendMessage(msg, type){
    var msgObj = {
        msg: msg,
        userName: userName,
        time: Date.now()
    };
    if (type) {
        msgObj.type = type;
    };
    chatManager.addMessage(msgObj);
}