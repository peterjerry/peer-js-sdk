PeerConnection = require('rtcpeerconnection')
Primus = require('./vendor/primus')
Config = require('./config')

connectToCineSignaling = ->
  Primus.connect(Config.signalingServer)

PENDING = 1

class Connection
  constructor: ->
    @iceServers = null
    @fetchedIce = false
    @peerConnections = {}
    @primus = connectToCineSignaling()
    @primus.on 'data', @_signalHandler

  write: =>
    @primus.write(arguments...)

  newLocalStream: (stream)=>
    for otherClientSparkId, peerConnection of @peerConnections
      # console.log "adding local screen stream", stream.id
      peerConnection.addStream(stream)

  _signalHandler: (data)=>
    # console.log("got data")
    switch data.action
      when 'allservers'
        console.log('setting config', data)
        @iceServers = data.data
        @fetchedIce = true
        CineIOPeer.trigger('gotIceServers')

      when 'incomingcall'
        # console.log('got incoming call', data)
        CineIOPeer.trigger('incomingCall', call: new CallObject(data))

      when 'leave'
        # console.log('leaving', data)
        return unless @peerConnections[data.sparkId]
        @peerConnections[data.sparkId].close()
        delete @peerConnections[data.sparkId]

      when 'member'
        console.log('got new member', data)
        @_ensurePeerConnection(data.sparkId, offer: true)

      # peerConnection standard config
      when 'ice'
        #console.log('got remote ice', data)
        return unless data.sparkId
        @_ensurePeerConnection data.sparkId, offer: false, (err, pc)=>
          pc.processIce(data.candidate)

      # peerConnection standard config
      when 'offer'
        otherClientSparkId = data.sparkId
        # console.log('got offer', data)
        @_ensurePeerConnection otherClientSparkId, offer: false, (err, pc)->
          pc.handleOffer data.offer, (err)=>
          # console.log('handled offer', err)
            pc.answer (err, answer)=>
              @write action: 'answer', source: "web", answer: answer, sparkId: otherClientSparkId

      # peerConnection standard config
      when 'answer'
        # console.log('got answer', data)
        @_ensurePeerConnection data.sparkId, offer: false, (err, pc)->
          pc.handleAnswer(data.answer)
      # else
      #   console.log("UNKNOWN DATA", data)

  _newMember: (otherClientSparkId, options, callback)=>
    # we must be pending to get ice candidates, do not create a new pc
    if @peerConnections[otherClientSparkId]
      return @_ensureIce =>
        callback(null, @peerConnections[otherClientSparkId])

    @peerConnections[otherClientSparkId] = PENDING
    @_ensureIce =>
      console.log("CREATING NEW PEER CONNECTION!!", otherClientSparkId, options)
      peerConnection = @_initializeNewPeerConnection(sparkId: otherClientSparkId, iceServers: @iceServers)
      @peerConnections[otherClientSparkId] = peerConnection
      peerConnection.videoEls = []
      # console.log("CineIOPeer.stream", CineIOPeer.stream)
      streamAttached = false
      if CineIOPeer.stream
        peerConnection.addStream(CineIOPeer.stream)
        streamAttached = true
      if CineIOPeer.screenShareStream
        peerConnection.addStream(CineIOPeer.screenShareStream)
        streamAttached = true

      console.warn("No stream attached") unless streamAttached

      peerConnection.on 'addStream', (event)->
        # console.log("got remote stream", event)
        videoEl = CineIOPeer._createVideoElementFromStream(event.stream, muted: false, mirror: false)
        peerConnection.videoEls.push videoEl
        CineIOPeer.trigger 'mediaAdded',
          peerConnection: peerConnection
          videoElement: videoEl
          remote: true

      peerConnection.on 'removeStream', (event)->
        # console.log("got remote stream", event)
        videoEl = CineIOPeer._getVideoElementFromStream(event.stream)
        index = peerConnection.videoEls.indexOf(videoEl)
        peerConnection.videoEls.splice(index, 1) if index > -1

        CineIOPeer.trigger 'mediaRemoved',
          peerConnection: peerConnection
          videoElement: videoEl
          remote: true

      peerConnection.on 'ice', (candidate)=>
        #console.log('got my ice', candidate.candidate.candidate)
        @write action: 'ice', source: "web", candidate: candidate, sparkId: otherClientSparkId

      if options.offer
        # console.log('sending offer')
        peerConnection.offer (err, offer)=>
          console.log('offering', otherClientSparkId)
          @write action: 'offer', source: "web", offer: offer, sparkId: otherClientSparkId


      peerConnection.on 'close', (event)->
        # console.log("remote closed", event)
        for videoEl in peerConnection.videoEls
          CineIOPeer.trigger 'mediaRemoved',
            peerConnection: peerConnection
            videoElement: videoEl
            remote: true
        delete peerConnection.videoEls

  _ensurePeerConnection: (otherClientSparkId, options, callback)=>
    candidate = @peerConnections[otherClientSparkId]
    if candidate && candidate != PENDING
      return setTimeout ->
        callback null, candidate
    @_newMember(otherClientSparkId, options, callback)

  _ensureIce: (callback)=>
      return setTimeout callback if @fetchedIce
      CineIOPeer.once 'gotIceServers', callback

  _initializeNewPeerConnection: (options)->
    new PeerConnection(options)

exports.connect = ->
  new Connection

CineIOPeer = require('./main')
CallObject = require('./call')
