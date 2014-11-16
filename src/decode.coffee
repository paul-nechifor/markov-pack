common = require './common'
log2Ceil = common.log2Ceil

exports.Header = class Header extends common.Header
  decode: (v) ->
    # Check header and version
    if @magicNumber[0] isnt read(v, 0, 32) or
        @magicNumber[1] isnt read(v, 32, 24)
      throw Error 'invalid-header'
    if v[7] isnt @version
      throw Error 'unsupported-version'

    # Read included header values.
    @wordLengthsLen = read v, 2 * 32, 32
    @chainLen =       read v, 3 * 32, 32
    @hashTableLen =   read v, 4 * 32, 32
    @chainBytesLen =  read v, 5 * 32, 32
    @contListSize =   read v, 6 * 32, 32
    @weightSize =     read v, 7 * 32, 32

  compute: (lengths) ->
    # Compute some of the not included values.
    @setWordListLen lengths
    nWords = 0
    nWords += l[1] for l in lengths
    @wordSize = log2Ceil nWords
    @wordTupleSize = @wordSize * 2
    @offsetSize = log2Ceil @chainBytesLen * 8

    @setOffsets()

exports.Decoder = class Decoder
  constructor: (@binary) ->
    @header = new Header

  decode: ->
    @header.decode @binary
    @lengths = getLengths @binary, @header.lengthsOffset, @header.wordLengthsLen
    @header.compute @lengths

exports.readBinary = read = (v, start, size) ->
  mask = 0xff
  startByte = start // 8
  byteOffset = start % 8
  inFirstByte = 8 - byteOffset
  remaining = size - inFirstByte

  # Read the bits of the first byte after the bit offset.
  n = v[startByte] & (mask >> byteOffset)

  # If there are no more bits to read, ignore the unused bits.
  if remaining <= 0
    return n >> -remaining

  # Read full bytes entirely.
  while remaining >= 8
    remaining -= 8
    n = (n << 8) | v[++startByte]

  # Read the last bits of the last byte.
  (n << remaining) | (v[++startByte] >> (8 - remaining))

getLengths = (v, offset, len) ->
  ret = []
  for i in [0 .. len - 1]
    ret.push [
      read v, offset + 64 * i, 32
      read v, offset + 64 * i + 32, 32
    ]
  ret
