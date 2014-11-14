generate = require '../src/generate'
require('chai').should()

createWordList = (n) ->
  ret = []
  for i in [1 .. n]
    ret.push '' + i
  ret

exampleChain1 =
  '\t': {a: 2}
  '\ta': {cc: 2, a: 1}
  'a\t': {c: 2, ddddd: 4}
  'a\tcc': {b: 1}

wordList1 = createWordList 1200

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

  describe '#getLengths', ->
    it 'should include empty words', ->
      generate.getLengths generate.getWords exampleChain1
      .should.deep.equal [[0, 1], [1, 3], [2, 1], [5, 1]]
    it 'should work with larger lists', ->
      generate.getLengths wordList1
      .should.deep.equal [[1, 9], [2, 90], [3, 900], [4, 201]]
    it 'ignore empty lists', ->
      generate.getLengths []
      .should.deep.equal []

  describe '#getHeader', ->
    it 'should generate the correct header', ->
      generate.getHeader generate.getLengths generate.getWords exampleChain1
      .should.deep.equal new Uint8Array [
        0, 0, 0, 4

        0, 0, 0, 0
        0, 0, 0, 1

        0, 0, 0, 1
        0, 0, 0, 3

        0, 0, 0, 2
        0, 0, 0, 1

        0, 0, 0, 5
        0, 0, 0, 1
      ]
    it 'should work with larger lists', ->
      generate.getHeader generate.getLengths wordList1
      .should.deep.equal new Uint8Array [
        0, 0, 0, 4

        0, 0, 0, 1
        0, 0, 0, 9

        0, 0, 0, 2
        0, 0, 0, 90

        0, 0, 0, 3
        0, 0, 3, 135

        0, 0, 0, 4
        0, 0, 0, 201
      ]

  describe '#getWordToNumberMap', ->
    it 'should work with small lists', ->
      generate.getWordToNumberMap generate.getWords exampleChain1
      .should.deep.equal
        '': 0
        a: 1
        b: 2
        c: 3
        cc: 4
        ddddd: 5

  describe '#writeBinary', ->
    it 'should work with aligned full bytes', ->
      checkConversion 4, 0, 24, 0x010203, [0x01, 0x02, 0x03, 0x00]
    it 'should work with single bytes', ->
      checkConversion 1, 0, 8, 153, [153]
    it 'should work with incomplete first byte', ->
      checkConversion 1, 0, 4, 0xf, [0xf0]
    it 'should work with incomplete offset first byte', ->
      checkConversion 1, 2, 4, 0xf, [0x3c]
    it 'should work with incomplete last byte', ->
      checkConversion 2, 0, 12, 0xfff, [0xff, 0xf0]
    it 'should write a byte across alignment', ->
      checkConversion 2, 4, 8, 0xff, [0x0f, 0xf0]
    it 'should work with aligned offsets', ->
      checkConversion 4, 8, 16, 0xffff, [0x00, 0xff, 0xff, 0x00]
    it 'should work with non aligned offsets', ->
      checkConversion 3, 4, 16, 0xffff, [0x0f, 0xff, 0xf0]
    it 'should work with 1 bit', ->
      checkConversion 1, 4, 1, 1, [0x08]
    it 'should work with 1 bit in first byte', ->
      checkConversion 3, 7, 9, 0x1ff, [0x01, 0xff, 0x00]
    it 'should work with 1 bit in last byte', ->
      checkConversion 3, 8, 9, 0x1ff, [0x00, 0xff, 0x80]
    it 'should work with 1 bit in the first and last byte', ->
      checkConversion 3, 7, 10, 0x3ff, [0x01, 0xff, 0x80]

checkConversion = (vSize, start, size, n, vCorrect) ->
  v = new Uint8Array vSize
  generate.writeBinary v, start, size, n
  v.should.deep.equal new Uint8Array vCorrect
