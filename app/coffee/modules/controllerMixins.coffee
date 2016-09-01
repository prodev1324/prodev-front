###
# Copyright (C) 2014-2016 Andrey Antukh <niwi@niwi.nz>
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
# File: modules/controllerMixins.coffee
###

taiga = @.taiga

groupBy = @.taiga.groupBy
joinStr = @.taiga.joinStr
trim = @.taiga.trim
toString = @.taiga.toString


#############################################################################
## Page Mixin
#############################################################################

class PageMixin
    fillUsersAndRoles: (users, roles) ->
        activeUsers = _.filter(users, (user) => user.is_active)
        @scope.activeUsers = _.sortBy(activeUsers, "full_name_display")
        @scope.activeUsersById = groupBy(@scope.activeUsers, (e) -> e.id)

        @scope.users = _.sortBy(users, "full_name_display")
        @scope.usersById = groupBy(@scope.users, (e) -> e.id)

        @scope.roles = _.sortBy(roles, "order")
        computableRoles = _(@scope.project.members).map("role").uniq().value()
        @scope.computableRoles = _(roles).filter("computable")
                                         .filter((x) -> _.includes(computableRoles, x.id))
                                         .value()
    loadUsersAndRoles: ->
        promise = @q.all([
            @rs.projects.usersList(@scope.projectId),
            @rs.projects.rolesList(@scope.projectId)
        ])

        return promise.then (results) =>
            [users, roles] = results
            @.fillUsersAndRoles(users, roles)
            return results

taiga.PageMixin = PageMixin


#############################################################################
## Filters Mixin
#############################################################################
# This mixin requires @location ($tgLocation), and @scope

class FiltersMixin
    selectFilter: (name, value, load=false) ->
        params = @location.search()
        if params[name] != undefined and name != "page"
            existing = _.map(taiga.toString(params[name]).split(","), (x) -> trim(x))
            existing.push(taiga.toString(value))
            existing = _.compact(existing)
            value = joinStr(",", _.uniq(existing))

        if !@location.isInCurrentRouteParams(name, value)
            location = if load then @location else @location.noreload(@scope)
            location.search(name, value)

    replaceFilter: (name, value, load=false) ->
        if !@location.isInCurrentRouteParams(name, value)
            location = if load then @location else @location.noreload(@scope)
            location.search(name, value)

    replaceAllFilters: (filters, load=false) ->
        location = if load then @location else @location.noreload(@scope)
        location.search(filters)

    unselectFilter: (name, value, load=false) ->
        params = @location.search()

        if params[name] is undefined
            return

        if value is undefined or value is null
            delete params[name]

        parsedValues = _.map(taiga.toString(params[name]).split(","), (x) -> trim(x))
        newValues = _.reject(parsedValues, (x) -> x == taiga.toString(value))
        newValues = _.compact(newValues)

        if _.isEmpty(newValues)
            value = null
        else
            value = joinStr(",", _.uniq(newValues))

        location = if load then @location else @location.noreload(@scope)
        location.search(name, value)

    applyStoredFilters: (projectSlug, key) ->
        if _.isEmpty(@location.search())
            filters = @.getFilters(projectSlug, key)
            if Object.keys(filters).length
                @location.search(filters)
                @location.replace()

                return true

        return false

    storeFilters: (projectSlug, params, filtersHashSuffix) ->
        ns = "#{projectSlug}:#{filtersHashSuffix}"
        hash = taiga.generateHash([projectSlug, ns])
        @storage.set(hash, params)

    getFilters: (projectSlug, filtersHashSuffix) ->
        ns = "#{projectSlug}:#{filtersHashSuffix}"
        hash = taiga.generateHash([projectSlug, ns])

        return @storage.get(hash) or {}

    formatSelectedFilters: (type, list, urlIds) ->
        selectedIds = urlIds.split(',')
        selectedFilters = _.filter list, (it) ->
            selectedIds.indexOf(_.toString(it.id)) != -1

        return _.map selectedFilters, (it) ->
            return {
                id: it.id
                key: type + ":" + it.id
                dataType: type,
                name: it.name
                color: it.color
            }

taiga.FiltersMixin = FiltersMixin

#############################################################################
## Us Filters Mixin
#############################################################################

class UsFiltersMixin
    changeQ: (q) ->
        @.replaceFilter("q", q)
        @.filtersReloadContent()
        @.generateFilters()

    removeFilter: (filter) ->
        @.unselectFilter(filter.dataType, filter.id)
        @.filtersReloadContent()
        @.generateFilters()

    addFilter: (newFilter) ->
        @.selectFilter(newFilter.category.dataType, newFilter.filter.id)
        @.filtersReloadContent()
        @.generateFilters()

    selectCustomFilter: (customFilter) ->
        @.replaceAllFilters(customFilter.filter)
        @.filtersReloadContent()
        @.generateFilters()

    saveCustomFilter: (name) ->
        filters = {}
        urlfilters = @location.search()
        filters.tags = urlfilters.tags
        filters.status = urlfilters.status
        filters.assigned_to = urlfilters.assigned_to
        filters.owner = urlfilters.owner

        @filterRemoteStorageService.getFilters(@scope.projectId, @.storeCustomFiltersName).then (userFilters) =>
            userFilters[name] = filters

            @filterRemoteStorageService.storeFilters(@scope.projectId, userFilters, @.storeCustomFiltersName).then(@.generateFilters)

    removeCustomFilter: (customFilter) ->
        @filterRemoteStorageService.getFilters(@scope.projectId, @.storeCustomFiltersName).then (userFilters) =>
            delete userFilters[customFilter.id]

            @filterRemoteStorageService.storeFilters(@scope.projectId, userFilters, @.storeCustomFiltersName).then(@.generateFilters)
            @.generateFilters()

    generateFilters: ->
        @.storeFilters(@params.pslug, @location.search(), @.storeFiltersName)

        urlfilters = @location.search()

        loadFilters = {}
        loadFilters.project = @scope.projectId
        loadFilters.tags = urlfilters.tags
        loadFilters.status = urlfilters.status
        loadFilters.assigned_to = urlfilters.assigned_to
        loadFilters.owner = urlfilters.owner
        loadFilters.q = urlfilters.q

        return @q.all([
            @rs.userstories.filtersData(loadFilters),
            @filterRemoteStorageService.getFilters(@scope.projectId, @.storeCustomFiltersName)
        ]).then (result) =>
            data = result[0]
            customFiltersRaw = result[1]

            statuses = _.map data.statuses, (it) ->
                it.id = it.id.toString()

                return it
            tags = _.map data.tags, (it) ->
                it.id = it.name

                return it
            assignedTo = _.map data.assigned_to, (it) ->
                if it.id
                    it.id = it.id.toString()
                else
                    it.id = "null"

                it.name = it.full_name || "Unassigned"

                return it
            owner = _.map data.owners, (it) ->
                it.id = it.id.toString()
                it.name = it.full_name

                return it

            @.selectedFilters = []

            if loadFilters.status
                selected = @.formatSelectedFilters("status", statuses, loadFilters.status)
                @.selectedFilters = @.selectedFilters.concat(selected)

            if loadFilters.tags
                selected = @.formatSelectedFilters("tags", tags, loadFilters.tags)
                @.selectedFilters = @.selectedFilters.concat(selected)

            if loadFilters.assigned_to
                selected = @.formatSelectedFilters("assigned_to", assignedTo, loadFilters.assigned_to)
                @.selectedFilters = @.selectedFilters.concat(selected)

            if loadFilters.owner
                selected = @.formatSelectedFilters("owner", owner, loadFilters.owner)
                @.selectedFilters = @.selectedFilters.concat(selected)

            @.filterQ = loadFilters.q

            @.filters = [
                {
                    title: @translate.instant("COMMON.FILTERS.CATEGORIES.STATUS"),
                    dataType: "status",
                    content: statuses
                },
                {
                    title: @translate.instant("COMMON.FILTERS.CATEGORIES.TAGS"),
                    dataType: "tags",
                    content: tags,
                    hideEmpty: true
                },
                {
                    title: @translate.instant("COMMON.FILTERS.CATEGORIES.ASSIGNED_TO"),
                    dataType: "assigned_to",
                    content: assignedTo
                },
                {
                    title: @translate.instant("COMMON.FILTERS.CATEGORIES.CREATED_BY"),
                    dataType: "owner",
                    content: owner
                }
            ]

            @.customFilters = []
            _.forOwn customFiltersRaw, (value, key) =>
                @.customFilters.push({id: key, name: key, filter: value})


taiga.UsFiltersMixin = UsFiltersMixin
