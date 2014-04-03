{Adapter,Robot,TextMessage,EnterMessage,LeaveMessage} = require 'hubot'

UppTalk = require 'upptalk'
util = require 'util'

class UppTalkBot extends Adapter

  constructor: ( robot ) ->
    @robot = robot
    @reconnectTryCount = 0

  run: ->
    options =
      username: process.env.HUBOT_UPPTALK_USERNAME
      password: process.env.HUBOT_UPPTALK_PASSWORD
      host: process.env.HUBOT_UPPTALK_HOST
      port: process.env.HUBOT_UPPTALK_PORT
      secure: process.env.HUBOT_UPPTALK_SECURE == 'true'
      apikey: process.env.HUBOT_UPPTALK_APIKEY

    @robot.logger.info util.inspect(options)

    @options = options
    @connected = false
    @makeClient()

  reconnect: () ->
    @reconnectTryCount += 1
    if @reconnectTryCount > 5
      @robot.logger.error 'Unable to reconnect to UppTalk server.'
      process.exit 1

    setTimeout () =>
      @robot.logger.info 'Hubot UppTalk reconnecting.'
      @client.open()
    , 5000

  makeClient: () ->
    options = @options

    @client = new UppTalk
      username: options.username
      password: options.password
      host: options.host
      port: options.port
      secure: options.secure
      apikey: options.apikey

    @configClient(options)

    @client.open()

  configClient: (options) ->
    @client.on 'error', @.error
    @client.on 'open', @.open
    @client.on 'close', @close
    @client.on 'message', @message

  close: =>
    @robot.logger.info 'Hubot UppTalk closed, attempting to reconnect'
    @reconnect()

  error: (error) =>
    @robot.logger.error error

  open: =>
    @robot.logger.info 'Hubot UppTalk open'

    @client.exec 'authenticate',
      username: @options.username
      password: @options.password
      @authenticated

  authenticated: (err) =>
    if err
      @robot.logger.info 'Hubot UppTalk authentication failed'
      process.exit()

    @robot.logger.info 'Hubot UppTalk authenticated'

    @client.exec 'presence'
    @robot.logger.info 'Hubot UppTalk sent presence'

    # @emit if @connected then 'reconnected' else 'connected'
    @emit 'connected'
    @connected = true

  message: (m) =>

    if m.method != 'chat'
      return
    p = m.payload
    if !p
      return
    if !p.user
      return
    if !p.text
      return
    # ignore offline messages
    if p.timestamp
      return

    @robot.logger.debug "Received message: #{p.text} from: #{p.user}"

    user = @robot.brain.userForId p.user
    user.name = p.name or p.user

    if p.group
      user.room = p.group
    else
      delete user.room
      #hack to avoid having to prepand commands with hubot name
      if p.text.toLowerCase().indexOf @robot.name.toLowerCase() != 0
        p.text = 'hubot ' + p.text

    @receive new TextMessage(user, p.text, p.id)

    if (p.id && p.receipt != false)
      @client.exec 'receipt', {user: p.user, type: 'received', id: p.id}

  chat: (user, text) ->
    lines = text.split '\n'
    for line in lines
      @robot.logger.debug "Sending message: #{line} to user: #{user}"
      @client.notify 'chat',
        text: line
        id: Math.random().toString()
        receipt: false
        user: user

  group: (group, text) ->
    lines = text.split '\n'
    for line in lines
      @robot.logger.debug "Sending message: #{line} to group: #{group}"
      @client.notify 'chat',
        text: line
        id: Math.random().toString()
        receipt: false
        group: group

  send: (envelope, messages...) ->
    if envelope.room
      for msg in messages
        @group envelope.room, msg
    else
      for msg in messages
        @chat envelope.user.id, msg

  reply: (envelope, messages...) ->
    console.log 'reply'
    console.log arguments
    # for msg in messages
      # @chat envelope.user.id, msg
    # for msg in messages
    #   # ltx.Element?
    #   if msg.attrs?
    #     @send envelope, msg
    #   else
    #     @send envelope, "#{envelope.user.name}: #{msg}"

  exports.use = (robot) ->
    new UppTalkBot robot
