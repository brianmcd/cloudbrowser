TestCase             = require('nodeunit').testCase
TaggedNodeCollection = require('../lib/tagged_node_collection')
# Any tests that create a JSDOMWrapper and run before this will have added
# advice to JSDOM, so we have to get a fresh copy.
reqCache = require.cache
for entry of reqCache
    if /jsdom/.test(entry) # && !(/jsdom_wrapper/.test(entry))
        delete reqCache[entry]
JSDOM                = require('jsdom')

doc = null
exports['tests'] = TestCase(
    setUp : (callback) ->
        doc = JSDOM.jsdom("
            <HTML>
                <HEAD></HEAD>
                <BODY>
                    <P id='para'></P>
                    <DIV id='div1'></DIV>
                    <DIV id='div2'></DIV>
                    <DIV id='div3'></DIV>
                    <DIV id='div4'></DIV>
                </BODY>
            </HTML>")
        callback()

    tearDown : (callback) ->
        doc = null
        callback()

    'basic test' : (test) ->
        nodes = new TaggedNodeCollection()
        test.notEqual(nodes, null)
        test.done()

    'test add' : (test) ->
        nodes = new TaggedNodeCollection()
        p = doc.getElementById('para')
        div1 = doc.getElementById('div1')
        div2 = doc.getElementById('div2')
        div3 = doc.getElementById('div3')
        div4 = doc.getElementById('div4')

        test.equal(nodes.count, 0)
        test.equal(p.__nodeID, undefined)

        nodes.add(p)
        test.equal(nodes.count, 1)
        test.equal(p.__nodeID, 'node1')

        nodes.add(div1)
        test.equal(nodes.count, 2)
        test.equal(div1.__nodeID, 'node2')

        nodes.add(div2, 'node4')
        test.equal(nodes.count, 3)
        test.equal(div2.__nodeID, 'node4')

        # Adding a node with existing ID, and ID doesn't belong to it.
        test.throws( () ->
            p.__nodeID = 'node4'
            nodes.add(p)
        )

        # ID taken
        test.throws( () ->
            nodes.add(div3, 'node1')
        )

        # ID must be string
        test.throws( () ->
            nodes.add(div3, {})
        )

        nodes.add(div3)
        nodes.add(div4)

        test.equal(div4.__nodeID, 'node5')
        test.equal(nodes.count, 5)
        test.done()

    'test get' : (test) ->
        nodes = new TaggedNodeCollection()
        p = doc.getElementById('para')
        div1 = doc.getElementById('div1')
        div2 = doc.getElementById('div2')
        div3 = doc.getElementById('div3')
        div4 = doc.getElementById('div4')
        for node in [p, div1, div2, div3, div4]
            nodes.add(node)
        
        test.equal(p, nodes.get('node1'))
        test.equal(div1, nodes.get('node2'))
        test.equal(div2, nodes.get('node3'))
        test.equal(div3, nodes.get('node4'))
        test.equal(div4, nodes.get('node5'))

        test.throws( () ->
            nodes.get('wrong')
        )
        test.done()


    'test scrub/unscrub' : (test) ->
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
)
