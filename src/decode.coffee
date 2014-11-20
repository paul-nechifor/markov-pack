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
    @wordsOffset = @header.wordListOffset / 8
    @hashOffset = @header.hashTableOffset
    @hashElemSize = @header.wordTupleSize + @header.offsetSize

  getWord: (index) ->
    lens = @lengths
    k = 0
    remaining = index
    start = 0
    while remaining - lens[k][1] >= 0
      start += lens[k][0] * lens[k][1]
      remaining -= lens[k][1]
      k++
    start += lens[k][0] * remaining
    length = lens[k][0]
    return '' if length is 0
    str = ''
    for i in [start .. start + length - 1] by 1
      str += String.fromCharCode @binary[@wordsOffset + i]
    str

  getContOffset: (tuple) ->
    i = tuple
    totalLooped = 0
    while true
      start = @hashOffset + (i % @header.hashTableLen) * @hashElemSize
      # TODO: See why a!=b but 0==a-b. WTF!?
      if 0 is tuple - read @binary, start, @header.wordTupleSize
        return read @binary, start + @header.wordTupleSize, @header.offsetSize
      i++
      if ++totalLooped >= @header.hashTableLen
        throw new Error 'no-such-key'
    return

  sumWeights: (tuple) ->
    start = @header.chainOffset + @getContOffset(tuple)
    nConts = read @binary, start, @header.contListSize
    sum = 0
    elemSize = @header.wordSize + @header.weightSize
    start += @header.wordSize + @header.contListSize
    for i in [0 .. nConts - 1] by 1
      s = read @binary, start + i * elemSize, @header.weightSize
      sum += s
    sum

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
  for i in [0 .. len - 1] by 1
    ret.push [
      read v, offset + 64 * i, 32
      read v, offset + 64 * i + 32, 32
    ]
  ret
