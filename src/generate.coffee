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

exports.getHeader = (lengths) ->
  bytesPerNumber = 4
  ret = new Uint8Array bytesPerNumber * (1 + 2 * lengths.length)
  writeInt32 ret, 0, lengths.length
  for i in [0 .. lengths.length - 1]
    s = bytesPerNumber * (1 + 2 * i)
    writeInt32 ret, s, lengths[i][0]
    writeInt32 ret, s + bytesPerNumber, lengths[i][1]
  ret

exports.getWordToNumberMap = (words) ->
  map = {}
  for word, i in words
    map[word] = i
  map

exports.writeBinary = (v, start, size, n) ->
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

writeInt32 = (a, pos, n) ->
  for i in [0 .. 3]
    a[pos + 3 - i] = n % 0xff
    n >>= 8
