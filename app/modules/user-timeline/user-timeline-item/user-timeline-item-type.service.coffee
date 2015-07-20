timelineType = (timeline, event) ->
    types = [
        { # NewMember
            check: (timeline, event) ->
                return event.obj == 'membership'
            key: 'TIMELINE.NEW_MEMBER',
            translate_params: ['project_name']
            member: (timeline) ->
                return Immutable.Map({
                    user: timeline.getIn(['data', 'user']),
                    role: timeline.getIn(['data', 'role'])
                })
        },
        { # NewProject
            check: (timeline, event) ->
                return event.obj == 'project' && event.type == 'create'
            key: 'TIMELINE.NEW_PROJECT',
            translate_params: ['username', 'project_name'],
            description: (timeline) ->
                return timeline.getIn(['data', 'project', 'description'])
        },
        { # NewAttachment
            check: (timeline, event) ->
                return event.type == 'change' &&
                     timeline.hasIn(['data', 'value_diff']) &&
                     timeline.getIn(['data', 'value_diff', 'key']) == 'attachments'
            key: 'TIMELINE.UPLOAD_ATTACHMENT',
            translate_params: ['username', 'obj_name']
        },
        { # NewUs
            check: (timeline, event) ->
                return event.obj == 'userstory' && event.type == 'create'
            key: 'TIMELINE.US_CREATED',
            translate_params: ['username', 'project_name', 'obj_name']
        },
        { # NewIssue
            check: (timeline, event) ->
                return event.obj == 'issue' && event.type == 'create'
            key: 'TIMELINE.ISSUE_CREATED',
            translate_params: ['username', 'project_name', 'obj_name']
        },
        { # NewWiki
            check: (timeline, event) ->
                return event.obj == 'wikipage' && event.type == 'create'
            key: 'TIMELINE.WIKI_CREATED',
            translate_params: ['username', 'project_name', 'obj_name']
        },
        { # NewTask
            check: (timeline, event) ->
                return event.obj == 'task' && event.type == 'create' && !timeline.getIn(['data', 'task', 'userstory'])
            key: 'TIMELINE.TASK_CREATED',
            translate_params: ['username', 'project_name', 'obj_name']
        },
        { # NewTask with US
            check: (timeline, event) ->
                return event.obj == 'task' && event.type == 'create' && timeline.getIn(['data', 'task', 'userstory'])
            key: 'TIMELINE.TASK_CREATED_WITH_US',
            translate_params: ['username', 'project_name', 'obj_name', 'us_name']
        },
        { # NewMilestone
            check: (timeline, event) ->
                return event.obj == 'milestone' && event.type == 'create'
            key: 'TIMELINE.MILESTONE_CREATED',
            translate_params: ['username', 'project_name', 'obj_name']
        },
        { # NewUsComment
            check: (timeline, event) ->
                return timeline.getIn(['data', 'comment']) && event.obj == 'userstory'
            key: 'TIMELINE.NEW_COMMENT_US',
            translate_params: ['username', 'obj_name'],
            description: (timeline) ->
                return $(timeline.getIn(['data', 'comment_html'])).text()
        },
        { # NewIssueComment
            check: (timeline, event) ->
                return timeline.getIn(['data', 'comment']) && event.obj == 'issue'
            key: 'TIMELINE.NEW_COMMENT_ISSUE',
            translate_params: ['username', 'obj_name'],
            description: (timeline) ->
                return $(timeline.getIn(['data', 'comment_html'])).text()
        },
        { # NewTaskComment
            check: (timeline, event) ->
                return timeline.getIn(['data', 'comment']) && event.obj == 'task'
            key: 'TIMELINE.NEW_COMMENT_TASK'
            translate_params: ['username', 'obj_name'],
            description: (timeline) ->
                return $(timeline.getIn(['data', 'comment_html'])).text()
        },
        { # UsToMilestone
            check: (timeline, event) ->
                if timeline.hasIn(['data', 'value_diff']) &&
                      timeline.getIn(['data', 'value_diff', 'key']) == 'milestone' &&
                      event.type == 'change'
                    return timeline.getIn(['data', 'value_diff', 'value']).get(0) == null

                return false
            key: 'TIMELINE.US_ADDED_MILESTONE',
            translate_params: ['username', 'obj_name', 'sprint_name']
        },
        { # UsToBacklog
            check: (timeline, event) ->
                if timeline.hasIn(['data', 'value_diff']) &&
                      timeline.getIn(['data', 'value_diff', 'key']) == 'milestone' &&
                      event.type == 'change'
                    return timeline.getIn(['data', 'value_diff', 'value']).get(1) == null

                return false
            key: 'TIMELINE.US_REMOVED_FROM_MILESTONE',
            translate_params: ['username', 'obj_name']
        },
        { # Blocked
            check: (timeline, event) ->
                if timeline.hasIn(['data', 'value_diff']) &&
                      timeline.getIn(['data', 'value_diff', 'key']) == 'blocked' &&
                      event.type == 'change'
                    return timeline.getIn(['data', 'value_diff', 'value', 'is_blocked']).get(1) == true

                return false
            key: 'TIMELINE.BLOCKED',
            translate_params: ['username', 'obj_name'],
            description: (timeline) ->
                if timeline.hasIn(['data', 'value_diff', 'value', 'blocked_note_html'])
                    return $(timeline.getIn(['data', 'value_diff', 'value', 'blocked_note_html']).get(1)).text()
                else
                    return false
        },
        { # UnBlocked
            check: (timeline, event) ->
                if timeline.hasIn(['data', 'value_diff']) &&
                      timeline.getIn(['data', 'value_diff', 'key']) == 'blocked' &&
                      event.type == 'change'
                    return timeline.getIn(['data', 'value_diff', 'value', 'is_blocked']).get(1) == false

                return false
            key: 'TIMELINE.UNBLOCKED',
            translate_params: ['username', 'obj_name']
        },
        { # MilestoneUpdated
            check: (timeline, event) ->
                return event.obj == 'milestone' && event.type == 'change'
            key: 'TIMELINE.MILESTONE_UPDATED',
            translate_params: ['username', 'obj_name']
        },
        { # WikiUpdated
            check: (timeline, event) ->
                return event.obj == 'wikipage' && event.type == 'change'
            key: 'TIMELINE.WIKI_UPDATED',
            translate_params: ['username', 'obj_name']
        },
        { # UsUpdated points
            check: (timeline, event) ->
                return event.obj == 'userstory' &&
                    event.type == 'change' &&
                    timeline.hasIn(['data', 'value_diff']) &&
                    timeline.getIn(['data', 'value_diff', 'key']) == 'points'
            key: 'TIMELINE.US_UPDATED_POINTS',
            translate_params: ['username', 'field_name', 'obj_name', 'new_value', 'role_name']
        },
        { # UsUpdated description
            check: (timeline, event) ->
                return event.obj == 'userstory' &&
                    event.type == 'change' &&
                    timeline.hasIn(['data', 'value_diff']) &&
                    timeline.getIn(['data', 'value_diff', 'key']) == 'description_diff'
            key: 'TIMELINE.US_UPDATED',
            translate_params: ['username', 'field_name', 'obj_name']
        },
        { # UsUpdated general
            check: (timeline, event) ->
                return event.obj == 'userstory' &&
                    event.type == 'change'
            key: 'TIMELINE.US_UPDATED_WITH_NEW_VALUE',
            translate_params: ['username', 'field_name', 'obj_name', 'new_value']
        },
        { # IssueUpdated description
            check: (timeline, event) ->
                return event.obj == 'issue' &&
                    event.type == 'change' &&
                    timeline.hasIn(['data', 'value_diff']) &&
                    timeline.getIn(['data', 'value_diff', 'key']) == 'description_diff'
            key: 'TIMELINE.ISSUE_UPDATED',
            translate_params: ['username', 'field_name', 'obj_name']
        },
        { # IssueUpdated general
            check: (timeline, event) ->
                return event.obj == 'issue' &&
                    event.type == 'change'
            key: 'TIMELINE.ISSUE_UPDATED_WITH_NEW_VALUE',
            translate_params: ['username', 'field_name', 'obj_name', 'new_value']
        },
        { # TaskUpdated description
            check: (timeline, event) ->
                return event.obj == 'task' &&
                    event.type == 'change' &&
                    !timeline.getIn('data', 'task', 'userstory') &&
                    timeline.hasIn(['data', 'value_diff']) &&
                    timeline.getIn(['data', 'value_diff', 'key']) == 'description_diff'
            key: 'TIMELINE.TASK_UPDATED',
            translate_params: ['username', 'field_name', 'obj_name']
        },
        { # TaskUpdated with US description
            check: (timeline, event) ->
                return event.obj == 'task' &&
                    event.type == 'change' &&
                    timeline.getIn('data', 'task', 'userstory') &&
                    timeline.hasIn(['data', 'value_diff']) &&
                    timeline.getIn(['data', 'value_diff', 'key']) == 'description_diff'
            key: 'TIMELINE.TASK_UPDATED_WITH_US',
            translate_params: ['username', 'field_name', 'obj_name', 'us_name']
        },
        { # TaskUpdated general
            check: (timeline, event) ->
                return event.obj == 'task' &&
                    event.type == 'change' &&
                    !timeline.getIn(['data', 'task', 'userstory'])
            key: 'TIMELINE.TASK_UPDATED_WITH_NEW_VALUE',
            translate_params: ['username', 'field_name', 'obj_name', 'new_value']
        },
        { # TaskUpdated with US
            check: (timeline, event) ->
                return event.obj == 'task' &&
                    event.type == 'change' &&
                    timeline.getIn(['data', 'task', 'userstory'])
            key: 'TIMELINE.TASK_UPDATED_WITH_US_NEW_VALUE',
            translate_params: ['username', 'field_name', 'obj_name', 'us_name', 'new_value']
        },
        { # New User
            check: (timeline, event) ->
                return event.obj == 'user' && event.type == 'create'
            key: 'TIMELINE.NEW_USER',
            translate_params: ['username']
        }
    ]

    return _.find types, (obj) ->
        return obj.check(timeline, event)

class UserTimelineType
    getType: (timeline, event) -> timelineType(timeline, event)

angular.module("taigaUserTimeline")
    .service("tgUserTimelineItemType", UserTimelineType)
