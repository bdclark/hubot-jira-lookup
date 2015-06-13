# Description:
#   Jira lookup when issues are heard
#
# Dependencies:
#   None
#
# Configuration:
#   HUBOT_JIRA_LOOKUP_USERNAME
#   HUBOT_JIRA_LOOKUP_PASSWORD
#   HUBOT_JIRA_LOOKUP_URL
#   HUBOT_JIRA_LOOKUP_IGNORE_USERS (optional, format: "user1|user2", default is "jira|github")
#
# Commands:
#   None
#
# Author:
#   Matthew Finlayson <matthew.finlayson@jivesoftware.com> (http://www.jivesoftware.com)
#   Benjamin Sherman  <benjamin@jivesoftware.com> (http://www.jivesoftware.com)
#   Dustin Miller <dustin@sharepointexperts.com> (http://sharepointexperience.com)

module.exports = (robot) ->

  ignored_users = process.env.HUBOT_JIRA_LOOKUP_IGNORE_USERS
  if ignored_users == undefined
    ignored_users = "jira|github"

  robot.hear /(\b[a-zA-Z]{2,5}-[0-9]{1,5}\b)/g, (msg) ->

    return if msg.message.user.name.match(new RegExp(ignored_users, "gi"))

    issues = msg.match

    short_display = false
    if issues.length > 1
      short_display = true

    user = process.env.HUBOT_JIRA_LOOKUP_USERNAME
    pass = process.env.HUBOT_JIRA_LOOKUP_PASSWORD
    url = process.env.HUBOT_JIRA_LOOKUP_URL
    auth = 'Basic ' + new Buffer(user + ':' + pass).toString('base64')

    for issue in issues
      robot.http("#{url}/rest/api/latest/issue/#{issue}")
        .headers(Authorization: auth, Accept: 'application/json')
        .get() (err, res, body) ->
          try
            json = JSON.parse(body)
            json_summary = ""
            if json.fields.summary
              unless json.fields.summary is null or json.fields.summary.nil? or json.fields.summary.empty?
                json_summary = json.fields.summary
            json_description = ""
            if json.fields.description
              unless json.fields.description is null or json.fields.description.nil? or json.fields.description.empty?
                desc_array = json.fields.description.split("\n")
                for item in desc_array[0..2]
                  json_description += item
            json_assignee = ""
            if json.fields.assignee
              unless json.fields.assignee is null or json.fields.assignee.nil? or json.fields.assignee.empty?
                unless json.fields.assignee.displayName.nil? or json.fields.assignee.displayName.empty?
                  json_assignee += json.fields.assignee.displayName
            json_status = ""
            if json.fields.status
              unless json.fields.status is null or json.fields.status.nil? or json.fields.status.empty?
                unless json.fields.status.name.nil? or json.fields.status.name.empty?
                  json_status += json.fields.status.name
            color = '#28D7E5'
            if json.fields.priority
              unless json.fields.priority is null or json.fields.priority.nil? or json.fields.priority.empty?
                unless json.fields.priority.name.nil? or json.fields.priority.name.empty?
                  priority = json.fields.priority.name
                  color = switch
                    when priority is "Minor" then 'good'
                    when priority is "Major" then 'warning'
                    when priority is "Critical" or "Blocker" then 'danger'
                    else '#28D7E5'

            if process.env.HUBOT_SLACK_INCOMING_WEBHOOK?
              if short_display
                robot.emit 'slack.attachment',
                  message: msg.message
                  content:
                    fallback: 'Issue: #{json.key}: #{json_summary}#{json_description}#{json_assignee}#{json_status}\n Link:        #{process.env.HUBOT_JIRA_LOOKUP_URL}/browse/#{json.key}\n'
                    title: "#{json.key}: #{json_summary}"
                    title_link: "#{process.env.HUBOT_JIRA_LOOKUP_URL}/browse/#{json.key}"
                    color: color
              else
                robot.emit 'slack.attachment',
                  message: msg.message
                  content:
                    fallback: 'Issue:       #{json.key}: #{json_summary}#{json_description}#{json_assignee}#{json_status}\n Link:        #{process.env.HUBOT_JIRA_LOOKUP_URL}/browse/#{json.key}\n'
                    title: "#{json.key}: #{json_summary}"
                    title_link: "#{process.env.HUBOT_JIRA_LOOKUP_URL}/browse/#{json.key}"
                    text: "#{json_description}"
                    color: color
                    fields: [
                      {
                        title: 'Assigned to'
                        value: "#{json_assignee}"
                        short: true
                      },
                      {
                        title: 'Status'
                        value: "#{json_status}"
                        short: true
                      }
                    ]
            else
              msg.send ":jira:<#{url}/browse/#{json.key}|#{json.key}:#{json_summary}> Created by #{json_assignee}#{json_status}\n"
          catch error
            console.log "Issue #{json.key} not found"
