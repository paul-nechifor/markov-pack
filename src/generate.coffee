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
