common = require './common'

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

exports.splitSentence = (s) ->
  s = s.trim()
  if s[s.length - 1] in ['.', '!', '?']
    end = s[s.length - 1]
    s = s.substring(0, s.length - 1).trim()
  ret = s.split /\s+/
  ret.push end if end
  ret

exports.addToChain = (chain, seq) ->
  len = seq.length
  return if len < 3
  for word in seq
    throw new Error 'tab-not-allowed' if /\t/.exec word
  for i in [0 .. len - 3]
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

exports.getWords = (chain) ->
  words = {}
  for key, pos of chain
    w2 = key.split '\t'
    words[w2[0]] = true
    words[w2[1]] = true
    for w of pos
      words[w] = true
  Object.keys(words).sort()

exports.getLengths = (words) ->
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

exports.getWordToNumberMap = (words) ->
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

exports.writePairOfLengths = (v, offset, lengths) ->
  for pair, i in lengths
    at = offset + 32 * 2 * i
    writeBinary v, at, 32, pair[0]
    writeBinary v, at + 32, 32, pair[1]
  return

exports.writeWordList = (v, offset, words) ->
  k = offset
  for word in words
    for c in word
      writeBinary v, k, 8, c.charCodeAt 0
      k += 8
  return

log2Ceil = (n) -> Math.ceil Math.log(n) / Math.LN2

nextPrime = (n) ->
  n++ if n % 2 is 0
  while true
    for i in [2 .. n / 2]
      if n % i is 0
        n++
        continue
    return n
