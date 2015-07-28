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
# File: modules/backlog/main.coffee
###

taiga = @.taiga

mixOf = @.taiga.mixOf
toggleText = @.taiga.toggleText
scopeDefer = @.taiga.scopeDefer
bindOnce = @.taiga.bindOnce
groupBy = @.taiga.groupBy
timeout = @.taiga.timeout
bindMethods = @.taiga.bindMethods
generateHash = @.taiga.generateHash

module = angular.module("taigaBacklog")

#############################################################################
## Backlog Controller
#############################################################################

class BacklogController extends mixOf(taiga.Controller, taiga.PageMixin, taiga.FiltersMixin)
    @.$inject = [
        "$scope",
        "$rootScope",
        "$tgRepo",
        "$tgConfirm",
        "$tgResources",
        "$routeParams",
        "$q",
        "$tgLocation",
        "tgAppMetaService",
        "$tgNavUrls",
        "$tgEvents",
        "$tgAnalytics",
        "$translate"
    ]

    constructor: (@scope, @rootscope, @repo, @confirm, @rs, @params, @q,
                  @location, @appMetaService, @navUrls, @events, @analytics, @translate) ->
        bindMethods(@)

        @scope.sectionName = @translate.instant("BACKLOG.SECTION_NAME")
        @showTags = false
        @activeFilters = false

        @.initializeEventHandlers()

        promise = @.loadInitialData()

        # On Success
        promise.then =>
            title = @translate.instant("BACKLOG.PAGE_TITLE", {projectName: @scope.project.name})
            description = @translate.instant("BACKLOG.PAGE_DESCRIPTION", {
                projectName: @scope.project.name,
                projectDescription: @scope.project.description
            })
            @appMetaService.setAll(title, description)

            if @rs.userstories.getShowTags(@scope.projectId)
                @showTags = true

                @scope.$broadcast("showTags", @showTags)

        # On Error
        promise.then null, @.onInitialDataError.bind(@)

    initializeEventHandlers: ->
        @scope.$on "usform:bulk:success", =>
            @.loadUserstories()
            @.loadProjectStats()
            @analytics.trackEvent("userstory", "create", "bulk create userstory on backlog", 1)

        @scope.$on "sprintform:create:success", =>
            @.loadSprints()
            @.loadProjectStats()
            @analytics.trackEvent("sprint", "create", "create sprint on backlog", 1)

        @scope.$on "usform:new:success", =>
            @.loadUserstories()
            @.loadProjectStats()

            @rootscope.$broadcast("filters:update")
            @analytics.trackEvent("userstory", "create", "create userstory on backlog", 1)

        @scope.$on "sprintform:edit:success", =>
            @.loadProjectStats()

        @scope.$on "sprintform:remove:success", =>
            @.loadSprints()
            @.loadProjectStats()
            @.loadUserstories()
            @rootscope.$broadcast("filters:update")

        @scope.$on "usform:edit:success", =>
            @.loadUserstories()
            @rootscope.$broadcast("filters:update")

        @scope.$on("sprint:us:move", @.moveUs)
        @scope.$on("sprint:us:moved", @.loadSprints)
        @scope.$on("sprint:us:moved", @.loadProjectStats)

        @scope.$on("backlog:load-closed-sprints", @.loadClosedSprints)
        @scope.$on("backlog:unload-closed-sprints", @.unloadClosedSprints)

    initializeSubscription: ->
        routingKey1 = "changes.project.#{@scope.projectId}.userstories"
        @events.subscribe @scope, routingKey1, (message) =>
            @.loadUserstories()
            @.loadSprints()

        routingKey2 = "changes.project.#{@scope.projectId}.milestones"
        @events.subscribe @scope, routingKey2, (message) =>
            @.loadSprints()

    toggleShowTags: ->
        @scope.$apply =>
            @showTags = !@showTags
            @rs.userstories.storeShowTags(@scope.projectId, @showTags)

    toggleActiveFilters: ->
        @activeFilters = !@activeFilters

    loadProjectStats: ->
        return @rs.projects.stats(@scope.projectId).then (stats) =>
            @scope.stats = stats

            if stats.total_points
                @scope.stats.completedPercentage = Math.round(100 * stats.closed_points / stats.total_points)
            else
                @scope.stats.completedPercentage = 0

            return stats

    refreshTagsColors: ->
        return @rs.projects.tagsColors(@scope.projectId).then (tags_colors) =>
            @scope.project.tags_colors = tags_colors

    unloadClosedSprints: ->
        @scope.$apply =>
            @scope.closedSprints =  []
            @rootscope.$broadcast("closed-sprints:reloaded", [])

    loadClosedSprints: ->
        params = {closed: true}
        return @rs.sprints.list(@scope.projectId, params).then (sprints) =>
            # NOTE: Fix order of USs because the filter orderBy does not work propertly in partials files
            for sprint in sprints
                sprint.user_stories = _.sortBy(sprint.user_stories, "sprint_order")
            @scope.closedSprints =  sprints
            @rootscope.$broadcast("closed-sprints:reloaded", sprints)
            return sprints

    loadSprints: ->
        params = {closed: false}
        return @rs.sprints.list(@scope.projectId, params).then (sprints) =>
            # NOTE: Fix order of USs because the filter orderBy does not work propertly in partials files
            for sprint in sprints
                sprint.user_stories = _.sortBy(sprint.user_stories, "sprint_order")

            @scope.sprints = sprints
            @scope.openSprints = _.filter(sprints, (sprint) => not sprint.closed).reverse()
            @scope.closedSprints =  [] if !@scope.closedSprints

            @scope.sprintsCounter = sprints.length
            @scope.sprintsById = groupBy(sprints, (x) -> x.id)
            @rootscope.$broadcast("sprints:loaded", sprints)
            return sprints

    resetFilters: ->
        selectedTags = _.filter(@scope.filters.tags, "selected")
        selectedStatuses = _.filter(@scope.filters.status, "selected")

        @scope.filtersQ = ""

        _.each [selectedTags, selectedStatuses], (filterGrp) =>
            _.each filterGrp, (item) =>
                filters = @scope.filters[item.type]
                filter = _.find(filters, {id: taiga.toString(item.id)})
                filter.selected = false

                @.unselectFilter(item.type, item.id)

        @.loadUserstories()
        @rootscope.$broadcast("filters:update")

    loadUserstories: ->
        @scope.httpParams = @.getUrlFilters()
        @rs.userstories.storeQueryParams(@scope.projectId, @scope.httpParams)

        promise = @q.all([@.refreshTagsColors(), @rs.userstories.listUnassigned(@scope.projectId, @scope.httpParams)])

        return promise.then (data) =>
            userstories = data[1]
            # NOTE: Fix order of USs because the filter orderBy does not work propertly in the partials files
            @scope.userstories = _.sortBy(userstories, "backlog_order")

            @.setSearchDataFilters()

            # The broadcast must be executed when the DOM has been fully reloaded.
            # We can't assure when this exactly happens so we need a defer
            scopeDefer @scope, =>
                @scope.$broadcast("userstories:loaded")

            return userstories

    loadBacklog: ->
        return @q.all([
            @.loadProjectStats(),
            @.loadSprints(),
            @.loadUserstories()
        ])

    loadProject: ->
        return @rs.projects.getBySlug(@params.pslug).then (project) =>
            if not project.is_backlog_activated
                @location.path(@navUrls.resolve("permission-denied"))

            @scope.projectId = project.id
            @scope.project = project
            @scope.totalClosedMilestones = project.total_closed_milestones
            @scope.$emit('project:loaded', project)
            @scope.points = _.sortBy(project.points, "order")
            @scope.pointsById = groupBy(project.points, (x) -> x.id)
            @scope.usStatusById = groupBy(project.us_statuses, (x) -> x.id)
            @scope.usStatusList = _.sortBy(project.us_statuses, "id")
            return project

    loadInitialData: ->
        promise = @.loadProject()
        promise.then (project) =>
            @.fillUsersAndRoles(project.members, project.roles)
            @.initializeSubscription()

        return promise
            .then(=> @.loadBacklog())
            .then(=> @.generateFilters())
            .then(=> @scope.$emit("backlog:loaded"))

    prepareBulkUpdateData: (uses, field="backlog_order") ->
         return _.map(uses, (x) -> {"us_id": x.id, "order": x[field]})

    resortUserStories: (uses, field="backlog_order") ->
        items = []

        for item, index in uses
            item[field] = index
            if item.isModified()
                items.push(item)

        return items

    moveUs: (ctx, usList, newUsIndex, newSprintId) ->
        oldSprintId = usList[0].milestone
        project = usList[0].project

        # In the same sprint or in the backlog
        if newSprintId == oldSprintId
            items = null
            userstories = null

            if newSprintId == null
                userstories = @scope.userstories
            else
                userstories = @scope.sprintsById[newSprintId].user_stories

            @scope.$apply ->
                for us, key in usList
                    r = userstories.indexOf(us)
                    userstories.splice(r, 1)

                args = [newUsIndex, 0].concat(usList)
                Array.prototype.splice.apply(userstories, args)

            # If in backlog
            if newSprintId == null
                # Rehash userstories order field

                items = @.resortUserStories(userstories, "backlog_order")
                data = @.prepareBulkUpdateData(items, "backlog_order")

                # Persist in bulk all affected
                # userstories with order change
                @rs.userstories.bulkUpdateBacklogOrder(project, data).then =>
                    for us in usList
                        @rootscope.$broadcast("sprint:us:moved", us, oldSprintId, newSprintId)

            # For sprint
            else
                # Rehash userstories order field
                items = @.resortUserStories(userstories, "sprint_order")
                data = @.prepareBulkUpdateData(items, "sprint_order")

                # Persist in bulk all affected
                # userstories with order change
                @rs.userstories.bulkUpdateSprintOrder(project, data).then =>
                    for us in usList
                        @rootscope.$broadcast("sprint:us:moved", us, oldSprintId, newSprintId)

            return promise

        # From sprint to backlog
        if newSprintId == null
            us.milestone = null for us in usList

            @scope.$apply =>
                # Add new us to backlog userstories list
                # @scope.userstories.splice(newUsIndex, 0, us)
                args = [newUsIndex, 0].concat(usList)
                Array.prototype.splice.apply(@scope.userstories, args)

                # Remove the us from the sprint list.
                sprint = @scope.sprintsById[oldSprintId]
                for us, key in usList
                    r = sprint.user_stories.indexOf(us)
                    sprint.user_stories.splice(r, 1)

            # Persist the milestone change of userstory
            promise = @repo.save(us)

            # Rehash userstories order field
            # and persist in bulk all changes.
            promise = promise.then =>
                items = @.resortUserStories(@scope.userstories, "backlog_order")
                data = @.prepareBulkUpdateData(items, "backlog_order")
                return @rs.userstories.bulkUpdateBacklogOrder(us.project, data).then =>
                    @rootscope.$broadcast("sprint:us:moved", us, oldSprintId, newSprintId)

            promise.then null, ->
                console.log "FAIL" # TODO

            return promise

        # From backlog to sprint
        newSprint = @scope.sprintsById[newSprintId]
        if oldSprintId == null
            us.milestone = newSprintId for us in usList

            @scope.$apply =>
                args = [newUsIndex, 0].concat(usList)

                # Add moving us to sprint user stories list
                Array.prototype.splice.apply(newSprint.user_stories, args)

                # Remove moving us from backlog userstories lists.
                for us, key in usList
                    r = @scope.userstories.indexOf(us)
                    @scope.userstories.splice(r, 1)

                    r = @scope.userstories.indexOf(us)
                    @scope.userstories.splice(r, 1)

        # From sprint to sprint
        else
            us.milestone = newSprintId for us in usList

            @scope.$apply =>
                args = [newUsIndex, 0].concat(usList)

                # Add new us to backlog userstories list
                Array.prototype.splice.apply(newSprint.user_stories, args)

                # Remove the us from the sprint list.
                for us in usList
                    oldSprint = @scope.sprintsById[oldSprintId]
                    r = oldSprint.user_stories.indexOf(us)
                    oldSprint.user_stories.splice(r, 1)

        # Persist the milestone change of userstory
        promises = _.map usList, (us) => @repo.save(us)

        # Rehash userstories order field
        # and persist in bulk all changes.
        promise = @q.all(promises).then =>
            items = @.resortUserStories(newSprint.user_stories, "sprint_order")
            data = @.prepareBulkUpdateData(items, "sprint_order")

            @rs.userstories.bulkUpdateSprintOrder(project, data).then =>
                @rootscope.$broadcast("sprint:us:moved", us, oldSprintId, newSprintId)

            @rs.userstories.bulkUpdateBacklogOrder(project, data).then =>
                for us in usList
                    @rootscope.$broadcast("sprint:us:moved", us, oldSprintId, newSprintId)

        promise.then null, ->
            console.log "FAIL" # TODO

        return promise

    isFilterSelected: (type, id) ->
        if @searchdata[type]? and @searchdata[type][id]
            return true
        return false

    setSearchDataFilters: () ->
        urlfilters = @.getUrlFilters()

        if urlfilters.q
            @scope.filtersQ = @scope.filtersQ or urlfilters.q

        @searchdata = {}
        for name, value of urlfilters
            if not @searchdata[name]?
                @searchdata[name] = {}

            for val in taiga.toString(value).split(",")
                @searchdata[name][val] = true

    getUrlFilters: ->
        return _.pick(@location.search(), "status", "tags", "q")

    generateFilters: ->
        urlfilters = @.getUrlFilters()
        @scope.filters =  {}

        loadFilters = {}
        loadFilters.project = @scope.projectId
        loadFilters.tags = urlfilters.tags

        return @rs.userstories.filtersData(loadFilters).then (data) =>
            choicesFiltersFormat = (choices, type, byIdObject) =>
                _.map choices, (t) ->
                    return {
                        id: t[0],
                        name: byIdObject[t[0]].name,
                        color: byIdObject[t[0]].color,
                        count: t[1],
                        type: type}

            tagsFilterFormat = (tags) =>
                return _.map tags, (t) =>
                    return {
                        id: t[0],
                        name: t[0],
                        color: @scope.project.tags_colors[t[0]],
                        count: t[1],
                        type: "tags"
                    }

            # Build filters data structure
            @scope.filters.status = choicesFiltersFormat(data.statuses, "status", @scope.usStatusById)
            @scope.filters.tags = tagsFilterFormat(data.tags)

            selectedTags = _.filter(@scope.filters.tags, "selected")
            selectedTags = _.map(selectedTags, "id")

            selectedStatuses = _.filter(@scope.filters.status, "selected")
            selectedStatuses = _.map(selectedStatuses, "id")

            @.markSelectedFilters(@scope.filters, urlfilters)

            #store query params
            @rs.userstories.storeQueryParams(@scope.projectId, {
                "status": selectedStatuses,
                "tags": selectedTags,
                "project": @scope.projectId
                "milestone": null
            })

    markSelectedFilters: (filters, urlfilters) ->
        # Build selected filters (from url) fast lookup data structure
        searchdata = {}
        for name, value of _.omit(urlfilters, "page", "orderBy")
            if not searchdata[name]?
                searchdata[name] = {}

            for val in "#{value}".split(",")
                searchdata[name][val] = true

        isSelected = (type, id) ->
            if searchdata[type]? and searchdata[type][id]
                return true
            return false

        for key, value of filters
            for obj in value
                obj.selected = if isSelected(obj.type, obj.id) then true else undefined

    ## Template actions

    updateUserStoryStatus: () ->
        @.setSearchDataFilters()
        @.generateFilters().then () ->
            @rootscope.$broadcast("filters:update")
            @.loadProjectStats()

    editUserStory: (us) ->
        @rootscope.$broadcast("usform:edit", us)

    deleteUserStory: (us) ->
        title = @translate.instant("US.TITLE_DELETE_ACTION")

        message = us.subject

        @confirm.askOnDelete(title, message).then (finish) =>
            # We modify the userstories in scope so the user doesn't see the removed US for a while
            @scope.userstories = _.without(@scope.userstories, us)
            promise = @.repo.remove(us)
            promise.then =>
                finish()
                @.loadBacklog()
            promise.then null, =>
                finish(false)
                @confirm.notify("error")

    addNewUs: (type) ->
        switch type
            when "standard" then @rootscope.$broadcast("usform:new", @scope.projectId,
                                                       @scope.project.default_us_status, @scope.usStatusList)
            when "bulk" then @rootscope.$broadcast("usform:bulk", @scope.projectId,
                                                   @scope.project.default_us_status)

    addNewSprint: () ->
        @rootscope.$broadcast("sprintform:create", @scope.projectId)

module.controller("BacklogController", BacklogController)

#############################################################################
## Backlog Directive
#############################################################################

BacklogDirective = ($repo, $rootscope, $translate) ->
    ## Doom line Link
    doomLineTemplate = _.template("""
    <div class="doom-line"><span><%- text %></span></div>
    """)

    linkDoomLine = ($scope, $el, $attrs, $ctrl) ->
        reloadDoomLine = ->
            if $scope.stats?
                removeDoomlineDom()

                stats = $scope.stats

                total_points = stats.total_points
                current_sum = stats.assigned_points

                return if not $scope.userstories

                for us, i in $scope.userstories
                    current_sum += us.total_points

                    if current_sum > total_points
                        domElement = $el.find('.backlog-table-body .us-item-row')[i]
                        addDoomLineDom(domElement)

                        break

        removeDoomlineDom = ->
            $el.find(".doom-line").remove()

        addDoomLineDom = (element) ->
            text = $translate.instant("BACKLOG.DOOMLINE")
            $(element).before(doomLineTemplate({"text": text}))

        getUsItems = ->
            rowElements = $el.find('.backlog-table-body .us-item-row')
            return _.map(rowElements, (x) -> angular.element(x))

        $scope.$on("userstories:loaded", reloadDoomLine)
        $scope.$watch "stats", reloadDoomLine

    ## Move to current sprint link

    linkToolbar = ($scope, $el, $attrs, $ctrl) ->
        moveToCurrentSprint = (selectedUss) ->
            ussCurrent = _($scope.userstories)

            # Remove them from backlog
            $scope.userstories = ussCurrent.without.apply(ussCurrent, selectedUss).value()

            extraPoints = _.map(selectedUss, (v, k) -> v.total_points)
            totalExtraPoints =  _.reduce(extraPoints, (acc, num) -> acc + num)

            # Add them to current sprint
            $scope.sprints[0].user_stories = _.union($scope.sprints[0].user_stories, selectedUss)

            # Update the total of points
            $scope.sprints[0].total_points += totalExtraPoints

            $repo.saveAll(selectedUss).then ->
                $ctrl.loadSprints()
                $ctrl.loadProjectStats()


        shiftPressed = false
        lastChecked = null

        checkSelected = (target) ->
            lastChecked = target.closest(".us-item-row")
            moveToCurrentSprintDom = $el.find("#move-to-current-sprint")
            selectedUsDom = $el.find(".backlog-table-body .user-stories input:checkbox:checked")

            if selectedUsDom.length > 0 and $scope.sprints.length > 0
                moveToCurrentSprintDom.show()
            else
                moveToCurrentSprintDom.hide()

            target.closest('.us-item-row').toggleClass('ui-multisortable-multiple')

        $(window).on "keydown.shift-pressed keyup.shift-pressed", (event) ->
            shiftPressed = !!event.shiftKey

            return true

        # Enable move to current sprint only when there are selected us's
        $el.on "change", ".backlog-table-body .user-stories input:checkbox", (event) ->
            # check elements between the last two if shift is pressed
            if lastChecked && shiftPressed
                elements = []
                current = $(event.currentTarget).closest(".us-item-row")
                nextAll = lastChecked.nextAll()
                prevAll = lastChecked.prevAll()

                if _.some(nextAll, (next) -> next == current[0])
                    elements = lastChecked.nextUntil(current)
                else if _.some(prevAll, (prev) -> prev == current[0])
                    elements = lastChecked.prevUntil(current)

                _.map elements, (elm) ->
                    input = $(elm).find("input:checkbox")
                    input.prop('checked', true)
                    checkSelected(input)

            target = angular.element(event.currentTarget)
            checkSelected(target)

        $el.on "click", "#move-to-current-sprint", (event) =>
            # Calculating the us's to be modified
            ussDom = $el.find(".backlog-table-body .user-stories input:checkbox:checked")

            ussToMove = _.map ussDom, (item) ->
                item =  $(item).closest('.tg-scope')
                itemScope = item.scope()
                itemScope.us.milestone = $scope.sprints[0].id
                return itemScope.us

            $scope.$apply(_.partial(moveToCurrentSprint, ussToMove))

        $el.on "click", "#show-tags", (event) ->
            event.preventDefault()

            $ctrl.toggleShowTags()

            showHideTags($ctrl)

    showHideTags = ($ctrl) ->
        elm = angular.element("#show-tags")

        if $ctrl.showTags
            elm.addClass("active")

            text = $translate.instant("BACKLOG.TAGS.HIDE")
            elm.find(".text").text(text)
        else
            elm.removeClass("active")

            text = $translate.instant("BACKLOG.TAGS.SHOW")
            elm.find(".text").text(text)

    showHideFilter = ($scope, $el, $ctrl) ->
        sidebar = $el.find("sidebar.filters-bar")
        sidebar.one "transitionend", () ->
            timeout 150, ->
                $rootscope.$broadcast("resize")
                $('.burndown').css("visibility", "visible")

        target = angular.element("#show-filters-button")
        $('.burndown').css("visibility", "hidden")
        sidebar.toggleClass("active")
        target.toggleClass("active")

        hideText = $translate.instant("BACKLOG.FILTERS.HIDE")
        showText = $translate.instant("BACKLOG.FILTERS.SHOW")

        toggleText(target.find(".text"), [hideText, showText])

        if !sidebar.hasClass("active")
            $ctrl.resetFilters()

        $ctrl.toggleActiveFilters()

    ## Filters Link

    linkFilters = ($scope, $el, $attrs, $ctrl) ->
        $scope.filtersSearch = {}
        $el.on "click", "#show-filters-button", (event) ->
            event.preventDefault()
            $scope.$apply ->
                showHideFilter($scope, $el, $ctrl)

    link = ($scope, $el, $attrs, $rootscope) ->
        $ctrl = $el.controller()

        linkToolbar($scope, $el, $attrs, $ctrl)
        linkFilters($scope, $el, $attrs, $ctrl)
        linkDoomLine($scope, $el, $attrs, $ctrl)

        $el.find(".backlog-table-body").disableSelection()

        filters = $ctrl.getUrlFilters()
        if filters.status ||
           filters.tags ||
           filters.q
            showHideFilter($scope, $el, $ctrl)

        $scope.$on "showTags", () ->
            showHideTags($ctrl)

        $scope.$on "$destroy", ->
            $el.off()
            $(window).off(".shift-pressed")

    return {link: link}


module.directive("tgBacklog", ["$tgRepo", "$rootScope", "$translate", BacklogDirective])

#############################################################################
## User story points directive
#############################################################################

UsRolePointsSelectorDirective = ($rootscope, $template, $compile, $translate) ->
    selectionTemplate = $template.get("backlog/us-role-points-popover.html", true)

    link = ($scope, $el, $attrs) ->
        # Watchers
        bindOnce $scope, "project", (project) ->
            roles = _.filter(project.roles, "computable")
            numberOfRoles = _.size(roles)

            if numberOfRoles > 1
                $el.append($compile(selectionTemplate({"roles": roles}))($scope))
            else
                $el.find(".icon-arrow-bottom").remove()
                $el.find(".header-points").addClass("not-clickable")

        $scope.$on "uspoints:select", (ctx, roleId, roleName) ->
            $el.find(".popover").popover().close()
            $el.find(".header-points").html("#{roleName}/<span>Total</span>")

        $scope.$on "uspoints:clear-selection", (ctx, roleId) ->
            $el.find(".popover").popover().close()

            text = $translate.instant("COMMON.FIELDS.POINTS")
            $el.find(".header-points").text(text)

        # Dom Event Handlers
        $el.on "click", (event) ->
            target = angular.element(event.target)

            if target.is("span") or target.is("div")
                event.stopPropagation()

            $el.find(".popover").popover().open()

        $el.on "click", ".clear-selection", (event) ->
            event.preventDefault()
            event.stopPropagation()
            $rootscope.$broadcast("uspoints:clear-selection")

        $el.on "click", ".role", (event) ->
            event.preventDefault()
            event.stopPropagation()
            target = angular.element(event.currentTarget)
            rolScope = target.scope()
            $rootscope.$broadcast("uspoints:select", target.data("role-id"), target.text())

        $scope.$on "$destroy", ->
            $el.off()

    return {link: link}

module.directive("tgUsRolePointsSelector", ["$rootScope", "$tgTemplate", "$compile", UsRolePointsSelectorDirective])


UsPointsDirective = ($tgEstimationsService, $repo, $tgTemplate) ->
    rolesTemplate = $tgTemplate.get("common/estimation/us-points-roles-popover.html", true)

    link = ($scope, $el, $attrs) ->
        $ctrl = $el.controller()
        updatingSelectedRoleId = null
        selectedRoleId = null
        filteringRoleId = null
        estimationProcess = null

        $scope.$on "uspoints:select", (ctx, roleId, roleName) ->
            us = $scope.$eval($attrs.tgBacklogUsPoints)
            selectedRoleId = roleId
            estimationProcess.render()

        $scope.$on "uspoints:clear-selection", (ctx) ->
            us = $scope.$eval($attrs.tgBacklogUsPoints)
            selectedRoleId = null
            estimationProcess.render()

        $scope.$watch $attrs.tgBacklogUsPoints, (us) ->
            if us
                estimationProcess = $tgEstimationsService.create($el, us, $scope.project)

                # Update roles
                roles = estimationProcess.calculateRoles()
                if roles.length == 0
                    $el.find(".icon-arrow-bottom").remove()
                    $el.find("a.us-points").addClass("not-clickable")

                else if roles.length == 1
                    # Preselect the role if we have only one
                    selectedRoleId = _.keys(us.points)[0]

                if estimationProcess.isEditable
                    bindClickElements()

                estimationProcess.onSelectedPointForRole = (roleId, pointId) ->
                    @save(roleId, pointId).then ->
                        $ctrl.loadProjectStats()

                estimationProcess.render = () ->
                    totalPoints = @calculateTotalPoints()
                    if not selectedRoleId? or roles.length == 1
                        text = totalPoints
                        title = totalPoints
                    else
                        pointId = @us.points[selectedRoleId]
                        pointObj = @pointsById[pointId]
                        text = "#{pointObj.name} / <span>#{totalPoints}</span>"
                        title = "#{pointObj.name} / #{totalPoints}"

                    ctx = {
                        totalPoints: totalPoints
                        roles: @calculateRoles()
                        editable: @isEditable
                        text:  text
                        title: title
                    }
                    mainTemplate = "common/estimation/us-estimation-total.html"
                    template = $tgTemplate.get(mainTemplate, true)
                    html = template(ctx)
                    @$el.html(html)

                estimationProcess.render()

        renderRolesSelector = () ->
            roles = estimationProcess.calculateRoles()
            html = rolesTemplate({"roles": roles})
            # Render into DOM and show the new created element
            $el.append(html)
            $el.find(".pop-role").popover().open(() -> $(this).remove())

        bindClickElements = () ->
            $el.on "click", "a.us-points span", (event) ->
                event.preventDefault()
                event.stopPropagation()
                us = $scope.$eval($attrs.tgBacklogUsPoints)
                updatingSelectedRoleId = selectedRoleId
                if selectedRoleId?
                    estimationProcess.renderPointsSelector(selectedRoleId)
                else
                    renderRolesSelector()

            $el.on "click", ".role", (event) ->
                event.preventDefault()
                event.stopPropagation()
                target = angular.element(event.currentTarget)
                us = $scope.$eval($attrs.tgBacklogUsPoints)
                updatingSelectedRoleId = target.data("role-id")
                popRolesDom = $el.find(".pop-role")
                popRolesDom.find("a").removeClass("active")
                popRolesDom.find("a[data-role-id='#{updatingSelectedRoleId}']").addClass("active")
                estimationProcess.renderPointsSelector(updatingSelectedRoleId)

        $scope.$on "$destroy", ->
            $el.off()

    return {link: link}

module.directive("tgBacklogUsPoints", ["$tgEstimationsService", "$tgRepo", "$tgTemplate", UsPointsDirective])


#############################################################################
## Burndown graph directive
#############################################################################
ToggleBurndownVisibility = ($storage) ->
    link = ($scope, $el, $attrs) ->
        hash = generateHash(["is-burndown-grpahs-collapsed"])
        toggleGraph = ->
            if $scope.isBurndownGraphCollapsed
                $(".js-toggle-burndown-visibility-button").removeClass("active")
                $(".js-burndown-graph").removeClass("open")
            else
                $(".js-toggle-burndown-visibility-button").addClass("active")
                $(".js-burndown-graph").addClass("open")

        $scope.isBurndownGraphCollapsed = $storage.get(hash) or false
        toggleGraph()

        $el.on "click", ".js-toggle-burndown-visibility-button", ->
            $scope.isBurndownGraphCollapsed = !$scope.isBurndownGraphCollapsed
            $storage.set(hash, $scope.isBurndownGraphCollapsed)
            toggleGraph()

        $scope.$on "$destroy", ->
            $el.off()

    return {
        scope: {}
        link: link
    }

module.directive("tgToggleBurndownVisibility", ["$tgStorage", ToggleBurndownVisibility])


#############################################################################
## Burndown graph directive
#############################################################################

BurndownBacklogGraphDirective = ($translate) ->
    redrawChart = (element, dataToDraw) ->
        width = element.width()
        element.height(width/6)
        milestonesRange = [0..(dataToDraw.milestones.length - 1)]
        data = []
        zero_line = _.map(dataToDraw.milestones, (ml) -> 0)
        data.push({
            data: _.zip(milestonesRange, zero_line)
            lines:
                fillColor : "rgba(0,0,0,0)"
            points:
                show: false
        })
        optimal_line = _.map(dataToDraw.milestones, (ml) -> ml.optimal)
        data.push({
            data: _.zip(milestonesRange, optimal_line)
            lines:
                fillColor : "rgba(120,120,120,0.2)"
        })
        evolution_line = _.filter(_.map(dataToDraw.milestones, (ml) -> ml.evolution), (evolution) -> evolution?)
        data.push({
            data: _.zip(milestonesRange, evolution_line)
            lines:
                fillColor : "rgba(102,153,51,0.3)"
        })
        team_increment_line = _.map(dataToDraw.milestones, (ml) -> -ml["team-increment"])
        data.push({
            data: _.zip(milestonesRange, team_increment_line)
            lines:
                fillColor : "rgba(153,51,51,0.3)"
        })
        client_increment_line = _.map dataToDraw.milestones, (ml) ->
            -ml["team-increment"] - ml["client-increment"]
        data.push({
            data: _.zip(milestonesRange, client_increment_line)
            lines:
                fillColor : "rgba(255,51,51,0.3)"
        })

        colors = [
            "rgba(0,0,0,1)"
            "rgba(120,120,120,0.2)"
            "rgba(102,153,51,1)"
            "rgba(153,51,51,1)"
            "rgba(255,51,51,1)"
        ]

        options = {
            grid: {
                borderWidth: { top: 0, right: 1, left:0, bottom: 0 }
                borderColor: "#ccc"
                hoverable: true
            }
            xaxis: {
                ticks: dataToDraw.milestones.length
                axisLabel: $translate.instant("BACKLOG.CHART.XAXIS_LABEL"),
                axisLabelUseCanvas: true
                axisLabelFontSizePixels: 12
                axisLabelFontFamily: "Verdana, Arial, Helvetica, Tahoma, sans-serif"
                axisLabelPadding: 5
                tickFormatter: (val, axis) -> ""
            }
            yaxis: {
                axisLabel: $translate.instant("BACKLOG.CHART.YAXIS_LABEL"),
                axisLabelUseCanvas: true
                axisLabelFontSizePixels: 12
                axisLabelFontFamily: "Verdana, Arial, Helvetica, Tahoma, sans-serif"
                axisLabelPadding: 5
            }
            series: {
                shadowSize: 0
                lines: {
                    show: true
                    fill: true
                }
                points: {
                    show: true
                    fill: true
                    radius: 4
                    lineWidth: 2
                }
            }
            colors: colors
            tooltip: true
            tooltipOpts: {
                content: (label, xval, yval, flotItem) ->
                    if flotItem.seriesIndex == 1
                        ctx = {sprintName: dataToDraw.milestones[xval].name, value: Math.abs(yval)}
                        return $translate.instant("BACKLOG.CHART.OPTIMAL", ctx)
                    else if flotItem.seriesIndex == 2
                        ctx = {sprintName: dataToDraw.milestones[xval].name, value: Math.abs(yval)}
                        return $translate.instant("BACKLOG.CHART.REAL", ctx)
                    else if flotItem.seriesIndex == 3
                        ctx = {sprintName: dataToDraw.milestones[xval].name, value: Math.abs(yval)}
                        return $translate.instant("BACKLOG.CHART.INCREMENT_TEAM", ctx)
                    else
                        ctx = {sprintName: dataToDraw.milestones[xval].name, value: Math.abs(yval)}
                        return $translate.instant("BACKLOG.CHART.INCREMENT_CLIENT", ctx)
            }
        }

        element.empty()
        element.plot(data, options).data("plot")

    link = ($scope, $el, $attrs) ->
        element = angular.element($el)

        $scope.$watch "stats", (value) ->
            if $scope.stats?
                redrawChart(element, $scope.stats)

                $scope.$on "resize", ->
                    redrawChart(element, $scope.stats)

        $scope.$on "$destroy", ->
            $el.off()

    return {link: link}

module.directive("tgBurndownBacklogGraph", ["$translate", BurndownBacklogGraphDirective])


#############################################################################
## Backlog progress bar directive
#############################################################################

TgBacklogProgressBarDirective = ($template, $compile) ->
    template = $template.get("backlog/progress-bar.html", true)

    render = (scope, el, projectPointsPercentaje, closedPointsPercentaje) ->
        html = template({
            projectPointsPercentaje: projectPointsPercentaje,
            closedPointsPercentaje:closedPointsPercentaje
        })
        html = $compile(html)(scope)
        el.html(html)

    adjustPercentaje = (percentage) ->
        adjusted = _.max([0 , percentage])
        adjusted = _.min([100, adjusted])
        return Math.round(adjusted)

    link = ($scope, $el, $attrs) ->
        element = angular.element($el)

        $scope.$watch $attrs.tgBacklogProgressBar, (stats) ->
            if stats?
                totalPoints = stats.total_points
                definedPoints = stats.defined_points
                closedPoints = stats.closed_points
                if definedPoints > totalPoints
                    projectPointsPercentaje = totalPoints * 100 / definedPoints
                    closedPointsPercentaje = closedPoints * 100 / definedPoints
                else
                    projectPointsPercentaje = 100
                    closedPointsPercentaje = closedPoints * 100 / totalPoints

                projectPointsPercentaje = adjustPercentaje(projectPointsPercentaje - 3)
                closedPointsPercentaje = adjustPercentaje(closedPointsPercentaje - 3)
                render($scope, $el, projectPointsPercentaje, closedPointsPercentaje)

        $scope.$on "$destroy", ->
            $el.off()

    return {link: link}

module.directive("tgBacklogProgressBar", ["$tgTemplate", "$compile", TgBacklogProgressBarDirective])
