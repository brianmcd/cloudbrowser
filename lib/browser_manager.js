var Class           = require('./inheritance'),
    BrowserInstance = require('./browser_instance');

/* BrowserManager class. */
module.exports = Class.create( {
    // env is a string, either 'jsdom' or 'zombie', for now
    initialize : function () {
        this.store = {}; // Store desktops in an object indexed by an id (session_id) for now.
    },

    lookup : function (id, callback) {
        if (typeof id != 'string') {
            console.log('id: ' + id);
            id = id.toString();
        }
        this.store[id] = this.store[id] || new BrowserInstance();
        callback(this.store[id]);
    }
});
