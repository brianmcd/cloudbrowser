var path = require('path'),
    vt = require('../../../vt-node-lib'),
    ko = vt.ko;

exports.UserModel = vt.Model({
    username : ko.observable,
    hashedPassword : ko.observable,
    primaryBrowser : {
        type : ko.observable,
        defaultvalue : null,
        persist : false
    },
    lastAccess : {
        type : ko.observable,
        defaultValue : Date()
    },
    isAdmin : {
        type : ko.observable,
        defaultValue : false
    },
    browsers : {
        type : ko.observableArray, // of Browser objects
        persist : false
    },
    toString : function () {
        return this.username();
    }
},{
    // The folder where we should persist instances of this model.
    folder : path.resolve(__dirname, 'db', 'users'),
    // The property to use as the file name. Must be unique
    filename : 'username'
});
