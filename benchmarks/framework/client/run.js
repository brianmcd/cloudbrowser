require('coffee-script')

var clientCtors = {
    'LockstepClient'          : require('./lockstep_client'),
    'RequestsPerSecondClient' : require('./requests_per_second_client'),
    'Client'                  : require('./client')
};

var Clients = require('./index');

var clients = null;
if (typeof process.send == 'function') {
    // We were forked, get options from parent.
    process.on('message', function (opts) {
        if (opts.type == 'Config') {
            opts.clientClass = clientCtors[opts.clientClass]
            opts.doneCallback = function (_clients) {
                clients = _clients;
                process.send({type: 'Ready'});
            };
            var resultEE = Clients.spawnClientsInProcess(opts);
            resultEE.on('Result', function (id, info) {
                process.send({type: 'Result', id: id, info: info});
            });
        } else if (opts.type == 'Start') {
            clients.forEach(function (client) {
                client.start();
            });
        }
    });
} else {
    // Get options from command line.
}
