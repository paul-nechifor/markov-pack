common = require './common'
log2Ceil = common.log2Ceil

# This is the number of bits to waste on the chain block. This is necessary
# since offset 0 is used in the hash table to indicate an unused position.
OFFSET_WASTE = 8

exports.MAX_WORDS = MAX_WORDS = 0xffff

exports.Header = class Header extends common.Header
  setWordLengthsLen: (lengths) ->
    @wordLengthsLen = lengths.length

  setWordSize: (wordList) ->
    @wordSize = log2Ceil wordList.length
    @wordTupleSize = @wordSize * 2

  setChainLen: (chain, nextFactor=1.234) ->
    @chainLen = 0
    @chainLen++ for key of chain
    @hashTableLen = nextPrime Math.ceil @chainLen * nextFactor

  setContListAndWeightSizes: (chain) ->
    maxNConts = -1
    maxWeight = -1
    for key, conts of chain
      nConts = 0
      for cont, weight of conts
        nConts++
        maxWeight = weight if weight > maxWeight
      maxNConts = nConts if nConts > maxNConts
    @contListSize = log2Ceil maxNConts
    @weightSize = log2Ceil maxWeight

  setChainBytesLen: (chain) ->
    offset = OFFSET_WASTE
    for key, conts of chain
      offset += @contListSize
      nConts = 0
      nConts++ for x of conts
      offset += nConts * (@wordSize + @weightSize)
    @chainBytesLen = Math.ceil offset / 8
    @offsetSize = log2Ceil offset

  setAll: (chain, words, lengths, map) ->
    @setWordLengthsLen lengths
    @setWordSize words
    @setChainLen chain
    @setWordListLen lengths
    @setContListAndWeightSizes chain
    @setChainBytesLen chain
    @setOffsets()

  writeInBinary: (v) ->
    writeBinary32s v, 0, [
      @magicNumber[0]
      (@magicNumber[1] << 8) | @version
      @wordLengthsLen
      @chainLen
      @hashTableLen
      @chainBytesLen
      @contListSize
      @weightSize
    ]

exports.Encoder = class Encoder
  constructor: (@chain) ->
    @header = new Header

  encode: ->
    @words = getWords @chain
    @lengths = getLengths @words
    @map = getWordToNumberMap @words
    @header.setAll @chain, @words, @lengths, @map

    @binary = new Uint8Array @header.totalByteSize
    @header.writeInBinary @binary
    writePairOfLengths @binary, @header.lengthsOffset, @lengths
    writeWordList @binary, @header.wordListOffset, @words
    @offsets = writeChain @header, @binary, @chain, @map
    @table = getHashTable @offsets, @header.hashTableLen
    writeHashTable @header, @binary, @table
    @binary

# Splits a sentence into words that can be added to the chain.
exports.splitSentence = (s) ->
  s = s.trim()
  if s[s.length - 1] in ['.', '!', '?']
    end = s[s.length - 1]
    s = s.substring(0, s.length - 1).trim()
  ret = s.split /\s+/
  ret.splice 0, 0, '', ''
  ret.push end if end
  ret.push ''
  ret

exports.addToChain = (chain, seq) ->
  len = seq.length
  return if len < 3
  for word in seq
    throw new Error 'tab-not-allowed' if /\t/.exec word
  for i in [0 .. len - 3] by 1
    key = seq[i] + '\t' + seq[i + 1]
    word = seq[i + 2]
    next = chain[key]
    if next is undefined
      chain[key] = next = {}
    if next[word] is undefined
      next[word] = 1
    else
      next[word]++
  return

exports.getWords = getWords = (chain) ->
  words = {}
  nWords = 0
  addWord = (w) ->
    if not words[w]
      words[w] = true
      if ++nWords > MAX_WORDS
        throw Error 'too-many-words'
    return
  for key, pos of chain
    w2 = key.split '\t'
    addWord w2[0]
    addWord w2[1]
    addWord w for w of pos
  Object.keys(words).sort (a, b) ->
    if a.length > b.length then 1
    else if a.length < b.length then -1
    else if a > b then 1 else if a < b then -1 else 0

exports.getLengths = getLengths = (words) ->
  return [] if words.length is 0
  ret = []
  last = -1
  count = -1
  for word in words
    if word.length is last
      count++
      continue
    unless last is -1
      ret.push [last, count]
    last = word.length
    count = 1
  ret.push [last, count]
  ret

exports.getWordToNumberMap = getWordToNumberMap = (words) ->
  map = {}
  for word, i in words
    map[word] = i
  map

exports.writeBinary = writeBinary = (v, start, size, n) ->
  # The position of the first byte to be written.
  startByte = start // 8
  # The remaining bits left to write.
  remaining = size - 8 + start % 8

  # Write the first bits of the first byte. If this is an incomplete byte, it
  # has to be shifted the other way.
  v[startByte] |= if remaining > 0 then n >> remaining else n << -remaining

  # Write all the whole bytes. These don't require using or.
  while remaining >= 8
    remaining -= 8
    v[++startByte] = (n >> remaining) & 0xff
  return if remaining is 0

  # Write the last bites of the last byte.
  v[++startByte] |= (n << (8 - remaining)) & 0xff
  return

exports.writePairOfLengths = writePairOfLengths = (v, offset, lengths) ->
  for pair, i in lengths
    at = offset + 32 * 2 * i
    writeBinary v, at, 32, pair[0]
    writeBinary v, at + 32, 32, pair[1]
  return

exports.writeWordList = writeWordList = (v, offset, words) ->
  k = offset
  for word in words
    for c in word
      writeBinary v, k, 8, c.charCodeAt 0
      k += 8
  return

exports.getNumberTuple = getNumberTuple = (wordSize, tuple, map) ->
  parts = tuple.split '\t'
  # The number should never be 0 since that's used in the hashTable to indicate
  # an unused position. That's why 1 is added. TODO: Write this in the readme.
  ((map[parts[0]] << wordSize) | map[parts[1]]) + 1

exports.writeChain = writeChain = (header, v, chain, map) ->
  offset = OFFSET_WASTE
  start = header.chainOffset

  # A map from number tuple to continuation offset.
  offsets = {}

  for tuple, cont of chain
    # Get the word tuple as a number tuple.
    nTuple = getNumberTuple header.wordSize, tuple, map

    # Save the offset for this continuation.
    offsets[nTuple] = offset

    # Compute and save the number of continuations.
    nConts = 0
    nConts++ for x of cont
    writeBinary v, start + offset, header.contListSize, nConts
    offset += header.contListSize

    # Write the number word and its weight.
    for word, weight of cont
      writeBinary v, start + offset, header.wordSize, map[word]
      offset += header.wordSize
      writeBinary v, start + offset, header.weightSize, weight
      offset += header.weightSize

  # Return the offsets map.
  offsets

exports.getHashTable = getHashTable = (offsets, length) ->
  v = []
  v.push null for i in [1 .. length] by 1
  for tuple, offset of offsets
    tuple = Number tuple
    hash = tuple % length
    while v[hash] isnt null
      hash = (hash + 1) % length
    v[hash] = [tuple, offset]
  v

exports.writeHashTable = writeHashTable = (header, v, table) ->
  eSize = header.wordTupleSize + header.offsetSize
  for e, i in table
    continue if e is null
    offset = header.hashTableOffset + eSize * i
    writeBinary v, offset, header.wordTupleSize, e[0]
    writeBinary v, offset + header.wordTupleSize, header.offsetSize, e[1]
  return

nextPrime = (n) ->
  n++ if n % 2 is 0
  while true
    for i in [2 .. n / 2] by 1
      if n % i is 0
        n++
        continue
    return n

writeBinary32s = (v, offset, list) ->
  for x, i in list
    writeBinary v, offset + i * 32, 32 , x
  return
