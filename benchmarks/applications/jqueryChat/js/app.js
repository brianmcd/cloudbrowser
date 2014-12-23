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

var msgItemTplFunc = Handlebars.templates['messageItem.tmpl'];
var alertMsgTplFunc = Handlebars.templates['alertItem.tmpl'];

var chatMsgBox = $('#chatMessageBox');
var msgObserver = {
    arrayDidChange : function(observedObj, start, removeCount, addCount){
        if (addCount > 0) {
            var content = '';
            for (var i = 0; i < addCount; i++) {
                content += msgItemTplFunc(observedObj[start+i]);
            }
            // only generate one DOM insert event
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
            // put it into setImmediate to batch these update
            setImmediate(function(){
                for (var i = 0; i < removed.length; i++) {
                    msgBox.removeChild(removed[i]);
                }    
            });
        }
    }
};
msgObserver.arrayDidChange(chatManager.messages.val(), 0, 0, chatManager.messages.length);
chatManager.messages.addArrayObserver(msgObserver);

var alertManager = {
    ele : $('#alertMsgsDiv'),
    alerts : [],
    uuid : 0,
    alert : function(msg){
        var self=this;
        var id = id++;
        var alertObj = {
            id : id,
            msg : msg
        };
        this.alerts.push(alertObj);
        this.ele.append(alertMsgTplFunc(alertObj));
        setTimeout(function(){
            self.remove(id);
        }, 3000);
    },
    remove : function(id){
        $('#alertMsgItem'+id).remove();
    }
};

function removeAlert(id){
    alertManager.remove(id);
}

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
        setUserName($("#userNameInput").val());
    }
}

function setUserName(name){
    if (!name || name=='') {
        return alertManager.alert("The user name must not be empty.");
    }
    name = name.trim();
    if (name=='') {
        return alertManager.alert("The user name must not be empty.");
    }
    if (!chatManager.isNameTaken(browserId, name)) {
        var oldName = userName;
        userName = name;
        chatManager.addUser(browserId, userName);
        showUserName();
        // only hide when successfully changed name
        toggleUserNameInput();
        sendMessage(oldName+" is now "+name, 'sys');
    }else{
        alertManager.alert("There is already a user called "+name);
        $("#userNameInput").val('');
    }
}

function chatBoxKeyEvents(evt){
    if (evt.which == 13) {
        sendChatMsg();
    }
}

var chatBox = $('#chatText');
function sendChatMsg(){
    var msg = chatBox.val();
    sendMessage(msg);
    chatBox.val('');
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