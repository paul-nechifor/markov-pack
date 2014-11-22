fs = require 'fs'
optimist = require 'optimist'
encode = require './encode'
decode = require './decode'

module.exports = main = ->
  argv = optimist
  .usage 'Usage: $0 [options]'

  .default 'i', '-'
  .alias 'i', 'in'
  .describe 'i', 'The input file (1 sentence per line). Use "-" for stdin.'

  .default 'o', '-'
  .alias 'o', 'out'
  .describe 'o', 'The path to the output file. Use "-" for stdout.'

  .alias 'h', 'help'
  .describe 'h', 'Print this help message.'

  .default 'trim', false
  .describe 'trim', 'Trim word list to specified number of words so that it' +
      'can fit into the binary chain limits.'

  .default 'max-words', 0x4000
  .describe 'max-words', 'Maximum number of words to trim to.'

  .alias 'g', 'generate'
  .describe 'g', 'Use the file to generate new sentences.'

  .default 'n', 100
  .describe 'n', 'The number of sentences to generate.'

  .argv

  cb = (err) -> throw err if err

  return optimist.showHelp() if argv.h
  return trim argv.in, argv.out, argv['max-words'], cb if argv.trim
  return generate argv.generate, argv.n, cb if argv.generate
  makeBinaryChain argv.in, argv.out, cb

generate = (inFile, n, cb) ->
  readFile inFile, 'binary', (err, data) ->
    return cb err if err
    binary = new Buffer data, 'binary'
    decoder = new decode.Decoder binary
    decoder.decode()
    for i in [1 .. n] by 1
      sentence = decoder.joinSequence decoder.getSequence()
      console.log sentence
    cb()

trim = (inFile, outFile, maxWords, cb)->
  readLines inFile, (err, lines) ->
    return cb err if err
    sentences = []
    sentences.push encode.splitSentence line for line in lines
    popular = getMostPopularWords sentences, maxWords
    ordered = getOrdered sentences, popular
    top = getTop sentences, ordered, maxWords
    writeTop outFile, lines, top, cb

makeBinaryChain = (inFile, outFile, cb) ->
  readFile inFile, 'utf8', (err, data) ->
    return cb err if err
    lines = data.split '\n'
    chain = {}
    for line in lines
      encode.addToChain chain, encode.splitSentence line
    encoder = new encode.Encoder chain
    binary = encoder.encode()
    writeBinary outFile, new Buffer(binary), cb

readFile = (name, encoding, cb) ->
  if name isnt '-'
    return fs.readFile name, {encoding: encoding}, cb
  chunks = []
  process.stdin.on 'data', (chunk) -> chunks.push chunk
  # TODO: Deal with the error.
  process.stdin.on 'end', -> cb null, chunks.join ''

writeBinary = (name, buffer, cb) ->
  if name isnt '-'
    return fs.writeFile name, buffer, {encoding: 'binary'}, cb
  process.stdout.write buffer
  cb()

readLines = (inFile, cb) ->
  readFile inFile, 'utf8', (err, data) ->
    return cb err if err
    bad = data.split '\n'
    lines = []
    for l in bad
      continue if l.trim().length is 0
      lines.push l
    cb null, lines

writeTop = (outFile, lines, top, cb) ->
  f = []
  f.push lines[t] for t in top
  writeBinary outFile, f.join('\n'), cb

getMostPopularWords = (sentences, max) ->
  count = {}
  for sentence in sentences
    for word in sentence
      if count[word]
        count[word]++
      else
        count[word] = 1
  list = []
  list.push [w, c] for w, c of count
  list.sort (a, b) -> b[1] - a[1]
  good = {}
  for i in [0 .. max - 1] by 1
    good[list[i]] = true
  good

getTop = (sentences, ordered, max) ->
  top = []
  nWords = 0
  words = {}
  for [i, score] in ordered
    for w in sentences[i]
      if not words[w]
        words[w] = true
        nWords++
        return top if nWords > max
    top.push i
  top

getOrdered = (sentences, popular) ->
  score = []
  for sentence, i in sentences
    s = 0
    for word in sentence
      s += popular[word]
    score.push [i, s]
  score.sort (a, b) -> b[1] - a[1]
