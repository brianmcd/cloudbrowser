var EventMonitor = require('client/event_monitor'),
    EventEmitter = require('events').EventEmitter;

function MockDocument () {
    this.addEventListener = function () {
        this.emit('addEventListener', arguments);
    };
}
MockDocument.prototype = new EventEmitter();

function MockServer () {
    this.processEvent = function () {
        this.emit('processEvent', event);
    };
}
MockServer.prototype = new EventEmitter();

exports['test basic'] = function (test, assert) {
    var monitor = new EventMonitor({
        document : new MockDocument(),
        socket   : new MockServer()
    });
    assert.notEqual(monitor, null);
    test.finish();
};

exports['test addEventListener'] = function (test, assert) {
    var document = new MockDocument();
    var server   = new MockServer();
    // Small implementation detail here: 'click' is registered before
    // 'change' when registering default events.
    var events = ['click', 'change', 'mouseover', 'dblclick'];
    var count = 0;
    document.on('addEventListener', function (args) {
        assert.equal(args[0], events[count++]);
        if (count == events.length) {
            test.finish();
        }
    });

    var monitor = new EventMonitor({
        document : document,
        socket   : server
    });

    // It shouldn't add a listener for default events; we're already
    // listening on those.
    monitor.addEventListener({
        nodeID    : 'node1',
        type      : 'change',
        capturing : true
    });
    monitor.addEventListener({
        nodeID    : 'node1',
        type      : 'click',
        capturing : true
    });
    monitor.addEventListener({
        nodeID    : 'node1',
        type      : 'mouseover',
        capturing : true
    });
    // It shouldn't add a second listener for 'mouseover'.
    monitor.addEventListener({
        nodeID    : 'node1',
        type      : 'mouseover',
        capturing : true
    });
    monitor.addEventListener({
        nodeID    : 'node1',
        type      : 'dblclick',
        capturing : true
    });
};
