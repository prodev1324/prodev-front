UserTimelineAttachmentDirective = (template, $compile) ->
    validFileExtensions = [".jpg", ".jpeg", ".bmp", ".gif", ".png"]

    isImage = (url) ->
        url = url.toLowerCase()

        return _.some validFileExtensions, (extension) ->
            return url.indexOf(extension, url - extension.length) != -1

    link = (scope, el) ->
        is_image = isImage(scope.attachment.url)

        if is_image
            templateHtml = template.get("user-timeline/user-timeline-attachment/user-timeline-attachment-image.html")
        else
            templateHtml = template.get("user-timeline/user-timeline-attachment/user-timeline-attachment.html")

        el.html(templateHtml)
        $compile(el.contents())(scope)

        el.find("img").error () -> @.remove()

    return {
        link: link
        scope: {
            attachment: "=tgUserTimelineAttachment"
        }
    }

UserTimelineAttachmentDirective.$inject = [
    "$tgTemplate",
    "$compile"
]

angular.module("taigaUserTimeline")
    .directive("tgUserTimelineAttachment", UserTimelineAttachmentDirective)
