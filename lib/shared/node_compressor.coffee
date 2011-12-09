# Record definitions:
# 'element':
#       type          : 0
#       id            : node.__nodeID
#       name          : node.tagName
#       parent        : node.parentNode.__nodeID
#       ownerDocument : node.ownerDocument.__nodeID
#       docID         : node.contentDocument.__nodeID
#       attributes    :
#               name : value
# 'comment' | 'text'
#       type          : 'comment' == 1, 'text' == 2
#       id            : node.__nodeID
#       parent        : node.parentNode.__nodeID
#       value         : node.data
#       ownerDocument : node.ownerDocument.__nodeID
class NodeCompressor
    @compress : (record) ->
        compressed = null
        switch record.type
            when 'element'
                return [
                    0
                    record.id
                    record.name
                    record.parent
                    record.ownerDocument
                    record.docID
                    record.attributes
                ]
            when 'comment', 'text'
                typeNum = if record.type == 'comment' then 1 else 2
                return [
                    typeNum
                    record.id
                    record.parent
                    record.value
                    record.ownerDocument
                ]

    @uncompress : (compressed) ->
        typeNum = compressed[0]
        switch typeNum
            when 0
                return {
                    type          : 'element'
                    id            : compressed[1]
                    name          : compressed[2]
                    parent        : compressed[3]
                    ownerDocument : compressed[4]
                    docID         : compressed[5]
                    attributes    : compressed[6]
                    before        : compressed[7]
                }
            when 1,2
                return {
                    type          : if typeNum == 1 then 'comment' else 'text'
                    id            : compressed[1]
                    parent        : compressed[2]
                    value         : compressed[3]
                    ownerDocument : compressed[4]
                }
        throw new Error("Invalid typeNum: #{typeNum}")

module.exports = NodeCompressor
