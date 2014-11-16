exports.magicNumber = [0x13e3ff45, 0xbe9c06]

exports.Header = class Header
  constructor: ->
    @magicNumber = exports.magicNumber
    @version = 1

    @wordLengthsLen = -1
    @chainLen = -1
    @wordListLen = -1
    @hashTableLen = -1
    @chainBytesLen = -1

    @wordSize = -1
    @wordTupleSize = -1
    @offsetSize = -1
    @contListSize = -1
    @weightSize = -1

    @lengthsOffset = 8 * @constructor.size
    @wordListOffset = -1
    @hashTableOffset = -1
    @chainOffset = -1
    @totalByteSize = -1

  @size = 4 * (2 + 6)

  setWordListLen: (lengths) ->
    @wordListLen = 0
    for [wl, count] in lengths
      @wordListLen += wl * count
    return
