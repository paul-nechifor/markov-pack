fs = require 'fs'
optimist = require 'optimist'
generate = require './generate'

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

  .argv

  return optimist.showHelp() if argv.h

  generateChain argv.in, argv.out, (err) ->
    throw err if err

generateChain = (inFile, outFile, cb) ->
  readFile inFile, (err, data) ->
    return cb err if err
    lines = data.split '\n'
    chain = {}
    for line in lines
      generate.addToChain chain, generate.splitSentence line
    encoder = new generate.Encoder chain
    binary = encoder.encode()
    writeBinary outFile, new Buffer(binary), cb

readFile = (name, cb) ->
  if name isnt '-'
    return fs.readFile name, {encoding: 'utf8'}, cb
  chunks = []
  process.stdin.on 'data', (chunk) -> chunks.push chunk
  # TODO: Deal with the error.
  process.stdin.on 'end', -> cb null, chunks.join ''

writeBinary = (name, buffer, cb) ->
  if name isnt '-'
    return fs.writeFile name, buffer, {encoding: 'binary'}, cb
  process.stdout.write buffer
  cb()
