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
    @wordToupleSize = -1
    @offsetSize = -1
    @contListSize = -1
    @weightSize = -1
