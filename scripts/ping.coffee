# Description:
#   Utility commands surrounding Hubot uptime.
#
# Commands:
#   hubot ping - Reply with pong
#   hubot echo <text> - Reply back with <text>
#   hubot time - Reply with current time
#   hubot die - End hubot process

module.exports = (robot) ->
  robot.respond /PING$/i, (msg) ->
    msg.send "PONG"

  robot.respond /ECHO (.*)$/i, (msg) ->
    msg.send msg.match[1]

  robot.respond /TIME$/i, (msg) ->
    msg.send "Server time is: #{new Date()}"

  robot.respond /DIE$/i, (msg) ->
    if robot.auth.hasRole(msg.envelope.user, 'admin')
      msg.send "Goodbye, cruel world."
      process.exit 0
    else
      user = robot.brain.userForId(msg.envelope.user.id)
      msg.send "#{user.id}, #{user.name}, #{user.roles}"
      msg.send "User #{msg.envelope.user.id} has roles #{user.roles}"
      msg.send "You do not have permission to kill me"

