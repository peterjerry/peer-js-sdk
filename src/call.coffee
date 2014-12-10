noop = ->
module.exports = class CallObject
  constructor: (@initiated, @_data)->
    if @initiated
      @ongoing = true
    else
      @ongoing = false

  answer: (callback=noop)=>
    @ongoing = true
    CineIOPeer.join(@_data.room, callback)

  reject: (callback=noop)->
    @ongoing = false
    CineIOPeer._signalConnection.write action: 'call-reject', room: @_data.room, publicKey: CineIOPeer.config.publicKey
    callback()

  invite: (identity, callback=noop)->
    CineIOPeer.call identity, @_data.room, callback

  hangup: (callback=noop)->
    @ongoing = false
    CineIOPeer.leave @_data.room, callback

CineIOPeer = require('./main')
