Primus = require('../../src/vendor/primus')
BackboneEvents = require("backbone-events-standalone")

class PrimusStub
  constructor: ->
    BackboneEvents.mixin this
  write: ->

module.exports = ->
  beforeEach ->
    @primusConnectStub = sinon.stub Primus, 'connect', (signalingServerUrl)=>
      @primusStub = new PrimusStub

      sinon.stub @primusStub, 'write'

      @primusStub

  afterEach ->
    @primusConnectStub.restore()
