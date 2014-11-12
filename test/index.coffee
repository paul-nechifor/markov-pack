generate = require '../src/generate'
require('chai').should()

exampleChain1 =
  '\t': {a: 2}
  '\ta': {cc: 2, a: 1}
  'a\t': {c: 2, ddddd: 4}
  'a\tcc': {b: 1}

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

  describe '#addToChain', ->
    it 'should assign correct usage numbers', ->
      seq = 'a b c b c c b c'.split ' '
      chain = {}
      generate.addToChain chain, seq
      chain.should.deep.equal
        'a\tb': {c: 1}
        'b\tc': {b: 1, c: 1}
        'c\tb': {c: 2}
        'c\tc': {b: 1}
    it 'should ignore lists with too few elements', ->
      chain = {}
      generate.addToChain chain, ['a', 'b']
      chain.should.deep.equal {}
      generate.addToChain chain, []
      chain.should.deep.equal {}
    it 'should not allow the tab char in words', ->
      fn = -> generate.addToChain {}, ['a', 'b', 'aa\t']
      fn.should.throw Error, 'tab-not-allowed'
      fn = -> generate.addToChain {}, ['a', '\tb', 'cc', 'ddd']
      fn.should.throw Error, 'tab-not-allowed'

  describe '#getWords', ->
    it 'should include empty words', ->
      generate.getWords exampleChain1
      .should.deep.equal '-a-b-c-cc-ddddd'.split '-'
