###
# Copyright (C) 2014-2016 Taiga Agile LLC <taiga@taiga.io>
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
# File: current-user.service.coffee
###

taiga = @.taiga

groupBy = @.taiga.groupBy

class CurrentUserService
    @.$inject = [
        "tgProjectsService",
        "$tgStorage",
        "tgResources"
    ]

    constructor: (@projectsService, @storageService, @rs) ->
        @._user = null
        @._projects = Immutable.Map()
        @._projectsById = Immutable.Map()
        @._joyride = null

        taiga.defineImmutableProperty @, "projects", () => return @._projects
        taiga.defineImmutableProperty @, "projectsById", () => return @._projectsById

    isAuthenticated: ->
        if @.getUser() != null
            return true
        return false

    getUser: () ->
        if !@._user
            userData = @storageService.get("userInfo")

            if userData
                userData = Immutable.fromJS(userData)
                @.setUser(userData)

        return @._user

    removeUser: () ->
        @._user = null
        @._projects = Immutable.Map()
        @._projectsById = Immutable.Map()
        @._joyride = null

    setUser: (user) ->
        @._user = user

        return @._loadUserInfo()

    bulkUpdateProjectsOrder: (sortData) ->
        @projectsService.bulkUpdateProjectsOrder(sortData).then () =>
            @.loadProjects()

    loadProjects: () ->
        return @projectsService.getProjectsByUserId(@._user.get("id"))
            .then (projects) => @.setProjects(projects)

    disableJoyRide: (section) ->
        if section
            @._joyride[section] = false
        else
            @._joyride = {
                backlog: false,
                kanban: false,
                dashboard: false
            }

        @rs.user.setUserStorage('joyride', @._joyride)

    loadJoyRideConfig: () ->
        return new Promise (resolve) =>
            if @._joyride != null
                resolve(@._joyride)
                return

            @rs.user.getUserStorage('joyride')
                .then (config) =>
                    @._joyride = config
                    resolve(@._joyride)
                .catch () =>
                    #joyride not defined
                    @._joyride = {
                        backlog: true,
                        kanban: true,
                        dashboard: true
                    }

                    @rs.user.createUserStorage('joyride', @._joyride)

                    resolve(@._joyride)

    _loadUserInfo: () ->
        return Promise.all([
            @.loadProjects()
        ])

    setProjects: (projects) ->
        @._projects = @._projects.set("all", projects)
        @._projects = @._projects.set("recents", projects.slice(0, 10))

        @._projectsById = Immutable.fromJS(groupBy(projects.toJS(), (p) -> p.id))

        return @.projects

    canAddMoreMembersInPrivateProjects: (projectId) ->
        project = @.projects.get('all').find (project) -> project.get('id') == projectId
        user = @.getUser()

        if user.get('max_memberships_private_projects') != null && project.get('members').size >= user.get('max_memberships_private_projects')
            return {valid: false, reason: 'max_memberships_private_projects', type: 'private_project'}

        return {valid: true}

    canAddMoreMembersInPublicProjects: (projectId) ->
        project = @.projects.get('all').find (project) -> project.get('id') == projectId
        user = @.getUser()

        if user.get('max_memberships_public_projects') != null && project.get('members').size >= user.get('max_memberships_public_projects')
            return {valid: false, reason: 'max_memberships_public_projects', type: 'public_project'}

        return {valid: true}


    canBePrivateProject: (projectId) ->
        project = @.projects.get('all').find (project) -> project.get('id') == projectId

        return {valid: true} if project.get('is_private')

        result = @.canCreatePrivateProjects()

        return result if !result.valid

        user = @.getUser()

        if user.get('max_memberships_private_projects') != null && project.get('members').size > user.get('max_memberships_private_projects')
            return {valid: false, reason: 'max_memberships_private_projects', type: 'private_project'}

        return {valid: true}

    canBePublicProject: (projectId) ->
        project = @.projects.get('all').find (project) -> project.get('id') == projectId

        return {valid: true} if !project.get('is_private')

        result = @.canCreatePublicProjects()

        return result if !result.valid

        user = @.getUser()

        if user.get('max_memberships_public_projects') != null && project.get('members').size > user.get('max_memberships_public_projects')
            return {valid: false, reason: 'max_memberships_public_projects', type: 'public_project'}

        return {valid: true}

    canCreatePrivateProjects: () ->
        user = @.getUser()

        if user.get('max_private_projects') != null && user.get('max_private_projects') <= user.get('total_private_projects')
            return {valid: false, reason: 'max_private_projects', type: 'private_project'}

        return {valid: true}

    canCreatePublicProjects: () ->
        user = @.getUser()

        if user.get('max_public_projects') != null && user.get('max_public_projects') <= user.get('total_public_projects')
            return {valid: false, reason: 'max_public_projects', type: 'public_project'}

        return {valid: true}

angular.module("taigaCommon").service("tgCurrentUserService", CurrentUserService)
