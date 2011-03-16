var Class           = require('./inheritance'),
    BrowserInstance = require('./browser_instance');

/* BrowserManager class. */
module.exports = Class.create( {
    // env is a string, either 'jsdom' or 'zombie', for now
    initialize: function (env) {
        this.store = {}; // Store desktops in an object indexed by an id (session_id) for now.
        this.env = env;
    },

    lookup: function(id, callback) {
        if (typeof id != 'string') {
            id = id.toString();
        }
        callback(this.store[id] || (this.store[id] = new BrowserInstance(this.env)));
    }
});
