# Description:
#   Interact with your Jenkins CI server
#
# Dependencies:
#   easy-table
#
# Configuration:
#   HUBOT_JENKINS_URL
#   HUBOT_JENKINS_AUTH
#   HUBOT_JENKINS_POLL_INTERVAL
#
# Commands:
#   hubot jenkins build <job> - builds the specified Jenkins job
#   hubot jenkins build <job>, <params> - builds the specified Jenkins job with parameters as key=value&key2=value2
#   hubot jenkins list <filter> - lists Jenkins jobs
#   hubot jenkins describe <job> - Describes the specified Jenkins job
#   hubot jenkins aliases - list known aliases for jenkins jobs

#
# Author:
#   dougcole, wrightling

querystring = require 'querystring'
Table = require 'easy-table'
pollInterval = process.env.HUBOT_JENKINS_POLL_INTERVAL

jobAliases =
  '06admin'    : 'LS DEPLOY NWLTEST06 Admin (trunk)'
  '06ecomm'    : 'LS-DEPLOY-NWLTEST06-Commerce-(trunk)'
  '06rws'      : 'LS DEPLOY NWLTEST06 Corp Regional (trunk)'
  '06sites'    : 'LS DEPLOY NWLTEST06 Sites (trunk)'
  '06services' : 'LS DEPLOY NWLTEST06 Services (trunk)'
  '06style'    : 'LS DEPLOY NWLTEST06 Style Guide (trunk)'
  '06tools'    : 'LS DEPLOY NWLTEST06 Tools (trunk)'
  '10admin'    : 'WO DEPLOY NWLTEST10 Admin (trunk)'
  '10ecomm'    : 'WO-DEPLOY-NWLTEST10-Commerce-(trunk)'
  '10rws'      : 'WO DEPLOY NWLTEST10 Corp Regional (trunk)'
  '10services' : 'WO DEPLOY NWLTEST10 Services (trunk)'
  '10sites'    : 'WO DEPLOY NWLTEST10 Sites (trunk)'
  '10style'    : 'WO DEPLOY NWLTEST10 Style Guide (trunk)'
  '10tools'    : 'WO DEPLOY NWLTEST10 Tools (trunk)'
  'emgr'       : 'CORE5_DEPLOY_nwl-eventmanager_(trunk)'

jenkinsBuild = (msg) ->
  req = prepRequest msg, (url, job) ->
    params = msg.match[3]
    if params then "#{url}/job/#{job}/buildWithParameters?#{params}" else "#{url}/job/#{job}/build"

  req.post() (err, res, body) ->
    if err
      msg.send "Jenkins says: #{err}"
      console.log("Jenkins error = #{err}")
    else if 200 <= res.statusCode < 400
      msg.send "#{res.statusCode} Build started for #{req.job} #{res.headers.location}"
      setTimeout startPollingForBuildStatus, pollInterval, msg, req.url, req.job
    else
      msg.send "Jenkins says: Status=#{res.statusCode} #{body}"

jenkinsDescribe = (msg) ->
  req = prepRequest msg, (url, job) ->
    "#{url}/job/#{job}/api/json"

  req.get() (err, res, body) ->
    if err
      msg.send "Jenkins says: #{err}"
    else
      try
        content = JSON.parse(body)
      catch error
        msg.send "error parsing JSON.\n error=#{error}.\n body=#{body}"
        return

      msg.send parseDescription content

      if content.lastBuild
        checkBuildStatus msg, content.lastBuild.url, true, false, (jobStatus, jobDate) ->
          "LAST JOB: #{jobStatus}, #{jobDate}\n"

jenkinsList = (msg) ->
  url = process.env.HUBOT_JENKINS_URL
  filter = new RegExp(msg.match[2], 'i')
  req = msg.http("#{url}/api/json")

  addAuthentication req

  req.get() (err, res, body) ->
    response = ""
    if err
      msg.send "Jenkins says: #{err}"
    else
      try
        content = JSON.parse(body)
      catch error
        msg.send "error parsing JSON.\n error=#{error}.\n body=#{body}"

      for job in content.jobs
        state = if job.color == "red" then "FAIL" else "PASS"
        if filter.test job.name
          response += "#{state} #{job.name}\n"
      msg.send response

jenkinsAliases = (msg) ->
  msg.send Table.printObj jobAliases

addAuthentication = (req) ->
  if process.env.HUBOT_JENKINS_AUTH
    auth = new Buffer(process.env.HUBOT_JENKINS_AUTH).toString('base64')
    req.headers Authorization: "Basic #{auth}"

prepRequest = (msg, pathBuilder) ->
  url = process.env.HUBOT_JENKINS_URL
  job = msg.match[1]

  if jobAliases[job] != undefined
    job = jobAliases[job]

  job = querystring.escape job

  path = pathBuilder(url, job)

  req = msg.http(path)
  req.url = url
  req.job = job

  addAuthentication req

  req.header('Content-Length', 0)

checkBuildStatus = (msg, url, reportPending, pollIfNotDone, respond) ->
  path = "#{url}/api/json"
  req = msg.http(path)

  addAuthentication req

  req.header('Content-Length', 0)
  req.get() (err, res, body) ->
    if err
      msg.send "http request reported an error in #checkBuildStatus: #{err}"
    else
      response = ""

      try
        content = JSON.parse(body)
      catch error
        msg.send "error parsing JSON in #checkBuildStatus.\n error=#{error}.\n body=#{body}"
        return

      jobstatus = content.result || 'PENDING'
      jobdate = new Date(content.timestamp);
      response += respond(jobstatus, jobdate)

      if content.result || reportPending
        msg.send response
      else if pollIfNotDone
        pollBuildStatus msg, url, pollInterval

startPollingForBuildStatus = (msg, url, job) ->
  req = prepRequest msg, (url, job) ->
    "#{url}/job/#{job}/api/json"

  req.get() (err, res, body) ->
    if err
      msg.send "Error in Jenkins' response for #{url} and #{job}, #{err}"
    else
      try
        content = JSON.parse(body)
      catch error
        msg.send "error parsing JSON in #pollBuildStatus.\n error=#{error}.\n body=#{body}"
        return

      if content.lastBuild
        pollBuildStatus msg, content.lastBuild.url, 0
      else
        msg.send "Went to poll for build at #{url}, but no lastBuild found in Jenkins"

pollBuildStatus = (msg, url, interval) ->
  setTimeout checkBuildStatus, interval, msg, url, false, true, (jobStatus, jobDate) ->
    "Build complete for #{url} with status #{jobStatus} at #{jobDate}"

parseDescription = (content) ->
  response = ""

  response += "JOB: #{content.displayName}\n"

  if content.description
    response += "DESCRIPTION: #{content.description}\n"

  response += "ENABLED: #{content.buildable}\n"
  response += "STATUS: #{content.color}\n"

  tmpReport = ""
  if content.healthReport.length > 0
    for report in content.healthReport
      tmpReport += "\n  #{report.description}"
  else
    tmpReport = " unknown"
  response += "HEALTH: #{tmpReport}\n"

  parameters = ""
  for item in content.actions
    if item.parameterDefinitions
      for param in item.parameterDefinitions
        tmpDescription = if param.description then " - #{param.description} " else ""
        tmpDefault = if param.defaultParameterValue then " (default=#{param.defaultParameterValue.value})" else ""
        parameters += "\n  #{param.name}#{tmpDescription}#{tmpDefault}"

  if parameters != ""
    response += "PARAMETERS: #{parameters}\n"

  response

module.exports = (robot) ->
  robot.respond /j(?:enkins)? build ([\w\.\-_ \(\)]+)(, (.+))?/i, (msg) ->
    jenkinsBuild(msg)

  robot.respond /j(?:enkins)? list( (.+))?/i, (msg) ->
    jenkinsList(msg)

  robot.respond /j(?:enkins)? describe (.*)/i, (msg) ->
    jenkinsDescribe(msg)

  robot.respond /j(?:enkins)? aliases/i, (msg) ->
    jenkinsAliases(msg)

  robot.jenkins = {
    list: jenkinsList,
    build: jenkinsBuild
  }
