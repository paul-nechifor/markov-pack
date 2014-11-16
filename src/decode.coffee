common = require './common'

exports.Header = class Header extends common.Header
  decode: (b) ->
    m1 = (b[0] << 24) | (b[1] << 16) | (b[2] << 8) | b[3]
    m2 = (b[4] << 16) | (b[5] << 8) | b[6]
    if m1 isnt @magicNumber[0] or m2 isnt @magicNumber[1]
      throw Error 'invalid-header'
    if b[7] isnt @version
      throw Error 'unsupported-version'
    return

exports.Decoder = class Decoder
  constructor: (@binary) ->
    @header = new Header

  init: ->
    @header.decode @binary

exports.readBinary = readBinary = (v, start, size) ->
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
