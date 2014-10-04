# ## Takana Server
#
# A `Server` instance is the root object in a Takana procces. It
# is reposible for starting the HTTP server, `editor.Manager` and `browser.Manager`.

helpers         = require './support/helpers'
renderer        = require './renderer'
log             = require './support/logger'
editor          = require './editor'
browser         = require './browser'
watcher         = require './watcher'
connect         = require 'connect'
http            = require 'http'
shell           = require 'shelljs'
path            = require 'path'
express         = require 'express'
_               = require 'underscore'

# configuration options
Config = 
  editorPort:  48627
  httpPort:    48626
  rootDir:     helpers.sanitizePath('~/.takana/')
  scratchPath: helpers.sanitizePath('~/.takana/scratch')

class Server
  constructor: (@options={}) ->
    @logger = @options.logger || log.getLogger('Server')

    @options.editorPort   ?= Config.editorPort
    @options.rootDir      ?= Config.rootDir
    @options.httpPort     ?= Config.httpPort
    @options.scratchPath  ?= Config.scratchPath
    @options.includePaths ?= []

    @projectName = 'default'

    if (!@options.path)
      throw('specify a project path')


    @app         = express()
    @webServer  = http.createServer(@app)

    # the [Editor Manager](editor/manager.html) manages the editor TCP socket.
    @editorManager = new editor.Manager(
      port   : @options.editorPort
      logger : log.getLogger('EditorManager')
    )

    # the [Browser Manager](browser/manager.html) manages the browser websocket connections.
    @browserManager = new browser.Manager(
      webServer : @webServer
      logger    : log.getLogger('BrowserManager')
    )

    @folder      = new watcher.Folder(
      path        : @options.path
      scratchPath : @options.scratchPath
      extensions  : ['scss', 'css']
      logger      : @logger
    ) 

    @setupWebServer()
    @setupListeners()
  
  setupWebServer: ->
    # serve the client side JS for browsers that listen to live updates
    @app.use express.static(path.join(__dirname, '..', '/node_modules/takana-client/dist'))
    @app.use express.json()
    @app.use express.urlencoded()

    @app.use (req, res, next) =>
      res.setHeader 'X-Powered-By', 'Takana'
      next()

    @app.use (req, res, next) =>
      @logger.trace "[#{req.socket.remoteAddress}] #{req.method} #{req.headers.host} #{req.url}"
      next()

    @app.use '/live', express.static(@options.scratchPath)

  setupListeners: ->
    @folder.on 'updated', @handleFolderUpdate.bind(@)

    @editorManager.on 'buffer:update', (data) =>
      return unless data.path.indexOf(@options.path) == 0
      
      @logger.debug 'processing buffer:update', data.path
      @folder.bufferUpdate(data.path, data.buffer)

    @editorManager.on 'buffer:reset', (data) =>
      return unless data.path.indexOf(@options.path) == 0
      
      @logger.debug 'processing buffer:reset', data.path
      @folder.bufferClear(data.path)

    @browserManager.on 'stylesheet:resolve', (data, callback) =>
      match = helpers.pickBestFileForHref(data.href, _.keys(@folder.files))

      if typeof(match) == 'string'
        @logger.info 'matched', data.href, '---->', match
        callback(null, match) 
      else
        callback("no match for #{data.href}") 
        @logger.warn "couldn't find a match for", data.href, match || ''

    @browserManager.on 'stylesheet:listen', (data) =>
      @logger.debug 'processing stylesheet:listen', data.id
      @handleFolderUpdate()

  handleFolderUpdate: ->
    watchedStylesheets = @browserManager.watchedStylesheetsForProject(@projectName)
    console.log('watched stylesheets are:', watchedStylesheets);
    watchedStylesheets.forEach (p) =>
      return if !p

      file = @folder.getFile(p)
      if file
        console.log('found the file')
        fileHash = helpers.hashCode(file.path)
        renderer.for(file.scratchPath).render {
          file         : file.scratchPath, 
          includePaths : @includePaths
          writeToDisk  : true
        }, (error, result) =>
          if !error
            @logger.info 'rendered', file.scratchPath, @projectName, file.path, "live/#{path.relative(@options.scratchPath, file.scratchPath)}.css"
            @browserManager.stylesheetRendered(@projectName, file.path, "live/#{path.relative(@options.scratchPath, file.scratchPath)}.css")
          else
            @logger.warn 'error rendering', file.scratchPath, ':', error
      else
        @logger.warn "couldn't find a file for watched stylesheet", path


  start: (callback) ->
    shell.mkdir('-p', @options.rootDir)
    shell.mkdir('-p', @options.scratchPath)

    @editorManager.start()
    @browserManager.start()
    @folder.start()

    @webServer.listen @options.httpPort, =>
      @logger.info "webserver listening on #{@options.httpPort}"
      callback?()

  stop: (callback) ->
    @folder.stop()
    @editorManager.stop =>
      @webServer.close ->
        callback?()

module.exports = Server
