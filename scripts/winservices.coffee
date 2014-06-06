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
#
# Author:
#   wrightling

Table = require 'easy-table'

serviceAliases =
  '06ecomm' : [{'service' : 'JBoss-Commerce',  'server' : 'nwltest06n2'},
               {'service' : 'JBoss-Commerce2', 'server' : 'nwltest06n2'}]

wsStatus = (msg) ->
  server = msg.match[1]
  service = msg.match[2]
  status msg, server, service

wsStatusByAlias = (msg) ->
  alias = msg.match[1]
  if serviceAliases[alias] == undefined
    msg.send "Invalid alias #{alias}.  Check available aliases with the list command"

  for serviceInfo in serviceAliases[alias]
    status msg, serviceInfo['server'], serviceInfo['service']

status = (msg, server, service) ->
  command = "net rpc service status #{service} -S #{server} -U '#{username()}%#{password()}'"

  shellOut msg, command

wsListServices = (msg) ->
  table = new Table
  for alias, services of serviceAliases
    for serviceInfo in services
      table.cell 'Alias', alias
      table.cell 'Service', serviceInfo['service']
      table.cell 'Server', serviceInfo['server']
      table.newRow()

  msg.send table.toString()

shellOut = (msg, command) ->
  exec = require('child_process').exec

  exec command, (error, stdout, stderr) ->
    msg.send "error=#{error}" if error
    msg.send stdout if stdout
    msg.send "stderr=#{stderr}" if stderr

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
