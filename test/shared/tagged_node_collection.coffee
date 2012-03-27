TaggedNodeCollection = require('../../src/shared/tagged_node_collection')
{getFreshJSDOM}      = require('../helpers')

jsdom = getFreshJSDOM()

getDoc = () ->
    jsdom.jsdom "
        <html>
            <head></head>
            <body>
                <p id='para'></p>
                <div id='div1'></div>
                <div id='div2'></div>
                <div id='div3'></div>
                <div id='div4'></div>
            </body>
        </html>"

exports['basic test'] = (test) ->
    nodes = new TaggedNodeCollection()
    test.notEqual(nodes, null)
    test.done()

exports['test add'] = (test) ->
    doc = getDoc()
    nodes = new TaggedNodeCollection()
    p = doc.getElementById('para')
    div1 = doc.getElementById('div1')
    div2 = doc.getElementById('div2')
    div3 = doc.getElementById('div3')
    div4 = doc.getElementById('div4')

    test.equal(p.__nodeID, undefined)

    nodes.add(p)
    test.equal(p.__nodeID, 'node1')

    nodes.add(div1)
    test.equal(div1.__nodeID, 'node2')

    nodes.add(div2, 'node4')
    test.equal(div2.__nodeID, 'node4')

    # Adding a node with existing ID, and ID doesn't belong to it.
    test.throws () ->
        p.__nodeID = 'node4'
        nodes.add(p)

    # ID taken
    test.throws () ->
        nodes.add(div3, 'node1')

    nodes.add(div3)
    nodes.add(div4)

    test.equal(div4.__nodeID, 'node5')
    test.done()

exports['test get'] = (test) ->
    doc = getDoc()
    nodes = new TaggedNodeCollection()
    p = doc.getElementById('para')
    div1 = doc.getElementById('div1')
    div2 = doc.getElementById('div2')
    div3 = doc.getElementById('div3')
    div4 = doc.getElementById('div4')
    for node in [p, div1, div2, div3, div4]
        nodes.add(node)
    
    test.strictEqual(p, nodes.get('node1'))
    test.strictEqual(div1, nodes.get('node2'))
    test.strictEqual(div2, nodes.get('node3'))
    test.strictEqual(div3, nodes.get('node4'))
    test.strictEqual(div4, nodes.get('node5'))

    test.throws () ->
        nodes.get('wrong')
    test.done()


exports['test scrub/unscrub'] = (test) ->
    doc = getDoc()
    nodes = new TaggedNodeCollection()
    p = doc.getElementById('para')
    div1 = doc.getElementById('div1')
    div2 = doc.getElementById('div2')
    div3 = doc.getElementById('div3')
    div4 = doc.getElementById('div4')
    domNodes = [p, div1, div2, div3, div4]
    for node in domNodes
        nodes.add(node)

    scrubbed = nodes.scrub(domNodes)
    for index in [0..scrubbed.length - 1]
        test.equal(scrubbed[index], "node#{index+1}")

    params = nodes.scrub([{ test : 3}, { more : 4}])
    test.equal(params[0].__nodeID, undefined)
    test.equal(params[0].test, 3)
    test.equal(params[1].__nodeID, undefined)
    test.equal(params[1].more, 4)
    
    unscrubbed = nodes.unscrub(scrubbed)
    for index in [0..unscrubbed.length - 1]
        test.equal(unscrubbed[index], domNodes[index])

    test.done()
