# Description:
#   Control and Query Windows Services remotely from Linux
#
# Dependencies:
#   Samba on the linux box hosting Hubot
#
# Configuration:
#
# Commands:
#   hubot winservices status <server> <service>
#
# Author:
#   wrightling

wsStatus = (msg) ->
  server = msg.match[1]
  service = msg.match[2]
  username = process.env.HUBOT_WINSERVICES_USERNAME
  password = process.env.HUBOT_WINSERVICES_PASSWORD

  exec = require('child_process').exec
  command = "net rpc service status #{service} -S #{server} -U '#{username}%#{password}'"

  msg.send msg.match
  exec command, (error, stdout, stderr) ->
    msg.send "error=#{error}" if error
    msg.send "stdout=#{stdout}" if stdout
    msg.send "stderr=#{stderr}" if stderr

module.exports = (robot) ->
  robot.respond /(?:ws|winservices) status (\S+) (\S+)/i, (msg) ->
    wsStatus(msg)
