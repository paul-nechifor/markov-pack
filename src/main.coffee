fs = require 'fs'
optimist = require 'optimist'
generate = require './generate'

module.exports = main = ->
  argv = optimist
  .usage 'Usage: $0 [options]'

  .alias 'i', 'in'
  .describe 'i', 'The input file (1 sentence per line).'

  .default 'o', 'out.makpak'
  .alias 'o', 'out'
  .describe 'o', 'The path to the output file.'

  .alias 'h', 'help'
  .describe 'h', 'Print this help message.'

  .argv

  return optimist.showHelp() if argv.h

  generateChain argv.in, argv.out, (err) ->
    throw err if err

generateChain = (inFile, outFile, cb) ->
  fs.readFile inFile, {encoding: 'utf8'}, (err, data) ->
    return cb err if err
    lines = data.split '\n'
    chain = {}
    for line in lines
      generate.addToChain chain, generate.splitSentence line
    binary = generate.generateBinary chain
    fs.writeFile outFile, new Buffer(binary), {encoding: 'binary'}, cb
