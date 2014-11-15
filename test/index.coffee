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
wordList2 = ['', 'a', 'bb', 'cc', 'dddd']

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

  describe '#writePairOfLengths', ->
    it 'should work with an offset', ->
      lengths = generate.getLengths generate.getWords exampleChain1
      v = new Uint8Array 4 * (1 + 2 * lengths.length)
      generate.writePairOfLengths v, 32, lengths
      v.should.deep.equal new Uint8Array [
        0, 0, 0, 0

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
      lengths = generate.getLengths wordList1
      v = new Uint8Array 4 * 2 * lengths.length
      generate.writePairOfLengths v, 0, lengths
      v.should.deep.equal new Uint8Array [
        0, 0, 0, 1
        0, 0, 0, 9

        0, 0, 0, 2
        0, 0, 0, 90

        0, 0, 0, 3
        0, 0, 3, 132

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
    it 'should be able to write 32 bits without an offset', ->
      checkConversion 4, 0, 32, 0x12345678, [0x12, 0x34, 0x56, 0x78]
    it 'should be able to write 32 bits with an aligned offset', ->
      checkConversion 5, 8, 32, 0x12345678, [0x00, 0x12, 0x34, 0x56, 0x78]
    it 'should be able to write 32 bits with a non aligned offset', ->
      checkConversion 5, 4, 32, 0x12345678, [0x01, 0x23, 0x45, 0x67, 0x80]
    it 'should be able to write 32 bits with a long offset', ->
      checkConversion 10, 40, 32, 0x12345678,
          [0, 0, 0, 0, 0, 0x12, 0x34, 0x56, 0x78, 0]
    it 'should work with two writes', ->
      checkConversion2 3, 0, 8, 0xff, 16, 8, 0xff, [0xff, 0x00, 0xff]
    it 'should work with two same byte writes', ->
      checkConversion2 1, 0, 2, 0x3, 6, 2, 0x3, [0xc3]

  describe '#writeWordList', ->
    it 'should work with simple words', ->
      v = new Uint8Array 11
      generate.writeWordList v, 8, wordList2
      v.should.deep.equal new Uint8Array [
        0, 97, 98, 98, 99, 99, 100, 100, 100, 100, 0
      ]

  describe '#Header', ->
    describe '#writeWordSize', ->
      it 'should work with small lists', ->
        header = new generate.Header
        header.setWordSize wordList2
        header.wordSize.should.equal 3
      it 'should work with big lists', ->
        header = new generate.Header
        header.setWordSize wordList1
        header.wordSize.should.equal 11
      it 'should work with small chains', ->
        header = new generate.Header
        header.setChainLen exampleChain1
        header.chainLen.should.equal 4
        header.hashTableLen.should.equal 5
      it 'should work with big chains', ->
        chain = {}
        for i in [1 .. 1234]
          chain[i] = {'1': 1}
        header = new generate.Header
        header.setChainLen chain
        header.chainLen.should.equal 1234
        header.hashTableLen.should.equal 1523

checkConversion = (vSize, start, size, n, vCorrect) ->
  v = new Uint8Array vSize
  generate.writeBinary v, start, size, n
  v.should.deep.equal new Uint8Array vCorrect

checkConversion2 = (vSize, start1, size1, n1, start2, size2, n2, vCorrect) ->
  v = new Uint8Array vSize
  generate.writeBinary v, start1, size1, n1
  generate.writeBinary v, start2, size2, n2
  v.should.deep.equal new Uint8Array vCorrect
