generate = require '../src/generate'
require('chai').should()

describe 'generate', ->
  describe '#splitSentence', ->
    it 'should ignore multiple spaces', ->
      s = 'The  road goes ever \non and on.'
      c = 'The-road-goes-ever-on-and-on-.'.split '-'
      generate.splitSentence(s).should.deep.equal c
    it 'should ignore end spaces', ->
      s = ' The  road goes ever \non and on \n.\t '
      c = 'The-road-goes-ever-on-and-on-.'.split '-'
      generate.splitSentence(s).should.deep.equal c

