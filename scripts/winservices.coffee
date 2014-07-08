# Description:
#   Control and Query Windows Services remotely from Linux
#
# Dependencies:
#   easy-table
#   Samba on the linux box hosting Hubot
#
# Configuration:
#
# Commands:
#   hubot s|service status <server> <service>
#   hubot s|service list - list all supported services and their aliases
#   hubot s|service start <alias>
#   hubot s|service stop <alias>
#   hubot s|service restart <alias>
#
# Author:
#   wrightling

Table = require 'easy-table'

serviceAliases =
  '06ecomm' : [{'service' : 'JBoss-Commerce',  'server' : 'nwltest06n2'},
               {'service' : 'JBoss-Commerce2', 'server' : 'nwltest06n2'}]
  '10ecomm' : [{'service' : 'JBoss-Commerce',  'server' : 'nwltest10n2'},
               {'service' : 'JBoss-Commerce2', 'server' : 'nwltest10n2'}]
  '17ecomm' : [{'service' : 'JBoss-Commerce',  'server' : 'nwltest17n2'}]
  'UATecomm': [{'service' : 'JBOSS-Commerce',  'server' : 'lsuatapp04'},
               {'service' : 'JBOSS-Commerce2', 'server' : 'lsuatapp04'}]

aliasIsValid = (msg, alias) ->
  if serviceAliases[alias] == undefined
    msg.send "Invalid alias '#{alias}'. Check available aliases with the list command"
  else
    true

wsStatus = (msg) ->
  server = msg.match[1]
  service = msg.match[2]
  status msg, server, service

wsStatusByAlias = (msg) ->
  alias = msg.match[1]
  if aliasIsValid msg, alias
    for serviceInfo in serviceAliases[alias]
      status msg, serviceInfo['server'], serviceInfo['service']

status = (msg, server, service) ->
  shellOutServiceRPC msg, 'status', server, service, statusSuccessMessage

wsStartService = (msg) ->
  alias = msg.match[1]
  if aliasIsValid msg, alias
    for serviceInfo in serviceAliases[alias]
      shellOutServiceRPC msg, 'start', serviceInfo['server'], serviceInfo['service']

wsStopService = (msg) ->
  alias = msg.match[1]
  if aliasIsValid msg, alias
    for serviceInfo in serviceAliases[alias]
      shellOutServiceRPC msg, 'stop', serviceInfo['server'], serviceInfo['service']

wsRestartService = (msg) ->
  alias = msg.match[1]
  if aliasIsValid msg, alias
    for serviceInfo in serviceAliases[alias]
      shellOutServiceRPC msg, 'stop', serviceInfo['server'], serviceInfo['service'], shellOutSucessMessage, 'start', 10000

wsListServices = (msg) ->
  table = new Table
  for alias, services of serviceAliases
    for serviceInfo in services
      table.cell 'Alias', alias
      table.cell 'Service', serviceInfo['service']
      table.cell 'Server', serviceInfo['server']
      table.newRow()

  msg.send table.toString()

shellOutServiceRPC = (msg, serviceCommand, server, service, onSuccess = shellOutSucessMessage, nextCommand = undefined, nextTimeout = 0) ->
  command = "net rpc service #{serviceCommand} #{service} -S #{server} -U '#{username()}%#{password()}'"
  exec = require('child_process').exec

  exec command, (error, stdout, stderr) ->
    msg.send "error=#{error}" if error?
    console.log "WinServices error=#{error} from command=#{command}" if error?
    msg.send onSuccess serviceCommand, server, service, command, stdout if stdout?

    if nextCommand?
      setTimeout shellOutServiceRPC, nextTimeout, msg, nextCommand, server, service unless error?

shellOutSucessMessage = (serviceCommand, server, service, command, stdout) ->
  "#{serviceCommand} request successful for service #{service} on #{server}"

statusSuccessMessage = (serviceCommand, server, service, command, stdout) ->
  successMessage = /\S+ service is running./i.exec stdout
  "-> #{successMessage.toString()}"

username = () ->
  process.env.HUBOT_WINSERVICES_USERNAME

password = () ->
  process.env.HUBOT_WINSERVICES_PASSWORD

module.exports = (robot) ->
  robot.respond /(?:s|service) status (\S+) (\S+)/i, (msg) ->
    wsStatus msg

  robot.respond /(?:s|service) list/i, (msg) ->
    wsListServices msg

  robot.respond /(?:s|service) status (\S+)$/i, (msg) ->
    wsStatusByAlias msg

  robot.respond /(?:s|service) start (\S+)$/i, (msg) ->
    wsStartService msg

  robot.respond /(?:s|service) stop (\S+)$/i, (msg) ->
    wsStopService msg

  robot.respond /(?:s|service) restart (\S+)$/i, (msg) ->
    wsRestartService msg
