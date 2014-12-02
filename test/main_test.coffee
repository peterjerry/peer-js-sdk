setupAndTeardown = require('./helpers/setup_and_teardown')
CineIOPeer = require('../src/main')
stubPrimus = require('./helpers/stub_primus')
stubUserMedia = require('./helpers/stub_user_media')

describe 'CineIOPeer', ->
  setupAndTeardown()
  stubPrimus()

  describe '.version', ->
    it 'has a version', ->
      expect(CineIOPeer.version).to.equal('0.0.1')

  describe '.reset', ->
    it 'resets the config', ->
      CineIOPeer.config = {some: 'random', config: 'setting'}
      CineIOPeer.reset()
      expect(CineIOPeer.config).to.deep.equal(rooms: [], videoElements: {})

  describe '.init', ->

    setupDataTrigger = (cb)->
      @dataTrigger = cb
      CineIOPeer.on 'info', @dataTrigger

    afterEach ->
      CineIOPeer.off 'info', @dataTrigger

    it 'initializes the config', (done)->
      setupDataTrigger.call this, ->
        done()
      CineIOPeer.init(publicKey: 'my-public-key')
      expect(CineIOPeer.config).to.deep.equal(publicKey: 'my-public-key', rooms: [], videoElements: {})

    it 'checks for support', (done)->
      setupDataTrigger.call this, (data)->
        expect(data).to.deep.equal(support: true)
        done()
      CineIOPeer.init(publicKey: 'my-public-key')

  describe 'after initialized', ->

    beforeEach (done)->
      @dataTrigger = (data)->
        done()
      CineIOPeer.on 'info', @dataTrigger
      CineIOPeer.init(publicKey: 'the-public-key')

    afterEach ->
      CineIOPeer.off 'info', @dataTrigger

    describe '.identify', ->
      it 'sets an identity', ->
        CineIOPeer.identify('Minerva McGonagall')
        expect(CineIOPeer.config.identity).to.equal('Minerva McGonagall')

      it 'writes to the signaling connection', ->
        CineIOPeer.identify('Minerva McGonagall')
        expect(@primusStub.write.calledOnce).to.be.true
        args = @primusStub.write.firstCall.args
        expect(args).to.have.length
        expect(args[0]).to.deep.equal(action: 'identify', identity: 'Minerva McGonagall', publicKey: 'the-public-key', client: 'web')

    describe '.call', ->
      stubUserMedia()

      beforeEach ->
        CineIOPeer.identify('Minerva McGonagall')

      it 'fetches media', (done)->
        CineIOPeer.call "Albus Dumbledore", (err)->
          expect(err).to.be.undefined
          expect(CineIOPeer._unsafeGetUserMedia.calledOnce).to.be.true
          args = CineIOPeer._unsafeGetUserMedia.firstCall.args
          expect(args).to.have.length(2)
          expect(args[0]).to.deep.equal(audio: true, video: true)
          expect(args[1]).to.be.a('function')
          done()

      it 'writes to the signaling connection', (done)->
        CineIOPeer.call "Albus Dumbledore", (err)=>
          expect(err).to.be.undefined
          expect(@primusStub.write.calledTwice).to.be.true
          args = @primusStub.write.secondCall.args
          expect(args).to.have.length
          expect(args[0]).to.deep.equal(action: 'call', otheridentity: 'Albus Dumbledore', identity: 'Minerva McGonagall', publicKey: 'the-public-key')
          done()

    describe '.join', ->
      stubUserMedia()

      it 'fetches media', (done)->
        CineIOPeer.join "Gryffindor Common Room", (err)->
          expect(err).to.be.undefined
          expect(CineIOPeer._unsafeGetUserMedia.calledOnce).to.be.true
          args = CineIOPeer._unsafeGetUserMedia.firstCall.args
          expect(args).to.have.length(2)
          expect(args[0]).to.deep.equal(audio: true, video: true)
          expect(args[1]).to.be.a('function')
          done()

      it 'adds the room to the list of rooms', (done)->
        CineIOPeer.join "Gryffindor Common Room", (err)->
          expect(err).to.be.undefined
          expect(CineIOPeer.config.rooms).to.deep.equal(['Gryffindor Common Room'])
          done()

      it 'writes to the signaling connection', (done)->
        CineIOPeer.join "Gryffindor Common Room", (err)=>
          expect(err).to.be.undefined
          expect(@primusStub.write.calledOnce).to.be.true
          args = @primusStub.write.firstCall.args
          expect(args).to.have.length
          expect(args[0]).to.deep.equal(action: 'join', room: 'Gryffindor Common Room', publicKey: 'the-public-key')
          done()

    describe '.leave', ->
      stubUserMedia()

      it 'requires the user have previously joined the room', (done)->
        errorHandler = (data)->
          expect(data).to.deep.equal(msg: "not connected to room", room: "Gryffindor Common Room")
          CineIOPeer.off 'error', errorHandler
          done()
        CineIOPeer.on 'error', errorHandler
        CineIOPeer.leave "Gryffindor Common Room"

      it 'removes the room to the list of rooms', (done)->
        CineIOPeer.join "Gryffindor Common Room", (err)->
          expect(err).to.be.undefined
          expect(CineIOPeer.config.rooms).to.contain("Gryffindor Common Room")
          CineIOPeer.leave("Gryffindor Common Room")
          expect(CineIOPeer.config.rooms).not.to.contain("Gryffindor Common Room")
          done()

      it 'writes to the signaling connection', (done)->
        CineIOPeer.join "Gryffindor Common Room", (err)=>
          expect(err).to.be.undefined
          CineIOPeer.leave("Gryffindor Common Room")
          expect(@primusStub.write.calledTwice).to.be.true
          args = @primusStub.write.secondCall.args
          expect(args).to.have.length
          expect(args[0]).to.deep.equal(action: 'leave', room: 'Gryffindor Common Room', publicKey: 'the-public-key')
          done()

    describe '.fetchMedia', ->
      describe 'success', ->
        stubUserMedia()

        it 'fetches media', (done)->
          CineIOPeer.fetchMedia (err)->
            expect(err).to.be.undefined
            expect(CineIOPeer._unsafeGetUserMedia.calledOnce).to.be.true
            args = CineIOPeer._unsafeGetUserMedia.firstCall.args
            expect(args).to.have.length(2)
            expect(args[0]).to.deep.equal(audio: true, video: true)
            expect(args[1]).to.be.a('function')
            done()

        it 'will not fetch twice', (done)->
          CineIOPeer.fetchMedia (err)->
            expect(err).to.be.undefined
            CineIOPeer.fetchMedia (err)->
              expect(err).to.be.undefined
              expect(CineIOPeer._unsafeGetUserMedia.calledOnce).to.be.true
              args = CineIOPeer._unsafeGetUserMedia.firstCall.args
              expect(args).to.have.length(2)
              expect(args[0]).to.deep.equal(audio: true, video: true)
              expect(args[1]).to.be.a('function')
              done()

        it 'triggers media with the stream and media true', (done)->
          mediaResponse = (data)->
            expect(data.media).to.be.true
            CineIOPeer.off 'media', mediaResponse
            done()
          CineIOPeer.on 'media', mediaResponse
          CineIOPeer.fetchMedia()
      describe 'failure', ->
        stubUserMedia(false)

        it 'returns with the error', (done)->
          mediaResponse = (data)->
            expect(data.media).to.be.false
            CineIOPeer.off 'media', mediaResponse
            done()
          CineIOPeer.on 'media', mediaResponse
          CineIOPeer.fetchMedia (err)->
            expect(err).to.equal('could not fetch media')

        it 'triggers media with the stream and media false', (done)->
          mediaResponse = (data)->
            expect(data.media).to.be.false
            CineIOPeer.off 'media', mediaResponse
            done()
          CineIOPeer.on 'media', mediaResponse
          CineIOPeer.fetchMedia()
