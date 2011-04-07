var repl = require('repl'),
    path = require('path'),
    BI   = require('./lib/browser_instance');

var b = new BI();
var htmlpage = "<html><head><title>Title</title></head><body>This is the body</body></html>";
var nodeinsert = path.join(__dirname, 'examples', 'test-server', 'nodeinsert', 'index.html');

var repl = repl.start()
repl.context.b = b;
repl.context.htmlpage = htmlpage;
repl.context.nodeinsert = nodeinsert;
