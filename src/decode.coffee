common = require './common'

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
    return

exports.Decoder = class Decoder
  constructor: (@binary) ->
    @header = new Header

  init: ->
    @header.decode @binary

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
