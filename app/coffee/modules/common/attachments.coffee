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
# File: modules/common/attachments.coffee
###

taiga = @.taiga
sizeFormat = @.taiga.sizeFormat
bindOnce = @.taiga.bindOnce
bindMethods = @.taiga.bindMethods

module = angular.module("taigaCommon")


class AttachmentsController extends taiga.Controller
    @.$inject = ["$scope", "$rootScope", "$tgRepo", "$tgResources", "$tgConfirm", "$q", "$translate"]

    constructor: (@scope, @rootscope, @repo, @rs, @confirm, @q, @translate) ->
        bindMethods(@)
        @.type = null
        @.objectId = null
        @.projectId = null

        @.uploadingAttachments = []
        @.attachments = []
        @.attachmentsCount = 0
        @.deprecatedAttachmentsCount = 0
        @.showDeprecated = false

    initialize: (type, objectId) ->
        @.type = type
        @.objectId = objectId
        @.projectId = @scope.projectId

    loadAttachments: ->
        return @.attachments if not @.objectId

        urlname = "attachments/#{@.type}"

        return @rs.attachments.list(urlname, @.objectId, @.projectId).then (attachments) =>
            @.attachments = _.sortBy(attachments, "order")
            @.updateCounters()
            return attachments

    updateCounters: ->
        @.attachmentsCount = @.attachments.length
        @.deprecatedAttachmentsCount = _.filter(@.attachments, {is_deprecated: true}).length

    _createAttachment: (attachment) ->
        urlName = "attachments/#{@.type}"

        promise = @rs.attachments.create(urlName, @.projectId, @.objectId, attachment)
        promise = promise.then (data) =>
            data.isCreatedRightNow = true

            index = @.uploadingAttachments.indexOf(attachment)
            @.uploadingAttachments.splice(index, 1)
            @.attachments.push(data)
            @rootscope.$broadcast("attachment:create")

        promise = promise.then null, (data) =>
            @scope.$emit("attachments:size-error") if data.status == 413

            index = @.uploadingAttachments.indexOf(attachment)
            @.uploadingAttachments.splice(index, 1)

            message = @translate.instant("ATTACHMENT.ERROR_UPLOAD_ATTACHMENT", {
                            fileName: attachment.name, errorMessage: data.data._error_message})
            @confirm.notify("error", message)
            return @q.reject(data)

        return promise

    # Create attachments in bulk
    createAttachments: (attachments) ->
        promises = _.map(attachments, (x) => @._createAttachment(x))
        return @q.all(promises).then =>
            @.updateCounters()

    # Add uploading attachment tracking.
    addUploadingAttachments: (attachments) ->
        @.uploadingAttachments = _.union(@.uploadingAttachments, attachments)

    # Change order of attachment in a ordered list.
    # This function is mainly executed after sortable ends.
    reorderAttachment: (attachment, newIndex) ->
        oldIndex = @.attachments.indexOf(attachment)
        return if oldIndex == newIndex

        @.attachments.splice(oldIndex, 1)
        @.attachments.splice(newIndex, 0, attachment)

        _.each(@.attachments, (x,i) -> x.order = i+1)

    # Persist one concrete attachment.
    # This function is mainly used when user clicks
    # to save button for save one unique attachment.
    updateAttachment: (attachment) ->
        onSuccess = =>
            @.updateCounters()
            @rootscope.$broadcast("attachment:edit")

        onError = (response) =>
            $scope.$emit("attachments:size-error") if response.status == 413
            @confirm.notify("error")
            return @q.reject()

        return @repo.save(attachment).then(onSuccess, onError)

    # Persist all pending modifications on attachments.
    # This function is used mainly for persist the order
    # after sorting.
    saveAttachments: ->
        return @repo.saveAll(@.attachments).then null, =>
            for item in @.attachments
                item.revert()
            @.attachments = _.sortBy(@.attachments, "order")

    # Remove one concrete attachment.
    removeAttachment: (attachment) ->
        title = @translate.instant("ATTACHMENT.TITLE_LIGHTBOX_DELETE_ATTACHMENT")
        message = @translate.instant("ATTACHMENT.MSG_LIGHTBOX_DELETE_ATTACHMENT", {fileName: attachment.name})

        return @confirm.askOnDelete(title, message).then (finish) =>
            onSuccess = =>
                finish()
                index = @.attachments.indexOf(attachment)
                @.attachments.splice(index, 1)
                @.updateCounters()
                @rootscope.$broadcast("attachment:delete")

            onError = =>
                finish(false)
                message = @translate.instant("ATTACHMENT.ERROR_DELETE_ATTACHMENT", {errorMessage: message})
                @confirm.notify("error", null, message)
                return @q.reject()

            return @repo.remove(attachment).then(onSuccess, onError)

    # Function used in template for filter visible attachments
    filterAttachments: (item) ->
        if @.showDeprecated
            return true
        return not item.is_deprecated


AttachmentsDirective = ($config, $confirm, $templates, $translate) ->
    template = $templates.get("attachment/attachments.html", true)

    link = ($scope, $el, $attrs, $ctrls) ->
        $ctrl = $ctrls[0]
        $model = $ctrls[1]

        bindOnce $scope, $attrs.ngModel, (value) ->
            $ctrl.initialize($attrs.type, value.id)
            $ctrl.loadAttachments()

        tdom = $el.find("div.attachment-body.sortable")
        tdom.sortable({
            items: "div.single-attachment"
            handle: "a.settings.icon.icon-drag-v"
            containment: ".attachments"
            dropOnEmpty: true
            scroll: false
            tolerance: "pointer"
            placeholder: "sortable-placeholder single-attachment"
        })

        tdom.on "sortstop", (event, ui) ->
            attachment = ui.item.scope().attach
            newIndex = ui.item.index()

            $ctrl.reorderAttachment(attachment, newIndex)
            $ctrl.saveAttachments().then ->
                $scope.$emit("attachment:edit")

        showSizeInfo = ->
            $el.find(".size-info").removeClass("hidden")

        $scope.$on "attachments:size-error", ->
            showSizeInfo()

        $el.on "change", ".attachments-header input", (event) ->
            files = _.toArray(event.target.files)
            return if files.length < 1

            $scope.$apply ->
                $ctrl.addUploadingAttachments(files)
                $ctrl.createAttachments(files)

        $el.on "click", ".more-attachments", (event) ->
            event.preventDefault()
            target = angular.element(event.currentTarget)

            $scope.$apply ->
                $ctrl.showDeprecated = not $ctrl.showDeprecated

            target.find("span.text").addClass("hidden")
            if $ctrl.showDeprecated
                target.find("span[data-type=hide]").removeClass("hidden")
                target.find("more-attachments-num").addClass("hidden")
            else
                target.find("span[data-type=show]").removeClass("hidden")
                target.find("more-attachments-num").removeClass("hidden")

        $scope.$on "$destroy", ->
            $el.off()

    templateFn = ($el, $attrs) ->
        maxFileSize = $config.get("maxUploadFileSize", null)
        maxFileSize = sizeFormat(maxFileSize) if maxFileSize
        maxFileSizeMsg = if maxFileSize then $translate.instant("ATTACHMENT.MAX_UPLOAD_SIZE", {maxFileSize: maxFileSize}) else ""
        ctx = {
            type: $attrs.type
            maxFileSize: maxFileSize
            maxFileSizeMsg: maxFileSizeMsg
        }
        return template(ctx)

    return {
        require: ["tgAttachments", "ngModel"]
        controller: AttachmentsController
        controllerAs: "ctrl"
        restrict: "AE"
        scope: true
        link: link
        template: templateFn
    }

module.directive("tgAttachments", ["$tgConfig", "$tgConfirm", "$tgTemplate", "$translate", AttachmentsDirective])


AttachmentDirective = ($template, $compile, $translate) ->
    template = $template.get("attachment/attachment.html", true)
    templateEdit = $template.get("attachment/attachment-edit.html", true)

    link = ($scope, $el, $attrs, $ctrl) ->
        render = (attachment, edit=false) ->
            permissions = $scope.project.my_permissions
            modifyPermission = permissions.indexOf("modify_#{$ctrl.type}") > -1

            ctx = {
                id: attachment.id
                name: attachment.name
                title : $translate.instant("ATTACHMENT.TITLE", {
                            fileName: attachment.name,
                            date: moment(attachment.created_date).format($translate.instant("ATTACHMENT.DATE"))})
                url: attachment.url
                size: sizeFormat(attachment.size)
                description: attachment.description
                isDeprecated: attachment.is_deprecated
                modifyPermission: modifyPermission
            }

            if edit
                html = $compile(templateEdit(ctx))($scope)
            else
                html = $compile(template(ctx))($scope)

            $el.html(html)

            if attachment.is_deprecated
                $el.addClass("deprecated")
                $el.find("input:checkbox").prop('checked', true)

        saveAttachment = ->
            attachment.description = $el.find("input[name='description']").val()
            attachment.is_deprecated = $el.find("input[name='is-deprecated']").prop("checked")

            $scope.$apply ->
                $ctrl.updateAttachment(attachment).then ->
                    render(attachment, false)

        ## Actions (on edit mode)
        $el.on "click", "a.editable-settings.icon-floppy", (event) ->
            event.preventDefault()
            saveAttachment()

        $el.on "keyup", "input[name=description]", (event) ->
            if event.keyCode == 13
                saveAttachment()
            else if event.keyCode == 27
                render(attachment, false)

        $el.on "click", "a.editable-settings.icon-delete", (event) ->
            event.preventDefault()
            render(attachment, false)

        ## Actions (on view mode)
        $el.on "click", "a.settings.icon-edit", (event) ->
            event.preventDefault()
            render(attachment, true)
            $el.find("input[name='description']").focus().select()

        $el.on "click", "a.settings.icon-delete", (event) ->
            event.preventDefault()
            $scope.$apply ->
                $ctrl.removeAttachment(attachment)

        $scope.$on "$destroy", ->
            $el.off()

        # Bootstrap
        attachment = $scope.$eval($attrs.tgAttachment)
        render(attachment, attachment.isCreatedRightNow)
        if attachment.isCreatedRightNow
            $el.find("input[name='description']").focus().select()

    return {
        link: link
        require: "^tgAttachments"
        restrict: "AE"
    }

module.directive("tgAttachment", ["$tgTemplate", "$compile", "$translate", AttachmentDirective])
