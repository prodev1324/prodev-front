###
# Copyright (C) 2014 Andrey Antukh <niwi@niwi.be>
# Copyright (C) 2014 Jesús Espino Garcia <jespinog@gmail.com>
# Copyright (C) 2014 David Barragán Merino <bameda@dbarragan.com>
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
        "$tgRepo",
        "$tgResources",
        "$routeParams",
        "$q",
        "$appTitle",
        "$tgAuth"
        "tgLoader"
    ]

    constructor: (@scope, @repo, @rs, @params, @q, @appTitle, @auth, tgLoader) ->
        @scope.sectionName = "Team"

        promise = @.loadInitialData()

        # On Success
        promise.then =>
            @appTitle.set("Team - " + @scope.project.name)
            tgLoader.pageLoaded()

        # On Error
        promise.then null, @.onInitialDataError.bind(@)

        @scope.currentUser = @auth.getUser()

    setRole: (role) ->
        if role
            @scope.filtersRole = role
        else
            @scope.filtersRole = ""

    loadMembers: ->
        return @rs.memberships.list(@scope.projectId).then (data) =>
            @scope.memberships = data.models
            return data

    loadProject: ->
        return @rs.projects.get(@scope.projectId).then (project) =>
            @scope.project = project
            @scope.$emit('project:loaded', project)

            return project

    loadInitialData: ->
        promise = @repo.resolve({pslug: @params.pslug}).then (data) =>
            @scope.projectId = data.project
            return data

        return promise.then(=> @.loadProject())
                      .then(=> @.loadUsersAndRoles())
                      .then(=> @.loadMembers())

module.controller("TeamController", TeamController)

#############################################################################
## Team Filters Directive
#############################################################################

TeamFiltersDirective = () ->
    template = """
    <ul>
        <li>
            <a ng-class="{active: !filtersRole.id}" ng-click="ctrl.setRole()" href="">
                <span class="title">All</span>
                <span class="icon icon-arrow-right"></span>
            </a>
        </li>
        <li ng-repeat="role in roles">
            <a ng-class="{active: role.id == filtersRole.id}" ng-click="ctrl.setRole(role)" href="">
                <span class="title" tg-bo-bind="role.name"></span>
                <span class="icon icon-arrow-right"></span>
            </a>
        </li>
    </ul>
    """

    return {
        template: template
    }

module.directive("tgTeamFilters", [TeamFiltersDirective])

#############################################################################
## Team Members Directive
#############################################################################

TeamMembersDirective = () ->
    template = """
        <div class="row" ng-repeat="user in memberships | filter:filtersQ | filter:{role: filtersRole.id}">
            <div class="username">
                <figure class="avatar">
                    <img tg-bo-src="user.photo", tg-bo-alt="user.full_name" />
                    <figcaption>
                        <span class="name" tg-bo-bind="user.full_name"></span>
                        <span class="position" tg-bo-bind="user.role_name"></span>
                        <tg-leave-project ng-if="currentUser"></tg-leave-project>
                    </figcaption>
                </figure>
            </div>
            <div class="attribute">
                <span class="icon icon-github"></span>
            </div>
            <div class="attribute">
                <span class="icon icon-github"></span>
            </div>
            <div class="attribute">
                <span class="icon icon-github"></span>
            </div>
            <div class="attribute">
                <span class="icon icon-github"></span>
            </div>
            <div class="attribute">
                <span class="icon icon-github top"></span>
            </div>
            <div class="attribute">
                <span class="points">666</span>
            </div>
        </div>
    """
    return {
        link: (scope) ->
            if !_.isArray(scope.memberships)
                scope.memberships = [scope.memberships]

        template: template
        scope: {
            memberships: "=",
            filtersQ: "=filtersq",
            filtersRole: "=filtersrole",
            currentUser: "@currentuser"
        }
    }

module.directive("tgTeamMembers", TeamMembersDirective)

#############################################################################
## Leave project Directive
#############################################################################

LeaveProjectDirective = ($repo, $confirm, $location) ->
    template= """
        <a ng-click="leave()" href="" class="leave-project">
            <span class="icon icon-delete"></span>Leave this project
        </a>
    """ #TODO: i18n

    link = ($scope) ->
        $scope.leave = () ->
            $confirm.ask("Leave this project", "Are you sure you want to leave the project?")#TODO: i18n
                .then (finish) =>
                    console.log "TODO"
    return {
        scope: {},
        restrict: "EA",
        replace: true,
        template: template,
        link: link
    }

module.directive("tgLeaveProject", ["$tgRepo", "$tgConfirm", "$tgLocation", LeaveProjectDirective])
