{allowUnsafeEval, allowUnsafeNewFunction} = require 'loophole'
_ = require 'underscore-plus'

module.exports =
class Server

  process: null
  rootPath: null
  embeddedTernServer:null

  constructor: (rootPath) ->
    @rootPath = rootPath

  start: (callback) ->
    path = require 'path'
    command = path.resolve __dirname, '../node_modules/.bin/tern'
    args = ['--persistent', '--no-port-file', '--verbose']
    options =
      cwd: @rootPath
    stdout = (output) ->
      output = output.split(' ')
      port = parseInt(output[output.length - 1])
      return if isNaN(port) or port is 0
      callback port

    if @isPlatformWindows()
      {BufferedProcess} = require 'atom'
      @process = new BufferedProcess {command, args, options, stdout, @stderr, @exit}
    else
      {BufferedNodeProcess} = require 'atom'
      @process = new BufferedNodeProcess {command, args, options, stdout, @stderr, @exit}

  stop: ->
    @process?.kill()
    @process = null

  stderr: (output) ->
    content = "atom-ternjs<br />" + output
    atom.notifications.addError(content, dismissable: true)

  exit: (code) ->
    content = "tern exited with code: #{code}.<br />Restart the server via Packages -> Atom Ternjs -> Restart server"
    atom.notifications.addError(content, dismissable: true)

  isPlatformWindows: ->
    document.getElementsByTagName('body')[0].classList.toString().indexOf('platform-win') > -1

  initializeEmbeddedTernServer: (manager)->
    @embeddedTernServer = allowUnsafeEval =>
      allowUnsafeNewFunction =>
        new (require '../node_modules/tern/lib/tern.js').Server(@getTernEmbeddedServerConfig(manager))

  getTernEmbeddedServerConfig: (manager)->
    #get the .tern_project
    defaultConfig =
      libs: [],
      loadEagerly: false,
      plugins: {},
      ecmaScript: true,
      ecmaVersion: 6,
    if manager.helper.fileExists(@rootPath+'/.tern-project') isnt false
      projectConfig = JSON.parse fs.readFileSync(@rootPath+'/.tern-project','utf8')
    homeDir = process.env.HOME || process.env.HOMEPATH || process.env.USERPROFILE
    if manager.helper.fileExists(homeDir+'/.tern-config') isnt false
      ternConfig = JSON.parse fs.readFileSync(homeDir+'/.tern-config','utf8')
    config = projectConfig || ternConfig || defaultConfig
    defs = @loadDefs(manager,config)
    plugins = @loadPlugins(manager,config)
    config =
      getFile:(name,c)=>
        if managet.helper.fileExists(@rootPath+'/'+name) isnt false
          fs.readFile(@rootPath+'/'+name,'utf8',c)
        else
          c('Error in getting file')
      plugins:plugins,
      defs:defs,
      async: true,
    return config

  loadDefs:(manager,config)->
    #return browser defs for now
    defs = []
    config.libs.forEach (lib)->
      if manager.helper.fileExists(__dirname+'/../node_modules/tern/defs/'+lib+'.json') isnt false
        defs.push JSON.parse fs.readFileSync(__dirname+'/../node_modules/tern/defs/'+lib+'.json','utf8')
    return defs


  loadPlugins:(manager,config)->
    {}#return no plugins for now

  getEmbeddedTernServer: ->
    @embeddedTernServer
