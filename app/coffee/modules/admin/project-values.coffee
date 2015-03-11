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
# File: modules/admin/project-profile.coffee
###

taiga = @.taiga

mixOf = @.taiga.mixOf
trim = @.taiga.trim
toString = @.taiga.toString
joinStr = @.taiga.joinStr
groupBy = @.taiga.groupBy
bindOnce = @.taiga.bindOnce
debounce = @.taiga.debounce

module = angular.module("taigaAdmin")

#############################################################################
## Project values section Controller
#############################################################################

class ProjectValuesSectionController extends mixOf(taiga.Controller, taiga.PageMixin)
    @.$inject = [
        "$scope",
        "$rootScope",
        "$tgRepo",
        "$tgConfirm",
        "$tgResources",
        "$routeParams",
        "$q",
        "$tgLocation",
        "$tgNavUrls",
        "$appTitle"
    ]

    constructor: (@scope, @rootscope, @repo, @confirm, @rs, @params, @q, @location, @navUrls, @appTitle) ->
        @scope.project = {}

        promise = @.loadInitialData()

        promise.then () =>
            @appTitle.set("Project values - " + @scope.sectionName + " - " + @scope.project.name)

        promise.then null, @.onInitialDataError.bind(@)

    loadProject: ->
        return @rs.projects.get(@scope.projectId).then (project) =>
            @scope.project = project
            @scope.$emit('project:loaded', project)
            return project

    loadInitialData: ->
        promise = @repo.resolve({pslug: @params.pslug}).then (data) =>
            @scope.projectId = data.project
            return data

        return promise.then => @.loadProject()


module.controller("ProjectValuesSectionController", ProjectValuesSectionController)

#############################################################################
## Project values Controller
#############################################################################

class ProjectValuesController extends taiga.Controller
    @.$inject = [
        "$scope",
        "$rootScope",
        "$tgRepo",
        "$tgConfirm",
        "$tgResources",
    ]

    constructor: (@scope, @rootscope, @repo, @confirm, @rs) ->
        @scope.$on("admin:project-values:move", @.moveValue)
        @rootscope.$on("project:loaded", @.loadValues)

    loadValues: =>
        return @rs[@scope.resource].listValues(@scope.projectId, @scope.type).then (values) =>
            @scope.values = values
            @scope.maxValueOrder = _.max(values, "order").order
            return values

    moveValue: (ctx, itemValue, itemIndex) =>
        values = @scope.values
        r = values.indexOf(itemValue)
        values.splice(r, 1)
        values.splice(itemIndex, 0, itemValue)
        _.each values, (value, index) ->
            value.order = index

        @repo.saveAll(values)

module.controller("ProjectValuesController", ProjectValuesController)


#############################################################################
## Project values directive
#############################################################################

ProjectValuesDirective = ($log, $repo, $confirm, $location, animationFrame) ->
    ## Drag & Drop Link

    linkDragAndDrop = ($scope, $el, $attrs) ->
        oldParentScope = null
        newParentScope = null
        itemEl = null
        tdom = $el.find(".sortable")

        tdom.sortable({
            handle: ".row.table-main.visualization",
            dropOnEmpty: true
            connectWith: ".project-values-body"
            revert: 400
            axis: "y"
        })

        tdom.on "sortstop", (event, ui) ->
            itemEl = ui.item
            itemValue = itemEl.scope().value
            itemIndex = itemEl.index()
            $scope.$broadcast("admin:project-values:move", itemValue, itemIndex)

        $scope.$on "$destroy", ->
            $el.off()

    ## Value Link

    linkValue = ($scope, $el, $attrs) ->
        $ctrl = $el.controller()
        valueType = $attrs.type

        initializeNewValue = ->
            $scope.newValue = {
                "name": ""
                "is_closed": false
                "is_archived": false
            }

        initializeNewValue()

        goToBottomList = (focus = false) =>
            table = $el.find(".table-main")

            $(document.body).scrollTop(table.offset().top + table.height())

            if focus
                $el.find(".new-value input:visible").first().focus()

        saveValue = (target) ->
            formEl = target.parents("form")
            form = formEl.checksley()
            return if not form.validate()

            value = formEl.scope().value
            promise = $repo.save(value)
            promise.then =>
                row = target.parents(".row.table-main")
                row.addClass("hidden")
                row.siblings(".visualization").removeClass('hidden')

            promise.then null, (data) ->
                form.setErrors(data)

        saveNewValue = (target) ->
            formEl = target.parents("form")
            form = formEl.checksley()
            return if not form.validate()

            $scope.newValue.project = $scope.project.id

            $scope.newValue.order = if $scope.maxValueOrder then $scope.maxValueOrder + 1 else 1

            promise = $repo.create(valueType, $scope.newValue)
            promise.then (data) =>
                target.addClass("hidden")

                $scope.values.push(data)
                $scope.maxValueOrder = data.order
                initializeNewValue()

            promise.then null, (data) ->
                form.setErrors(data)

        cancel = (target) ->
            row = target.parents(".row.table-main")
            formEl = target.parents("form")
            value = formEl.scope().value
            $scope.$apply ->
                row.addClass("hidden")
                value.revert()
                row.siblings(".visualization").removeClass('hidden')

        $el.on "click", ".show-add-new", (event) ->
            event.preventDefault()
            $el.find(".new-value").removeClass('hidden')

            goToBottomList(true)

        $el.on "click", ".add-new", debounce 2000, (event) ->
            event.preventDefault()
            target = $el.find(".new-value")
            saveNewValue(target)

        $el.on "click", ".delete-new", (event) ->
            event.preventDefault()
            $el.find(".new-value").addClass("hidden")
            initializeNewValue()

        $el.on "click", ".edit-value", (event) ->
            event.preventDefault()
            target = angular.element(event.currentTarget)

            row = target.parents(".row.table-main")
            row.addClass("hidden")

            editionRow = row.siblings(".edition")
            editionRow.removeClass('hidden')
            editionRow.find('input:visible').first().focus().select()

        $el.on "keyup", ".edition input", (event) ->
            if event.keyCode == 13
                target = angular.element(event.currentTarget)
                saveValue(target)
            else if event.keyCode == 27
                target = angular.element(event.currentTarget)
                cancel(target)

        $el.on "keyup", ".new-value input", (event) ->
            if event.keyCode == 13
                target = $el.find(".new-value")
                saveNewValue(target)
            else if event.keyCode == 27
                $el.find(".new-value").addClass("hidden")
                initializeNewValue()

        $el.on "click", ".save", (event) ->
            event.preventDefault()
            target = angular.element(event.currentTarget)
            saveValue(target)

        $el.on "click", ".cancel", (event) ->
            event.preventDefault()
            target = angular.element(event.currentTarget)
            cancel(target)

        $el.on "click", ".delete-value", (event) ->
            event.preventDefault()
            target = angular.element(event.currentTarget)
            formEl = target.parents("form")
            value = formEl.scope().value

            choices = {}
            _.each $scope.values, (option) ->
                if value.id != option.id
                    choices[option.id] = option.name

            #TODO: i18n
            title = "Delete value"
            subtitle = value.name
            replacement = "All items with this value will be changed to"
            if _.keys(choices).length == 0
                return $confirm.error("You can't delete all values.")

            return $confirm.askChoice(title, subtitle, choices, replacement).then (response) ->
                onSucces = ->
                    $ctrl.loadValues().finally ->
                        response.finish()
                onError = ->
                    $confirm.notify("error")
                $repo.remove(value, {"moveTo": response.selected}).then(onSucces, onError)

    link = ($scope, $el, $attrs) ->
        linkDragAndDrop($scope, $el, $attrs)
        linkValue($scope, $el, $attrs)

        $scope.$on "$destroy", ->
            $el.off()

    return {link:link}

module.directive("tgProjectValues", ["$log", "$tgRepo", "$tgConfirm", "$tgLocation", "animationFrame",
                                     ProjectValuesDirective])


#############################################################################
## Color selection directive
#############################################################################

ColorSelectionDirective = () ->
    ## Color selection Link

    link = ($scope, $el, $attrs, $model) ->
        $ctrl = $el.controller()

        $scope.$watch $attrs.ngModel, (element) ->
            $scope.color = element.color

        $el.on "click", ".current-color", (event) ->
            # Showing the color selector
            event.preventDefault()
            event.stopPropagation()
            target = angular.element(event.currentTarget)
            $el.find(".select-color").hide()
            target.siblings(".select-color").show()
            # Hide when click outside
            body = angular.element("body")
            body.on "click", (event) =>
                if angular.element(event.target).parent(".select-color").length == 0
                    $el.find(".select-color").hide()
                    body.unbind("click")

        $el.on "click", ".select-color .color", (event) ->
            # Selecting one color on color selector
            event.preventDefault()
            target = angular.element(event.currentTarget)
            $scope.$apply ->
                $model.$modelValue.color = target.data("color")
            $el.find(".select-color").hide()

        $el.on "click", ".select-color .selected-color", (event) ->
            event.preventDefault()
            $scope.$apply ->
                $model.$modelValue.color = $scope.color
            $el.find(".select-color").hide()

        $scope.$on "$destroy", ->
            $el.off()

      return {
          link: link
          require:"ngModel"
      }

module.directive("tgColorSelection", ColorSelectionDirective)

#############################################################################
## Custom Attributes Controller
#############################################################################

class ProjectCustomAttributesController extends mixOf(taiga.Controller, taiga.PageMixin)
    @.$inject = [
        "$scope",
        "$rootScope",
        "$tgRepo",
        "$tgResources",
        "$routeParams",
        "$q",
        "$tgLocation",
        "$tgNavUrls",
        "$appTitle",
    ]

    constructor: (@scope, @rootscope, @repo, @rs, @params, @q, @location, @navUrls, @appTitle) ->
        @scope.project = {}

        @rootscope.$on "project:loaded", =>
            @.loadCustomAttributes()
            @appTitle.set("Project Custom Attributes - " + @scope.sectionName + " - " + @scope.project.name)

    #########################
    # Custom Attribute
    #########################

    loadCustomAttributes: =>
        return @rs.customAttributes[@scope.type].list(@scope.projectId).then (customAttributes) =>
            @scope.customAttributes = customAttributes
            @scope.maxOrder = _.max(customAttributes, "order").order
            return customAttributes

    createCustomAttribute: (attrValues) =>
        return @repo.create("custom-attributes/#{@scope.type}", attrValues)

    saveCustomAttribute: (attrModel) =>
        return @repo.save(attrModel)

    deleteCustomAttribute: (attrModel) =>
        return @repo.remove(attrModel)

    moveCustomAttributes: (attrModel, newIndex) =>
        customAttributes = @scope.customAttributes
        r = customAttributes.indexOf(attrModel)
        customAttributes.splice(r, 1)
        customAttributes.splice(newIndex, 0, attrModel)

        _.each customAttributes, (val, idx) ->
            val.order = idx

        @repo.saveAll(customAttributes)


module.controller("ProjectCustomAttributesController", ProjectCustomAttributesController)


#############################################################################
## Custom Attributes Directive
#############################################################################

ProjectCustomAttributesDirective = ($log, $confirm, animationFrame) ->
    link = ($scope, $el, $attrs) ->
        $ctrl = $el.controller()

        $scope.$on "$destroy", ->
            $el.off()

        ##################################
        # Drag & Drop
        ##################################
        sortableEl = $el.find(".js-sortable")

        sortableEl.sortable({
            handle: ".js-view-custom-field",
            dropOnEmpty: true
            revert: 400
            axis: "y"
        })

        sortableEl.on "sortstop", (event, ui) ->
            itemEl = ui.item
            itemAttr = itemEl.scope().attr
            itemIndex = itemEl.index()
            $ctrl.moveCustomAttributes(itemAttr, itemIndex)

        ##################################
        # New custom attribute
        ##################################

        showCreateForm = ->
            $el.find(".js-new-custom-field").removeClass("hidden")
            $el.find(".js-new-custom-field input:visible").first().focus()

        hideCreateForm = ->
            $el.find(".js-new-custom-field").addClass("hidden")

        showAddButton = ->
            $el.find(".js-add-custom-field-button").removeClass("hidden")

        hideAddButton = ->
            $el.find(".js-add-custom-field-button").addClass("hidden")

        showCancelButton = ->
            $el.find(".js-cancel-new-custom-field-button").removeClass("hidden")

        hideCancelButton = ->
            $el.find(".js-cancel-new-custom-field-button").addClass("hidden")

        resetNewAttr = ->
            $scope.newAttr = {}

        create = (formEl) ->
            form = formEl.checksley()
            return if not form.validate()

            onSucces = =>
                $ctrl.loadCustomAttributes()
                hideCreateForm()
                resetNewAttr()
                $confirm.notify("success")

            onError = (data) =>
                form.setErrors(data)

            attr = $scope.newAttr
            attr.project = $scope.projectId
            attr.order = if $scope.maxOrder then $scope.maxOrder + 1 else 1

            $ctrl.createCustomAttribute(attr).then(onSucces, onError)

        cancelCreate = ->
            hideCreateForm()
            resetNewAttr()

        $scope.$watch "customAttributes", (customAttributes) ->
            return if not customAttributes

            if customAttributes.length == 0
                hideCancelButton()
                hideAddButton()
                showCreateForm()
            else
                hideCreateForm()
                showAddButton()
                showCancelButton()

        $el.on "click", ".js-add-custom-field-button", (event) ->
            event.preventDefault()

            showCreateForm()

        $el.on "click", ".js-create-custom-field-button", debounce 2000, (event) ->
            event.preventDefault()
            target = angular.element(event.currentTarget)
            formEl = target.closest("form")

            create(formEl)

        $el.on "click", ".js-cancel-new-custom-field-button", (event) ->
            event.preventDefault()

            cancelCreate()

        $el.on "keyup", ".js-new-custom-field input", (event) ->
            if event.keyCode == 13 # Enter
                target = angular.element(event.currentTarget)
                formEl = target.closest("form")
                create(formEl)
            else if event.keyCode == 27 # Esc
                cancelCreate()

        ##################################
        # Edit custom attribute
        ##################################

        showEditForm = (formEl) ->
            formEl.find(".js-view-custom-field").addClass("hidden")
            formEl.find(".js-edit-custom-field").removeClass("hidden")
            formEl.find(".js-edit-custom-field input:visible").first().focus().select()

        hideEditForm = (formEl) ->
            formEl.find(".js-edit-custom-field").addClass("hidden")
            formEl.find(".js-view-custom-field").removeClass("hidden")

        revertChangesInCustomAttribute = (formEl) ->
            $scope.$apply ->
                formEl.scope().attr.revert()

        update = (formEl) ->
            form = formEl.checksley()
            return if not form.validate()

            onSucces = =>
                $ctrl.loadCustomAttributes()
                hideEditForm(formEl)
                $confirm.notify("success")

            onError = (data) =>
                form.setErrors(data)

            attr = formEl.scope().attr
            $ctrl.saveCustomAttribute(attr).then(onSucces, onError)

        cancelUpdate = (formEl) ->
            hideEditForm(formEl)
            revertChangesInCustomAttribute(formEl)

        $el.on "click", ".js-edit-custom-field-button", (event) ->
            event.preventDefault()
            target = angular.element(event.currentTarget)
            formEl = target.closest("form")

            showEditForm(formEl)

        $el.on "click", ".js-update-custom-field-button", debounce 2000, (event) ->
            event.preventDefault()
            target = angular.element(event.currentTarget)
            formEl = target.closest("form")

            update(formEl)

        $el.on "click", ".js-cancel-edit-custom-field-button", (event) ->
            event.preventDefault()
            target = angular.element(event.currentTarget)
            formEl = target.closest("form")

            cancelUpdate(formEl)

        $el.on "keyup", ".js-edit-custom-field input", (event) ->
            if event.keyCode == 13 # Enter
                target = angular.element(event.currentTarget)
                formEl = target.closest("form")
                update(formEl)
            else if event.keyCode == 27 # Esc
                target = angular.element(event.currentTarget)
                formEl = target.closest("form")
                cancelUpdate(formEl)

        ##################################
        # Delete custom attribute
        ##################################

        deleteCustomAttribute = (formEl) ->
            attr = formEl.scope().attr

            title = "Delete custom attribute" # i18n
            subtitle = "Remeber that all values in this custom field will be deleted.</br> Are you sure you want to continue?"
            message = attr.name
            $confirm.ask(title, subtitle, message).then (finish) ->
                onSucces = ->
                    $ctrl.loadCustomAttributes().finally ->
                        finish()

                onError = ->
                    finish(false)
                    $confirm.notify("error", null, "We have not been able to delete '#{message}'.")

                $ctrl.deleteCustomAttribute(attr).then(onSucces, onError)

        $el.on "click", ".js-delete-custom-field-button", debounce 2000, (event) ->
            event.preventDefault()
            target = angular.element(event.currentTarget)
            formEl = target.closest("form")

            deleteCustomAttribute(formEl)

    return {link: link}

module.directive("tgProjectCustomAttributes", ["$log", "$tgConfirm", "animationFrame", ProjectCustomAttributesDirective])

#############################################################################
## CSV Exporter directive
#############################################################################

class CsvExporterController extends taiga.Controller
    @.$inject = [
        "$scope",
        "$rootScope",
        "$tgUrls",
        "$tgConfirm",
        "$tgResources",
    ]

    constructor: (@scope, @rootscope, @urls, @confirm, @rs) ->
        @rootscope.$on("project:loaded", @.setCsvUuid)
        @scope.$watch "csvUuid", (value) =>
            if value
                @scope.csvUrl = @urls.resolveAbsolute("#{@.type}-csv", value)
            else
                @scope.csvUrl = ""

    setCsvUuid: =>
        @scope.csvUuid = @scope.project["#{@.type}_csv_uuid"]

    _generateUuid: (finish) =>
        promise = @rs.projects["regenerate_#{@.type}_csv_uuid"](@scope.projectId)

        promise.then (data) =>
            @scope.csvUuid = data.data?.uuid

        promise.then null, =>
            @confirm.notify("error")

        promise.finally ->
            finish()
        return promise

    regenerateUuid: ->
        #TODO: i18n
        if @scope.csvUuid
            @confirm.ask("Change URL", "You going to change the CSV data access url. The previous url will be disabled. Are you sure?").then @._generateUuid
        else
            @._generateUuid(_.identity)

class CsvExporterUserstoriesController extends CsvExporterController
    type: "userstories"

class CsvExporterTasksController extends CsvExporterController
    type: "tasks"

class CsvExporterIssuesController extends CsvExporterController
    type: "issues"

module.controller("CsvExporterUserstoriesController", CsvExporterUserstoriesController)
module.controller("CsvExporterTasksController", CsvExporterTasksController)
module.controller("CsvExporterIssuesController", CsvExporterIssuesController)
