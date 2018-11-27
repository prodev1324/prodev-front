###
# Copyright (C) 2014-2017 Andrey Antukh <niwi@niwi.nz>
# Copyright (C) 2014-2017 Jesús Espino Garcia <jespinog@gmail.com>
# Copyright (C) 2014-2017 David Barragán Merino <bameda@dbarragan.com>
# Copyright (C) 2014-2017 Alejandro Alonso <alejandro.alonso@kaleidos.net>
# Copyright (C) 2014-2017 Juan Francisco Alcántara <juanfran.alcantara@kaleidos.net>
# Copyright (C) 2014-2017 Xavi Julian <xavier.julian@kaleidos.net>
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
# File: modules/user-settings/user-project-settings.coffee
###

taiga = @.taiga
mixOf = @.taiga.mixOf
bindOnce = @.taiga.bindOnce

module = angular.module("taigaUserSettings")


#############################################################################
## Custom Homepage Controller
#############################################################################

class UserProjectSettingsController extends mixOf(taiga.Controller, taiga.PageMixin)
    @.$inject = [
        "$rootScope"
        "$scope"
        "$tgSections"
        "$tgResources"
        "$tgRepo"
        "$tgConfirm"
         "tgCurrentUserService"
    ]

    constructor: (@rootScope, @scope, @tgSections, @rs, @repo, @confirm, @currentUserService) ->
        @scope.sections = @tgSections.list()

        promise = @.loadInitialData()
        promise.then null, @.onInitialDataError.bind(@)

    loadInitialData: ->
        return @rs.userProjectSettings.list().then (userProjectSettings) =>
            @scope.userProjectSettings = userProjectSettings

    updateCustomHomePage: (projectSettings) ->
        onSuccess = =>
            @currentUserService.loadProjects()
            @rootScope.$broadcast("dropdown-project-list:updated")
            @confirm.notify("success")

        onError = =>
            @confirm.notify("error")

        @repo.save(projectSettings).then(onSuccess, onError)

    filteredSections: (projectSettings) ->
        return _.filter @scope.sections, (section) ->
            section.id in projectSettings.allowed_sections


module.controller("UserProjectSettingsController", UserProjectSettingsController)
