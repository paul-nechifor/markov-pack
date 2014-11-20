encode = require '../src/encode'
decode = require '../src/decode'
require('chai').should()

###
  Helper functions
###

createWordList = (n) ->
  ret = []
  for i in [1 .. n] by 1
    ret.push '' + i
  ret

getASimpleChain = ->
  chain = {}
  sen = [
    '  the dog in the car has a big nose '
    '  the car has a big door '
    '  the car has a big door '
  ]
  for s in sen
    encode.addToChain chain, s.split ' '
  chain

checkConversion = (vSize, start, size, n, vCorrect) ->
  v = new Uint8Array vSize
  encode.writeBinary v, start, size, n
  v.should.deep.equal new Uint8Array vCorrect

checkDeconversion = (vSize, start, size, n, vCorrect) ->
  v = new Uint8Array vCorrect
  decode.readBinary v, start, size
  .should.deep.equal n

checkConversion2 = (vSize, start1, size1, n1, start2, size2, n2, vCorrect) ->
  v = new Uint8Array vSize
  encode.writeBinary v, start1, size1, n1
  encode.writeBinary v, start2, size2, n2
  v.should.deep.equal new Uint8Array vCorrect

split32in8 = (v) ->
  ret = []
  for n in v
    ret.push n >> 24,
        (n >> 16) & 0xff,
        (n >> 8) & 0xff,
        n & 0xff
  ret

###
  Reused values
###

exampleChain1 =
  '\t': {a: 2}
  '\ta': {cc: 2, a: 1}
  'a\t': {c: 2, ddddd: 4}
  'a\tcc': {b: 1}

wordList1 = createWordList 1200
wordList2 = ['', 'a', 'bb', 'cc', 'dddd']

readWriteData = [
  'should work with aligned full bytes'
  [4, 0, 24, 0x010203, [0x01, 0x02, 0x03, 0x00]]
  'should work with single bytes'
  [1, 0, 8, 153, [153]]
  'should work with incomplete first byte'
  [1, 0, 4, 0xf, [0xf0]]
  'should work with incomplete offset first byte'
  [1, 2, 4, 0xf, [0x3c]]
  'should work with incomplete last byte'
  [2, 0, 12, 0xfff, [0xff, 0xf0]]
  'should work with a byte across alignment'
  [2, 4, 8, 0xff, [0x0f, 0xf0]]
  'should work with aligned offsets'
  [4, 8, 16, 0xffff, [0x00, 0xff, 0xff, 0x00]]
  'should work with non aligned offsets'
  [3, 4, 16, 0xffff, [0x0f, 0xff, 0xf0]]
  'should work with 1 bit'
  [1, 4, 1, 1, [0x08]]
  'should work with 1 bit in first byte'
  [3, 7, 9, 0x1ff, [0x01, 0xff, 0x00]]
  'should work with 1 bit in last byte'
  [3, 8, 9, 0x1ff, [0x00, 0xff, 0x80]]
  'should work with 1 bit in the first and last byte'
  [3, 7, 10, 0x3ff, [0x01, 0xff, 0x80]]
  'should be able to work with 32 bits without an offset'
  [4, 0, 32, 0x12345678, [0x12, 0x34, 0x56, 0x78]]
  'should be able to work with 32 bits with an aligned offset'
  [5, 8, 32, 0x12345678, [0x00, 0x12, 0x34, 0x56, 0x78]]
  'should be able to work with 32 bits with a non aligned offset'
  [5, 4, 32, 0x12345678, [0x01, 0x23, 0x45, 0x67, 0x80]]
  'should be able to work with 32 bits with a long offset'
  [10, 40, 32, 0x12345678, [0, 0, 0, 0, 0, 0x12, 0x34, 0x56, 0x78, 0]]
]

###
  Tests
###

describe 'encode', ->
  describe '#splitSentence', ->
    it 'should ignore multiple spaces', ->
      s = 'The  road goes ever \non and on.'
      c = '--The-road-goes-ever-on-and-on-.-'.split '-'
      encode.splitSentence(s).should.deep.equal c
    it 'should ignore end spaces', ->
      s = ' The  road goes ever \non and on \n.\t '
      c = '--The-road-goes-ever-on-and-on-.-'.split '-'
      encode.splitSentence(s).should.deep.equal c

  describe '#addToChain', ->
    it 'should assign correct usage numbers', ->
      seq = 'a b c b c c b c'.split ' '
      chain = {}
      encode.addToChain chain, seq
      chain.should.deep.equal
        'a\tb': {c: 1}
        'b\tc': {b: 1, c: 1}
        'c\tb': {c: 2}
        'c\tc': {b: 1}
    it 'should ignore lists with too few elements', ->
      chain = {}
      encode.addToChain chain, ['a', 'b']
      chain.should.deep.equal {}
      encode.addToChain chain, []
      chain.should.deep.equal {}
    it 'should not allow the tab char in words', ->
      fn = -> encode.addToChain {}, ['a', 'b', 'aa\t']
      fn.should.throw Error, 'tab-not-allowed'
      fn = -> encode.addToChain {}, ['a', '\tb', 'cc', 'ddd']
      fn.should.throw Error, 'tab-not-allowed'

  describe '#getWords', ->
    next = {}
    # Start from 3 since 'next' and '' are also words.
    for i in [3 .. encode.MAX_WORDS] by 1
      next['' + i] = 1
    fullChain = next: next
    it 'should include empty words', ->
      encode.getWords exampleChain1
      .should.deep.equal '-a-b-c-cc-ddddd'.split '-'
    it 'should allow as many words as fit on 16 bits', ->
      fn = -> encode.getWords fullChain
      fn.should.not.throw Error, 'too-many-words'
    it 'should not allow more words than fit on 16 bits', ->
      fullChain.next['overflow'] = 1
      fn = -> encode.getWords fullChain
      fn.should.throw Error, 'too-many-words'

  describe '#getLengths', ->
    it 'should include empty words', ->
      encode.getLengths encode.getWords exampleChain1
      .should.deep.equal [[0, 1], [1, 3], [2, 1], [5, 1]]
    it 'should work with larger lists', ->
      encode.getLengths wordList1
      .should.deep.equal [[1, 9], [2, 90], [3, 900], [4, 201]]
    it 'ignore empty lists', ->
      encode.getLengths []
      .should.deep.equal []

  describe '#writePairOfLengths', ->
    it 'should work with an offset', ->
      lengths = encode.getLengths encode.getWords exampleChain1
      v = new Uint8Array 4 * (1 + 2 * lengths.length)
      encode.writePairOfLengths v, 32, lengths
      v.should.deep.equal new Uint8Array split32in8 [
        0, 0, 1, 1, 3, 2, 1, 5, 1
      ]
    it 'should work with larger lists', ->
      lengths = encode.getLengths wordList1
      v = new Uint8Array 4 * 2 * lengths.length
      encode.writePairOfLengths v, 0, lengths
      v.should.deep.equal new Uint8Array split32in8 [
        1, 9, 2, 90, 3, 900, 4, 201
      ]

  describe '#getWordToNumberMap', ->
    it 'should work with small lists', ->
      encode.getWordToNumberMap encode.getWords exampleChain1
      .should.deep.equal
        '': 0
        a: 1
        b: 2
        c: 3
        cc: 4
        ddddd: 5

  describe '#writeBinary', ->
    for i in [0 .. readWriteData.length - 1] by 2
      do (i) ->
        it readWriteData[i], ->
          checkConversion.apply null, readWriteData[i + 1]
    it 'should work with two writes', ->
      checkConversion2 3, 0, 8, 0xff, 16, 8, 0xff, [0xff, 0x00, 0xff]
    it 'should work with two same byte writes', ->
      checkConversion2 1, 0, 2, 0x3, 6, 2, 0x3, [0xc3]

  describe '#writeWordList', ->
    it 'should work with simple words', ->
      v = new Uint8Array 11
      encode.writeWordList v, 8, wordList2
      v.should.deep.equal new Uint8Array [
        0, 97, 98, 98, 99, 99, 100, 100, 100, 100, 0
      ]

  describe '#Header', ->
    h = new encode.Header
    describe '#setWordLengthsLen', ->
      it 'should work with small lists', ->
        h.setWordLengthsLen encode.getLengths encode.getWords exampleChain1
        h.wordLengthsLen.should.equal 4
      it 'should work with big lists', ->
        h.setWordLengthsLen encode.getLengths wordList1
        h.wordLengthsLen.should.equal 4
    describe '#setWordSize', ->
      it 'should work with small lists', ->
        h.setWordSize wordList2
        h.wordSize.should.equal 3
        h.wordTupleSize.should.equal 6
      it 'should work with big lists', ->
        h.setWordSize wordList1
        h.wordSize.should.equal 11
        h.wordTupleSize.should.equal 22
    describe '#setChainLen', ->
      it 'should work with small chains', ->
        h.setChainLen exampleChain1
        h.chainLen.should.equal 4
        h.hashTableLen.should.equal 5
      it 'should work with big chains', ->
        chain = {}
        for i in [1 .. 1234] by 1
          chain[i] = {'1': 1}
        h.setChainLen chain
        h.chainLen.should.equal 1234
        h.hashTableLen.should.equal 1523
    describe '#setContListAndWeightSizes', ->
      it 'should work with small chains', ->
        h.setContListAndWeightSizes
          a: {a: 1, b: 2, c: 3, d: 4, e: 5}
          b: {b: 1000, cc: 1}
        h.contListSize.should.equal 3
        h.weightSize.should.equal 10
    describe '#setChainBytesLen', ->
      it 'should work with small chains', ->
        chain =
          a: {a: 1, b: 2, c: 3, d: 4, e: 5}
          b: {b: 1000, cc: 1}
          c: {a: 1}
        h.setWordSize encode.getWords chain
        h.setContListAndWeightSizes chain
        h.setChainBytesLen chain
        full = 8 + (3 * 3) + 8 * (3 + 10)
        h.chainBytesLen.should.equal Math.ceil full / 8
    describe '#writeInBinary', ->
      it 'should write the header correctly', ->
        h.wordLengthsLen = 0x11111111
        h.chainLen = 0x22222222
        h.wordListLen = 0x33333333
        h.hashTableLen = 0x44444444
        h.chainBytesLen = 0x55555555
        h.wordSize = 0x66666666
        h.wordTupleSize = 0x77777777
        h.offsetSize = 0x88888888
        h.contListSize = 0x99999999
        h.weightSize = 0xaaaaaaaa
        b = new Uint8Array 10 * 4
        h.writeInBinary b
        b.should.deep.equal new Uint8Array split32in8 [
          h.magicNumber[0]
          (h.magicNumber[1] << 8) | h.version
          0x11111111
          0x22222222
          0x44444444
          0x55555555
          0x99999999
          0xaaaaaaaa
          0x00000000
          0x00000000
        ]

describe 'decode', ->
  chain = getASimpleChain()
  encoder = new encode.Encoder chain
  binary = encoder.encode()
  describe '#Header', ->
    describe '#decode', ->
      header = new decode.Header
      fn = -> header.decode binary
      it 'should check for the correct header', ->
        fn.should.not.throw Error, 'invalid-header'
      it 'should fail for incorrect headers', ->
        org = binary[0]
        binary[0] = 0
        fn.should.throw Error, 'invalid-header'
        binary[0] = org
      it 'should check for the supported version', ->
        fn.should.not.throw Error, 'invalid-version'
      it 'should fail for unsupported version', ->
        org = binary[7]
        binary[7] = 99
        fn.should.throw Error, 'unsupported-version'
        binary[7] = org
      values = [
        'wordLengthsLen'
        'chainLen'
        'hashTableLen'
        'chainBytesLen'
        'contListSize'
        'weightSize'
      ]

      for value in values
        do (value) ->
          it "should read #{value} correctly", ->
            header[value].should.equal encoder.header[value]

  describe '#Decoder', ->
    decoder = new decode.Decoder binary
    decoder.decode()

    describe '#decode', ->
      it 'should read the correct lengths', ->
        decoder.lengths.should.deep.equal encoder.lengths
      values = [
        'wordListLen'
        'wordSize'
        'wordTupleSize'
        'offsetSize'
        'wordListOffset'
        'hashTableOffset'
        'chainOffset'
        'totalByteSize'
      ]
      for value in values
        do (value) ->
          it "should set header.#{value} correctly", ->
            decoder.header[value].should.equal encoder.header[value]

    describe '#getWord', ->
      it 'should be able to get all the words', ->
        words = []
        for i in [0 .. encoder.words.length - 1] by 1
          words.push decoder.getWord i
        words.should.deep.equal encoder.words

    describe '#getContOffset', ->
      it 'should get the offsets correctly', ->
        correctOffsets = encoder.offsets
        offsets = {}
        for tuple, offset of correctOffsets
          offsets[tuple] = decoder.getContOffset tuple
        offsets.should.deep.equal correctOffsets

    describe '#sumWeights', ->
      it 'should sum weights correctly', ->
        correctSum = 0
        for word, weight of chain['\t']
          correctSum += weight
        decoder.sumWeights 0
        .should.equal correctSum
      it 'should sum weights correctly 2', ->
        for wTuple, conts of chain
          sum = 0
          sum += weight for word, weight of conts
          nTuple = encode.getNumberTuple encoder.header.wordSize, wTuple,
              encoder.map
          decoder.sumWeights nTuple
          .should.equal sum

  describe '#readBytes', ->
    for i in [0 .. readWriteData.length - 1] by 2
      do (i) ->
        it readWriteData[i], ->
          checkDeconversion.apply null, readWriteData[i + 1]
