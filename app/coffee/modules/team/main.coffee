###
# Copyright (C) 2014-2016 Andrey Antukh <niwi@niwi.be>
# Copyright (C) 2014-2016 Jesús Espino Garcia <jespinog@gmail.com>
# Copyright (C) 2014-2016 David Barragán Merino <bameda@dbarragan.com>
# Copyright (C) 2014-2016 Alejandro Alonso <alejandro.alonso@kaleidos.net>
# Copyright (C) 2014-2016 Juan Francisco Alcántara <juanfran.alcantara@kaleidos.net>
# Copyright (C) 2014-2016 Xavi Julian <xavier.julian@kaleidos.net>
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU Affero General Public License as
# published by the Free Software Foundation, either version 3 of the
# License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
# GNU Affero General Public License for more details.
#
# You should have received a copy of the GNU Affero General Public License
# along with this program. If not, see <http://www.gnu.org/licenses/>.
#
# File: modules/team/main.coffee
###

taiga = @.taiga

mixOf = @.taiga.mixOf

module = angular.module("taigaTeam")

#############################################################################
## Team Controller
#############################################################################

class TeamController extends mixOf(taiga.Controller, taiga.PageMixin)
    @.$inject = [
        "$scope",
        "$rootScope",
        "$tgRepo",
        "$tgResources",
        "$routeParams",
        "$q",
        "$location",
        "$tgNavUrls",
        "tgAppMetaService",
        "$tgAuth",
        "$translate",
        "tgProjectService"
    ]

    constructor: (@scope, @rootscope, @repo, @rs, @params, @q, @location, @navUrls, @appMetaService, @auth,
                  @translate, @projectService) ->
        @scope.sectionName = "TEAM.SECTION_NAME"

        promise = @.loadInitialData()

        # On Success
        promise.then =>
            title = @translate.instant("TEAM.PAGE_TITLE", {projectName: @scope.project.name})
            description = @translate.instant("TEAM.PAGE_DESCRIPTION", {
                projectName: @scope.project.name,
                projectDescription: @scope.project.description
            })
            @appMetaService.setAll(title, description)

        # On Error
        promise.then null, @.onInitialDataError.bind(@)

    setRole: (role) ->
        if role
            @scope.filtersRole = role
        else
            @scope.filtersRole = null

    loadMembers: ->
        user = @auth.getUser()

        # Calculate totals
        @scope.totals = {}
        for member in @scope.activeUsers
            @scope.totals[member.id] = 0

        # Get current user
        @scope.currentUser = _.find(@scope.activeUsers, {id: user?.id})

        # Get member list without current user
        @scope.memberships = _.reject(@scope.activeUsers, {id: user?.id})

    loadProject: ->
        return @rs.projects.getBySlug(@params.pslug).then (project) =>
            @scope.projectId = project.id
            @scope.project = project
            @scope.$emit('project:loaded', project)

            @scope.issuesEnabled = project.is_issues_activated
            @scope.tasksEnabled = project.is_kanban_activated or project.is_backlog_activated
            @scope.wikiEnabled = project.is_wiki_activated

            return project

    loadMemberStats: ->
        return @rs.projects.memberStats(@scope.projectId).then (stats) =>
          totals = {}
          _.forEach @scope.totals, (total, userId) =>
              vals = _.map(stats, (memberStats, statsKey) -> memberStats[userId])
              total = _.reduce(vals, (sum, el) -> sum + el)
              @scope.totals[userId] = total

          @scope.stats = @._processStats(stats)
          @scope.stats.totals = @scope.totals

    _processStat: (stat) ->
        max = _.max(stat)
        min = _.min(stat)
        singleStat = _.map stat, (value, key) ->
            if value == min
                return [key, 0.1]
            if value == max
                return [key, 1]
            return [key, (value * 0.5) / max]
        singleStat = _.object(singleStat)
        return singleStat

    _processStats: (stats) ->
        for key,value of stats
            stats[key] = @._processStat(value)
        return stats

    loadInitialData: ->
        promise = @.loadProject()
        return promise.then (project) =>
            @.fillUsersAndRoles(project.members, project.roles)
            @.loadMembers()
            return @.loadMemberStats()

module.controller("TeamController", TeamController)


#############################################################################
## Team Filters Directive
#############################################################################

TeamFiltersDirective = () ->
    return {
        templateUrl: "team/team-filter.html"
    }

module.directive("tgTeamFilters", [TeamFiltersDirective])


#############################################################################
## Team Member Stats Directive
#############################################################################

TeamMemberStatsDirective = () ->
    return {
        templateUrl: "team/team-member-stats.html",
        scope: {
            stats: "=",
            userId: "=user"
            issuesEnabled: "=issuesenabled"
            tasksEnabled: "=tasksenabled"
            wikiEnabled: "=wikienabled"
        }
    }

module.directive("tgTeamMemberStats", TeamMemberStatsDirective)


#############################################################################
## Team Current User Directive
#############################################################################

TeamMemberCurrentUserDirective = () ->
    return {
        templateUrl: "team/team-member-current-user.html"
        scope: {
            projectId: "=projectid",
            currentUser: "=currentuser",
            stats: "="
            issuesEnabled: "=issuesenabled"
            tasksEnabled: "=tasksenabled"
            wikiEnabled: "=wikienabled"
        }
    }

module.directive("tgTeamCurrentUser", TeamMemberCurrentUserDirective)


#############################################################################
## Team Members Directive
#############################################################################

TeamMembersDirective = () ->
    template = "team/team-members.html"

    return {
        templateUrl: template
        scope: {
            memberships: "=",
            filtersQ: "=filtersq",
            filtersRole: "=filtersrole",
            stats: "="
            issuesEnabled: "=issuesenabled"
            tasksEnabled: "=tasksenabled"
            wikiEnabled: "=wikienabled"
        }
    }

module.directive("tgTeamMembers", TeamMembersDirective)


#############################################################################
## Leave project Directive
#############################################################################

LeaveProjectDirective = ($repo, $confirm, $location, $rs, $navurls, $translate) ->
    link = ($scope, $el, $attrs) ->
        $scope.leave = () ->
            leave_project_text = $translate.instant("TEAM.ACTION_LEAVE_PROJECT")
            confirm_leave_project_text = $translate.instant("TEAM.CONFIRM_LEAVE_PROJECT")

            $confirm.ask(leave_project_text, confirm_leave_project_text).then (response) =>
                promise = $rs.projects.leave($attrs.projectid)

                promise.then =>
                    response.finish()
                    $confirm.notify("success")
                    $location.path($navurls.resolve("home"))

                promise.then null, (response) ->
                    response.finish()
                    $confirm.notify('error', response.data._error_message)

    return {
        scope: {},
        templateUrl: "team/leave-project.html",
        link: link
    }

module.directive("tgLeaveProject", ["$tgRepo", "$tgConfirm", "$tgLocation", "$tgResources", "$tgNavUrls", "$translate",
                                    LeaveProjectDirective])


#############################################################################
## Team Filters
#############################################################################

membersFilter = ->
    return (members, filtersQ, filtersRole) ->
        return _.filter members, (m) -> (not filtersRole or m.role == filtersRole.id) and
                                        (not filtersQ or m.full_name.search(new RegExp(filtersQ, "i")) >= 0)

module.filter('membersFilter', membersFilter)
