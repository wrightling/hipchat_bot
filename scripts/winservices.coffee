# Description:
#   Control and Query Windows Services remotely from Linux
#
# Dependencies:
#   Samba on the linux box hosting Hubot
#
# Configuration:
#
# Commands:
#   hubot ws|winservices status <server> <service>
#   hubot ws|winservices list <server>
#
# Author:
#   wrightling

wsStatus = (msg) ->
  server = msg.match[1]
  service = msg.match[2]
  command = "net rpc service status #{service} -S #{server} -U '#{username()}%#{password()}'"

  shellOut msg, command

wsList = (msg) ->
  server = msg.match[1]
  command = "net rpc service list -S #{server} -U '#{username()}%#{password()}'"

  shellOut msg, command

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
  robot.respond /(?:ws|winservices) status (\S+) (\S+)/i, (msg) ->
    wsStatus(msg)

  robot.respond /(?:ws|winservices) list (\S+)/i, (msg) ->
    wsList(msg)
