reqCache = require.cache
for entry of reqCache
    if /jsdom/.test(entry)
        delete reqCache[entry]
JSDOM = require('jsdom')

Serialize = require('../../lib/dom/serializer').serialize


exports['tests'] =
    'basic test' : (test) ->
        doc = JSDOM.jsdom("<HTML><HEAD></HEAD><BODY><DIV></DIV></BODY></HTML>")
        snapshot = Serialize(doc)
        expected = ['html', 'head', 'body', 'div']
        count = 0
        test.equal(snapshot[0].type, 'document')
        for record in snapshot
            if record.type == 'element'
                test.equal(record.name.toLowerCase(), expected[count++])
                if count == expected.length
                    test.done()
