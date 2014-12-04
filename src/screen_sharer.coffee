ScreenShareError = require('./screen_share_base').ScreenShareError

ScreenSharer =
  get: (options={}, cb)->
    options.audio = false unless options.hasOwnProperty("audio")

    if navigator.webkitGetUserMedia
      ChromeScreenSharer = require('./chrome_screen_sharer')
      return new ChromeScreenSharer(options, cb)
    else if navigator.mozGetUserMedia
      FirefoxScreenSharer = require('./firefox_screen_sharer')
      return new FirefoxScreenSharer(options, cb)
    else
      return cb(new ScreenShareError("Screen sharing not implemented in this browser / environment."))


module.exports = ScreenSharer