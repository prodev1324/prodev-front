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
# File: modules/common/components.coffee
###

taiga = @.taiga
bindOnce = @.taiga.bindOnce
normalizeString = @.taiga.normalizeString

module = angular.module("taigaCommon")


#############################################################################
## Date Range Directive (used mainly for sprint date range)
#############################################################################

DateRangeDirective = ($translate) ->
    renderRange = ($el, first, second) ->
        prettyDate = $translate.instant("BACKLOG.SPRINTS.DATE")
        initDate = moment(first).format(prettyDate)
        endDate = moment(second).format(prettyDate)
        $el.html("#{initDate}-#{endDate}")

    link = ($scope, $el, $attrs) ->
        [first, second] = $attrs.tgDateRange.split(",")

        bindOnce $scope, first, (valFirst) ->
            bindOnce $scope, second, (valSecond) ->
                renderRange($el, valFirst, valSecond)

    return {link:link}

module.directive("tgDateRange", ["$translate", DateRangeDirective])


#############################################################################
## Date Selector Directive (using pikaday)
#############################################################################

DateSelectorDirective = ($rootscope, datePickerConfigService) ->
    link = ($scope, $el, $attrs, $model) ->
        selectedDate = null

        initialize = () ->
            datePickerConfig = datePickerConfigService.get()

            _.merge(datePickerConfig, {
                field: $el[0]
            })

            $el.picker = new Pikaday(datePickerConfig)

        unbind = $rootscope.$on "$translateChangeEnd", (ctx) =>
            $el.picker.destroy() if $el.picker
            initialize()

        $attrs.$observe "pickerValue", (val) ->
            $el.val(val)

            if val?
                $el.picker.destroy() if $el.picker
                initialize()

            $el.picker.setDate(val)

        $scope.$on "$destroy", ->
            $el.off()
            unbind()
            $el.picker.destroy()

    return {
        link: link
    }

module.directive("tgDateSelector", ["$rootScope", "tgDatePickerConfigService", DateSelectorDirective])


#############################################################################
## Sprint Progress Bar Directive
#############################################################################

SprintProgressBarDirective = ->
    renderProgress = ($el, percentage, visual_percentage) ->
        if $el.hasClass(".current-progress")
            $el.css("width", "#{percentage}%")
        else
            $el.find(".current-progress").css("width", "#{visual_percentage}%")
            $el.find(".number").html("#{percentage} %")

    link = ($scope, $el, $attrs) ->
        bindOnce $scope, $attrs.tgSprintProgressbar, (sprint) ->
            closedPoints = sprint.closed_points
            totalPoints = sprint.total_points
            percentage = 0
            percentage = Math.round(100 * (closedPoints/totalPoints)) if totalPoints != 0
            visual_percentage = 0
            #Visual hack for .current-progress bar
            visual_percentage = Math.round(98 * (closedPoints/totalPoints)) if totalPoints != 0

            renderProgress($el, percentage, visual_percentage)

        $scope.$on "$destroy", ->
            $el.off()

    return {link: link}

module.directive("tgSprintProgressbar", SprintProgressBarDirective)


#############################################################################
## Created-by display directive
#############################################################################

CreatedByDisplayDirective = ($template, $compile, $translate, $navUrls, avatarService)->
    # Display the owner information (full name and photo) and the date of
    # creation of an object (like USs, tasks and issues).
    #
    # Example:
    #     div.us-created-by(tg-created-by-display, ng-model="us")
    #
    # Requirements:
    #   - model object must have the attributes 'created_date' and
    #     'owner'(ng-model)
    #   - scope.usersById object is required.

    link = ($scope, $el, $attrs) ->
        bindOnce $scope, $attrs.ngModel, (model) ->
            if model?

                avatar = avatarService.getAvatar(model.owner_extra_info)
                $scope.owner = model.owner_extra_info or {
                    full_name_display: $translate.instant("COMMON.EXTERNAL_USER")
                }

                $scope.owner.avatar = avatar.url
                $scope.owner.bg = avatar.bg

                $scope.url = if $scope.owner?.is_active then $navUrls.resolve("user-profile", {username: $scope.owner.username}) else ""


                $scope.date =  moment(model.created_date).format($translate.instant("COMMON.DATETIME"))

        $scope.$on "$destroy", ->
            $el.off()

    return {
        link: link
        restrict: "EA"
        require: "ngModel",
        scope: true,
        templateUrl: "common/components/created-by.html"
    }

module.directive("tgCreatedByDisplay", ["$tgTemplate", "$compile", "$translate", "$tgNavUrls", "tgAvatarService",
                                        CreatedByDisplayDirective])


UserDisplayDirective = ($template, $compile, $translate, $navUrls, avatarService)->
    # Display the user information (full name and photo).
    #
    # Example:
    #     div.creator(tg-user-display, tg-user-id="{{ user.id }}")
    #
    # Requirements:
    #   - scope.usersById object is required.

    link = ($scope, $el, $attrs) ->
        id = $attrs.tgUserId
        $scope.user = $scope.usersById[id] or {
            full_name_display: $translate.instant("COMMON.EXTERNAL_USER")
        }

        avatar = avatarService.getAvatar($scope.usersById[id] or null)

        $scope.user.avatar = avatar.url
        $scope.user.bg = avatar.bg

        $scope.url = if $scope.user.is_active then $navUrls.resolve("user-profile", {username: $scope.user.username}) else ""

        $scope.$on "$destroy", ->
            $el.off()

    return {
        link: link
        restrict: "EA"
        scope: true,
        templateUrl: "common/components/user-display.html"
    }

module.directive("tgUserDisplay", ["$tgTemplate", "$compile", "$translate", "$tgNavUrls", "tgAvatarService",
                                   UserDisplayDirective])

#############################################################################
## Watchers directive
#############################################################################

WatchersDirective = ($rootscope, $confirm, $repo, $modelTransform, $template, $compile, $translate) ->
    # You have to include a div with the tg-lb-watchers directive in the page
    # where use this directive

    link = ($scope, $el, $attrs, $model) ->
        isEditable = ->
            return $scope.project?.my_permissions?.indexOf($attrs.requiredPerm) != -1

        save = (watchers) ->
            transform = $modelTransform.save (item) ->
                item.watchers = watchers

                return item

            transform.then ->
                watchers = _.map(watchers, (watcherId) -> $scope.usersById[watcherId])
                renderWatchers(watchers)
                $rootscope.$broadcast("object:updated")
            transform.then null, ->
                $confirm.notify("error")

        deleteWatcher = (watcherIds) ->
            transform = $modelTransform.save (item) ->
                item.watchers = watcherIds

                return item

            transform.then () ->
                item = $modelTransform.getObj()
                watchers = _.map(item.watchers, (watcherId) -> $scope.usersById[watcherId])
                renderWatchers(watchers)
                $rootscope.$broadcast("object:updated")

            transform.then null, ->
                item.revert()
                $confirm.notify("error")

        renderWatchers = (watchers) ->
            $scope.watchers = watchers
            $scope.isEditable = isEditable()

        $el.on "click", ".js-delete-watcher", (event) ->
            event.preventDefault()
            return if not isEditable()
            target = angular.element(event.currentTarget)
            watcherId = target.data("watcher-id")

            title = $translate.instant("COMMON.WATCHERS.TITLE_LIGHTBOX_DELETE_WARTCHER")
            message = $scope.usersById[watcherId].full_name_display

            $confirm.askOnDelete(title, message).then (askResponse) =>
                askResponse.finish()

                watcherIds = _.clone($model.$modelValue.watchers, false)
                watcherIds = _.pull(watcherIds, watcherId)

                deleteWatcher(watcherIds)

        $scope.$on "watcher:added", (ctx, watcherId) ->
            watchers = _.clone($model.$modelValue.watchers, false)
            watchers.push(watcherId)
            watchers = _.uniq(watchers)

            save(watchers)

        $scope.$watch $attrs.ngModel, (item) ->
            return if not item?
            watchers = _.map(item.watchers, (watcherId) -> $scope.usersById[watcherId])
            watchers = _.filter watchers, (it) -> return !!it

            renderWatchers(watchers)

        $scope.$on "$destroy", ->
            $el.off()

    return {
        scope: true,
        templateUrl: "common/components/watchers.html",
        link:link,
        require:"ngModel"
    }

module.directive("tgWatchers", ["$rootScope", "$tgConfirm", "$tgRepo", "$tgQueueModelTransformation", "$tgTemplate", "$compile",
                                "$translate", WatchersDirective])



#############################################################################
## Assigned Users directive
#############################################################################

AssignedUsersDirective = ($rootscope, $confirm, $repo, $modelTransform, $template, $compile, $translate, $currentUserService) ->
    # You have to include a div with the tg-lb-assignedusers directive in the page
    # where use this directive

    link = ($scope, $el, $attrs, $model) ->
        isEditable = ->
            return $scope.project?.my_permissions?.indexOf($attrs.requiredPerm) != -1
        isAssigned = ->
            return $scope.assignedUsers.length > 0

        save = (assignedUsers, assignedToUser) ->
            transform = $modelTransform.save (item) ->
                item.assigned_users = assignedUsers
                if not item.assigned_to
                    item.assigned_to = assignedToUser
                return item

            transform.then ->
                assignedUsers = _.map(assignedUsers, (assignedUserId) -> $scope.usersById[assignedUserId])
                renderAssignedUsers(assignedUsers)
                result = $rootscope.$broadcast("object:updated")

            transform.then null, ->
                $confirm.notify("error")

        openAssignedUsers = ->
            item = _.clone($model.$modelValue, false)
            $rootscope.$broadcast("assigned-user:add", item)

        $scope.selfAssign = () ->
            return if not isEditable()
            currentUserId = $currentUserService.getUser().get('id')
            assignedUsers = _.clone($model.$modelValue.assigned_users, false)
            assignedUsers.push(currentUserId)
            assignedUsers = _.uniq(assignedUsers)
            save(assignedUsers, currentUserId)

        $scope.unassign = (user) ->
            return if not isEditable()
            target = angular.element(event.currentTarget)
            assignedUserId = user.id

            title = $translate.instant("COMMON.ASSIGNED_USERS.TITLE_LIGHTBOX_DELETE_ASSIGNED")
            message = $scope.usersById[assignedUserId].full_name_display

            $confirm.askOnDelete(title, message).then (askResponse) ->
                askResponse.finish()

                assignedUserIds = _.clone($model.$modelValue.assigned_users, false)
                assignedUserIds = _.pull(assignedUserIds, assignedUserId)

                deleteAssignedUser(assignedUserIds)

        deleteAssignedUser = (assignedUserIds) ->
            transform = $modelTransform.save (item) ->
                item.assigned_users = assignedUserIds

                # Update as
                if item.assigned_to not in assignedUserIds and assignedUserIds.length > 0
                    item.assigned_to = assignedUserIds[0]
                if assignedUserIds.length == 0
                    item.assigned_to = null

                return item

            transform.then () ->
                item = $modelTransform.getObj()
                assignedUsers = _.map(item.assignedUsers, (assignedUserId) -> $scope.usersById[assignedUserId])
                renderAssignedUsers(assignedUsers)
                $rootscope.$broadcast("object:updated")

            transform.then null, ->
                item.revert()
                $confirm.notify("error")

        renderAssignedUsers = (assignedUsers) ->
            $scope.assignedUsers = assignedUsers
            $scope.isEditable = isEditable()
            $scope.isAssigned = isAssigned()
            $scope.openAssignedUsers = openAssignedUsers

        $scope.$on "assigned-user:deleted", (ctx, assignedUserId) ->
            assignedUsersIds = _.clone($model.$modelValue.assigned_users, false)
            assignedUsersIds = _.pull(assignedUsersIds, assignedUserId)
            assignedUsersIds = _.uniq(assignedUsersIds)
            deleteAssignedUser(assignedUsersIds)

        $scope.$on "assigned-user:added", (ctx, assignedUserId) ->
            assignedUsers = _.clone($model.$modelValue.assigned_users, false)
            assignedUsers.push(assignedUserId)
            assignedUsers = _.uniq(assignedUsers)

            # Save assigned_users and assignedUserId for assign_to legacy attribute
            save(assignedUsers, assignedUserId)

        $scope.$watch $attrs.ngModel, (item) ->
            return if not item?
            assignedUsers = _.map(item.assigned_users, (assignedUserId) -> $scope.usersById[assignedUserId])
            assignedUsers = _.filter assignedUsers, (it) -> return !!it

            renderAssignedUsers(assignedUsers)

        $scope.$on "$destroy", ->
            $el.off()

    return {
        scope: true,
        templateUrl: "common/components/assigned-users.html",
        link:link,
        require:"ngModel"
    }

module.directive("tgAssignedUsers", ["$rootScope", "$tgConfirm", "$tgRepo",
"$tgQueueModelTransformation", "$tgTemplate", "$compile", "$translate", "tgCurrentUserService",
AssignedUsersDirective])


#############################################################################
## Assigned to directive
#############################################################################

AssignedToDirective = ($rootscope, $confirm, $repo, $loading, $modelTransform, $template,
$translate, $compile, $currentUserService, avatarService) ->
    # You have to include a div with the tg-lb-assignedto directive in the page
    # where use this directive
    template = $template.get("common/components/assigned-to.html", true)

    link = ($scope, $el, $attrs, $model) ->
        isEditable = ->
            return $scope.project?.my_permissions?.indexOf($attrs.requiredPerm) != -1

        save = (userId) ->
            item = $model.$modelValue.clone()
            item.assigned_to = userId

            currentLoading = $loading()
                .target($el)
                .start()

            transform = $modelTransform.save (item) ->
                item.assigned_to = userId
                return item

            transform.then (item) ->
                currentLoading.finish()
                $rootscope.$broadcast("object:updated")

            transform.then null, ->
                $confirm.notify("error")
                currentLoading.finish()

            return transform

        render = () ->
            template = $template.get("common/components/assigned-to.html")
            templateScope = $scope.$new()
            compiledTemplate = $compile(template)(templateScope)
            $el.html(compiledTemplate)

        $scope.assign = () ->
            $rootscope.$broadcast("assigned-to:add", $model.$modelValue)

        $scope.unassign = () ->
            title = $translate.instant("COMMON.ASSIGNED_TO.CONFIRM_UNASSIGNED")
            $confirm.ask(title).then (response) ->
                response.finish()
                save(null)

        $scope.selfAssign = () ->
            userId = $currentUserService.getUser().get('id')
            save(userId)

        $scope.$on "assigned-to:added", (ctx, userId, item) ->
            return if item.id != $model.$modelValue.id
            save(userId)

        $scope.$watch $attrs.ngModel, (instance) ->
            if instance?.assigned_to
                $scope.selected = instance.assigned_to
                assigned_to_extra_info = $scope.usersById[$scope.selected]
                $scope.fullName = assigned_to_extra_info?.full_name_display
                $scope.isUnassigned = false
                $scope.avatar = avatarService.getAvatar(assigned_to_extra_info)
                $scope.bg = $scope.avatar.bg
                $scope.isIocaine = instance?.is_iocaine
            else
                $scope.fullName = $translate.instant("COMMON.ASSIGNED_TO.ASSIGN")
                $scope.isUnassigned = true
                $scope.avatar = avatarService.getAvatar(null)
                $scope.bg = null
                $scope.isIocaine = false

            $scope.fullNameVisible = !($scope.isUnassigned && !$currentUserService.isAuthenticated())
            $scope.isEditable = isEditable()
            render()

        $scope.$on "$destroy", ->
            $el.off()

    return {
        link:link,
        require:"ngModel"
    }

module.directive("tgAssignedTo", ["$rootScope", "$tgConfirm", "$tgRepo", "$tgLoading",
"$tgQueueModelTransformation", "$tgTemplate", "$translate", "$compile","tgCurrentUserService",
"tgAvatarService", AssignedToDirective])



#############################################################################
## Assigned to (inline) directive
#############################################################################

AssignedToInlineDirective = ($rootscope, $confirm, $repo, $loading, $modelTransform, $template
$translate, $compile, $currentUserService, avatarService) ->
    link = ($scope, $el, $attrs, $model) ->
        isEditable = ->
            return $scope.project?.my_permissions?.indexOf($attrs.requiredPerm) != -1

        filterUsers = (text, user) ->
            username = user.full_name_display.toUpperCase()
            username = normalizeString(username)
            text = text.toUpperCase()
            text = normalizeString(text)
            return _.includes(username, text)

        renderUserList = (text) ->
            users = _.clone($scope.activeUsers, true)
            users = _.reject(users, {"id": $scope.selected.id}) if $scope.selected?
            users = _.sortBy(users, (o) -> if o.id is $scope.user.id then 0 else o.id)
            users = _.filter(users, _.partial(filterUsers, text)) if text?

            visibleUsers = _.slice(users, 0, 5)
            visibleUsers = _.map visibleUsers, (user) -> user.avatar = avatarService.getAvatar(user)

            $scope.users = _.slice(users, 0, 5)
            $scope.showMore = users.length > 5

        renderUser = (assignedObject) ->
            if assignedObject?.assigned_to
                $scope.selected = assignedObject.assigned_to
                assigned_to_extra_info = $scope.usersById[$scope.selected]
                $scope.fullName = assigned_to_extra_info?.full_name_display
                $scope.isUnassigned = false
                $scope.avatar = avatarService.getAvatar(assigned_to_extra_info)
                $scope.bg = $scope.avatar.bg
                $scope.isIocaine = assignedObject?.is_iocaine
            else
                $scope.fullName = $translate.instant("COMMON.ASSIGNED_TO.ASSIGN")
                $scope.isUnassigned = true
                $scope.avatar = avatarService.getAvatar(null)
                $scope.bg = null
                $scope.isIocaine = false

            $scope.fullNameVisible = !($scope.isUnassigned && !$currentUserService.isAuthenticated())
            $scope.isEditable = isEditable()

        $el.on "click", ".users-search", (event) ->
            event.stopPropagation()

        $el.on "click", ".users-dropdown", (event) ->
            event.preventDefault()
            event.stopPropagation()
            renderUserList()
            $scope.$apply()
            $el.find(".pop-users").popover().open()

        $scope.selfAssign = () ->
            $model.$modelValue.assigned_to = $currentUserService.getUser().get('id')
            renderUser($model.$modelValue)

        $scope.unassign = () ->
            $model.$modelValue.assigned_to  = null
            renderUser()

        $scope.$watch "usersSearch", (searchingText) ->
            if searchingText?
                renderUserList(searchingText)
                $el.find('input').focus()

        $el.on "click", ".user-list-single", (event) ->
            event.preventDefault()
            target = angular.element(event.currentTarget)
            $model.$modelValue.assigned_to = target.data("user-id")
            renderUser($model.$modelValue)
            $scope.$apply()

        $scope.$watch $attrs.ngModel, (instance) ->
            renderUser(instance)

        $scope.$on "isiocaine:changed", (ctx, instance) ->
            renderUser(instance)

        $scope.$on "$destroy", ->
            $el.off()

    return {
        link:link,
        require:"ngModel",
        templateUrl: "common/components/assigned-to-inline.html"
    }

module.directive("tgAssignedToInline", ["$rootScope", "$tgConfirm", "$tgRepo", "$tgLoading"
"$tgQueueModelTransformation", "$tgTemplate", "$translate", "$compile","tgCurrentUserService"
"tgAvatarService", AssignedToInlineDirective])


#############################################################################
## Assigned users (inline) directive
#############################################################################

AssignedUsersInlineDirective = ($rootscope, $confirm, $repo, $loading, $modelTransform, $template
$translate, $compile, $currentUserService, avatarService) ->
    link = ($scope, $el, $attrs, $model) ->
        currentAssignedIds = []
        currentAssignedTo = null

        isAssigned = ->
            return currentAssignedIds.length > 0

        filterUsers = (text, user) ->
            username = user.full_name_display.toUpperCase()
            username = normalizeString(username)
            text = text.toUpperCase()
            text = normalizeString(text)
            return _.includes(username, text)

        renderUsersList = (text) ->
            users = _.clone($scope.activeUsers, true)
            users = _.sortBy(users, (o) -> if o.id is $scope.user.id then 0 else o.id)
            users = _.filter(users, _.partial(filterUsers, text)) if text?

            # Add selected users
            selected = []
            _.map users, (user) ->
                if user.id in currentAssignedIds
                    user.avatar = avatarService.getAvatar(user)
                    selected.push(user)

            # Filter users in searchs
            visible = []
            _.map users, (user) ->
                if user.id not in currentAssignedIds
                    user.avatar = avatarService.getAvatar(user)
                    visible.push(user)

            $scope.selected = _.slice(selected, 0, 5)
            if $scope.selected.length < 5
                $scope.users = _.slice(visible, 0, 5 - $scope.selected.length)
            else
                $scope.users = []
            $scope.showMore = users.length > 5

        renderUsers = () ->
            assignedUsers = _.map(currentAssignedIds, (assignedUserId) -> $scope.usersById[assignedUserId])
            assignedUsers = _.filter assignedUsers, (it) -> return !!it

            $scope.hiddenUsers = if currentAssignedIds.length > 3 then currentAssignedIds.length - 3 else 0
            $scope.assignedUsers = _.slice(assignedUsers, 0, 3)

            $scope.isAssigned = isAssigned()

        applyToModel = () ->
            _.map currentAssignedIds, (userId) ->
                if !$scope.usersById[userId]
                    currentAssignedIds.splice(currentAssignedIds.indexOf(userId), 1)
            if currentAssignedIds.length == 0
                currentAssignedTo = null
            else if currentAssignedIds.indexOf(currentAssignedTo) == -1 || !currentAssignedTo
                currentAssignedTo = currentAssignedIds[0]
            $model.$modelValue.setAttr('assigned_users', currentAssignedIds)
            $model.$modelValue.assigned_to = currentAssignedTo

        $el.on "click", ".users-dropdown", (event) ->
            event.preventDefault()
            event.stopPropagation()
            renderUsersList()
            $scope.$apply()
            $el.find(".pop-users").popover().open()

        $scope.selfAssign = () ->
            currentAssignedIds.push($currentUserService.getUser().get('id'))
            renderUsers()
            applyToModel()
            $scope.usersSearch = null

        $el.on "click", ".users-search", (event) ->
            event.stopPropagation()

        $scope.$watch "usersSearch", (searchingText) ->
            if searchingText?
                renderUsersList(searchingText)
                $el.find('input').focus()

        $el.on "click", ".user-list-single", (event) ->
            event.preventDefault()
            event.stopPropagation()
            target = angular.element(event.currentTarget)
            index = currentAssignedIds.indexOf(target.data("user-id"))
            if index == -1
                currentAssignedIds.push(target.data("user-id"))
            else
                currentAssignedIds.splice(index, 1)
            renderUsers()
            $el.find(".pop-users").popover().close()
            $scope.usersSearch = null
            $scope.$apply()

        $scope.$watch $attrs.ngModel, (item) ->
            return if not item?
            currentAssignedIds = []
            assigned_to = null

            if item.assigned_users?
                currentAssignedIds = item.assigned_users
            assigned_to = item.assigned_to
            renderUsers()

        $scope.$on "$destroy", ->
            $el.off()

    return {
        link:link,
        require: "ngModel",
        templateUrl: "common/components/assigned-users-inline.html"
    }

module.directive("tgAssignedUsersInline", ["$rootScope", "$tgConfirm", "$tgRepo",
"$tgLoading", "$tgQueueModelTransformation", "$tgTemplate", "$translate", "$compile",
"tgCurrentUserService", "tgAvatarService", AssignedUsersInlineDirective])


#############################################################################
## Block Button directive
#############################################################################

BlockButtonDirective = ($rootscope, $loading, $template) ->
    template = $template.get("common/components/block-button.html")

    link = ($scope, $el, $attrs, $model) ->
        isEditable = ->
            return $scope.project.my_permissions.indexOf("modify_us") != -1

        $scope.$watch $attrs.ngModel, (item) ->
            return if not item

            if isEditable()
                $el.find('.item-block').addClass('editable')

            if item.is_blocked
                $el.find('.item-block').removeClass('is-active')
                $el.find('.item-unblock').addClass('is-active')
            else
                $el.find('.item-block').addClass('is-active')
                $el.find('.item-unblock').removeClass('is-active')

        $el.on "click", ".item-block", (event) ->
            event.preventDefault()
            $rootscope.$broadcast("block", $model.$modelValue)

        $el.on "click", ".item-unblock", (event) ->
            event.preventDefault()
            currentLoading = $loading()
                .target($el.find(".item-unblock"))
                .start()

            finish = ->
                currentLoading.finish()

            $rootscope.$broadcast("unblock", $model.$modelValue, finish)

        $scope.$on "$destroy", ->
            $el.off()

    return {
        link: link
        restrict: "EA"
        require: "ngModel"
        template: template
    }

module.directive("tgBlockButton", ["$rootScope", "$tgLoading", "$tgTemplate", BlockButtonDirective])


#############################################################################
## Delete Button directive
#############################################################################

DeleteButtonDirective = ($log, $repo, $confirm, $location, $template) ->
    template = $template.get("common/components/delete-button.html")

    link = ($scope, $el, $attrs, $model) ->
        if not $attrs.onDeleteGoToUrl
            return $log.error "DeleteButtonDirective requires on-delete-go-to-url set in scope."
        if not $attrs.onDeleteTitle
            return $log.error "DeleteButtonDirective requires on-delete-title set in scope."

        $el.on "click", ".button-delete", (event) ->
            title = $attrs.onDeleteTitle
            subtitle = $model.$modelValue.subject

            $confirm.askOnDelete(title, subtitle).then (askResponse) =>
                promise = $repo.remove($model.$modelValue)
                promise.then =>
                    askResponse.finish()
                    url = $scope.$eval($attrs.onDeleteGoToUrl)
                    $location.path(url)
                promise.then null, =>
                    askResponse.finish(false)
                    $confirm.notify("error")

        $scope.$on "$destroy", ->
            $el.off()

    return {
        link: link
        restrict: "EA"
        require: "ngModel"
        template: template
    }

module.directive("tgDeleteButton", ["$log", "$tgRepo", "$tgConfirm", "$tgLocation", "$tgTemplate", DeleteButtonDirective])

#############################################################################
## Common list directives
#############################################################################
## NOTE: These directives are used in issues and search and are
##       completely bindonce, they only serves for visualization of data.
#############################################################################

ListItemEpicStatusDirective = ->
    link = ($scope, $el, $attrs) ->
        epic = $scope.$eval($attrs.tgListitemEpicStatus)
        bindOnce $scope, "epicStatusById", (epicStatusById) ->
            $el.html(epicStatusById[epic.status].name)

    return {link:link}

module.directive("tgListitemEpicStatus", ListItemEpicStatusDirective)

ListItemUsStatusDirective = ->
    link = ($scope, $el, $attrs) ->
        us = $scope.$eval($attrs.tgListitemUsStatus)
        bindOnce $scope, "usStatusById", (usStatusById) ->
            $el.html(usStatusById[us.status].name)

    return {link:link}

module.directive("tgListitemUsStatus", ListItemUsStatusDirective)


ListItemTaskStatusDirective = ->
    link = ($scope, $el, $attrs) ->
        task = $scope.$eval($attrs.tgListitemTaskStatus)
        bindOnce $scope, "taskStatusById", (taskStatusById) ->
            $el.html(taskStatusById[task.status].name)

    return {link:link}

module.directive("tgListitemTaskStatus", ListItemTaskStatusDirective)


ListItemAssignedtoDirective = ($template, $translate, avatarService) ->
    template = $template.get("common/components/list-item-assigned-to-avatar.html", true)

    link = ($scope, $el, $attrs) ->
        bindOnce $scope, "usersById", (usersById) ->
            item = $scope.$eval($attrs.tgListitemAssignedto)
            ctx = {
                name: $translate.instant("COMMON.ASSIGNED_TO.NOT_ASSIGNED"),
            }

            member = usersById[item.assigned_to]
            avatar = avatarService.getAvatar(member)

            ctx.imgurl = avatar.url
            ctx.bg = avatar.bg

            if member
                ctx.name = member.full_name_display

            $el.html(template(ctx))

    return {link:link}

module.directive("tgListitemAssignedto", ["$tgTemplate", "$translate", "tgAvatarService", ListItemAssignedtoDirective])


ListItemIssueStatusDirective = ->
    link = ($scope, $el, $attrs) ->
        issue = $scope.$eval($attrs.tgListitemIssueStatus)
        bindOnce $scope, "issueStatusById", (issueStatusById) ->
            $el.html(issueStatusById[issue.status].name)

    return {link:link}

module.directive("tgListitemIssueStatus", ListItemIssueStatusDirective)


ListItemTypeDirective = ->
    link = ($scope, $el, $attrs) ->
        render = (issueTypeById, issue) ->
            type = issueTypeById[issue.type]
            domNode = $el.find(".level")
            domNode.css("background-color", type.color)
            domNode.attr("title", type.name)

        bindOnce $scope, "issueTypeById", (issueTypeById) ->
            issue = $scope.$eval($attrs.tgListitemType)
            render(issueTypeById, issue)

        $scope.$watch $attrs.tgListitemType, (issue) ->
            render($scope.issueTypeById, issue)

    return {
        link: link
        templateUrl: "common/components/level.html"
    }

module.directive("tgListitemType", ListItemTypeDirective)


ListItemPriorityDirective = ->
    link = ($scope, $el, $attrs) ->
        render = (priorityById, issue) ->
            priority = priorityById[issue.priority]
            domNode = $el.find(".level")
            domNode.css("background-color", priority.color)
            domNode.attr("title", priority.name)

        bindOnce $scope, "priorityById", (priorityById) ->
            issue = $scope.$eval($attrs.tgListitemPriority)
            render(priorityById, issue)

        $scope.$watch $attrs.tgListitemPriority, (issue) ->
            render($scope.priorityById, issue)

    return {
        link: link
        templateUrl: "common/components/level.html"
    }

module.directive("tgListitemPriority", ListItemPriorityDirective)


ListItemSeverityDirective = ->
    link = ($scope, $el, $attrs) ->
        render = (severityById, issue) ->
            severity = severityById[issue.severity]
            domNode = $el.find(".level")
            domNode.css("background-color", severity.color)
            domNode.attr("title", severity.name)

        bindOnce $scope, "severityById", (severityById) ->
            issue = $scope.$eval($attrs.tgListitemSeverity)
            render(severityById, issue)

        $scope.$watch $attrs.tgListitemSeverity, (issue) ->
            render($scope.severityById, issue)

    return {
        link: link
        templateUrl: "common/components/level.html"
    }

module.directive("tgListitemSeverity", ListItemSeverityDirective)


#############################################################################
## Progress bar directive
#############################################################################

TgProgressBarDirective = ($template) ->
    template = $template.get("common/components/progress-bar.html", true)

    render = (el, percentage) ->
        el.html(template({percentage: percentage}))

    link = ($scope, $el, $attrs) ->
        element = angular.element($el)

        $scope.$watch $attrs.tgProgressBar, (percentage) ->
            percentage = _.max([0 , percentage])
            percentage = _.min([100, percentage])
            render($el, percentage)

        $scope.$on "$destroy", ->
            $el.off()

    return {link: link}

module.directive("tgProgressBar", ["$tgTemplate", TgProgressBarDirective])


#############################################################################
## Main title directive
#############################################################################

TgMainTitleDirective = ($translate) ->
    link = ($scope, $el, $attrs) ->
        $attrs.$observe "i18nSectionName", (i18nSectionName) ->
            $scope.sectionName = i18nSectionName

        $scope.$on "$destroy", ->
            $el.off()

    return {
        link: link
        templateUrl: "common/components/main-title.html"
        scope: {
            projectName : "=projectName"
        }
    }

module.directive("tgMainTitle", ["$translate",  TgMainTitleDirective])
