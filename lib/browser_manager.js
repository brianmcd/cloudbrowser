var Class           = require('./inheritance'),
    BrowserInstance = require('./browser_instance');

/* BrowserManager class. */
module.exports = Class.create( {
    // Can I do private variables with the inheritance library?
    // env is a string, either 'jsdom' or 'zombie', for now
    initialize: function (env) {
        //TODO: Add timers for managing the cache.
        //TODO: Add a real backing store.
        this.store = {}; // Store desktops in an object indexed by an id (session_id) for now.
        this.env = env;
    },

    //TODO: change interface to ({id: success: failure:})
    lookup: function(id, callback) {
        if (typeof id != 'string') {
            id = id.toString();
        }
        callback(this.store[id] || (this.store[id] = new BrowserInstance(this.env)));
    }
});
