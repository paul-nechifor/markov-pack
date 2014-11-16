common = require './common'

exports.Header = class Header extends common.Header
  decode: (b) ->
    m1 = (b[0] << 24) | (b[1] << 16) | (b[2] << 8) | b[3]
    m2 = (b[4] << 16) | (b[5] << 8) | b[6]
    if m1 isnt @magicNumber[0] or m2 isnt @magicNumber[1]
      throw Error 'invalid-header'
    if b[7] isnt @version
      throw Error 'unsupported-version'
    return

exports.Decoder = class Decoder
  constructor: (@binary) ->
    @header = new Header

  init: ->
    @header.decode @binary
