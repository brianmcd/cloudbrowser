/* Metadata to be tested against for hello.html. */
exports.Hello = {
    html     : '<html><head><title>Hello</title></head><body>Node</body></html>',
    pathStr  : 'fixtures/hello.html',
    urlStr   : 'http://www.brianmcd.com/hello.html',
    numNodes : 8 //counted by hand...
};

/* Metadata for testing against a snapshot of the HackerNews site. */
exports.HackerNews = {
    // TODO: Edit hn.html so that we don't make requests to HN's servers.
    //       Host CSS etc on my server.
    urlStr : 'http://www.brianmcd.com/hn.html',
};
