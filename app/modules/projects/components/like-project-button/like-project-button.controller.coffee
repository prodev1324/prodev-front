class LikeProjectButtonController
    @.$inject = [
        "$tgConfirm"
        "tgLikeProjectButtonService"
    ]

    constructor: (@confirm, @likeButtonService)->
        @.isMouseOver = false
        @.loading = false

    showTextWhenMouseIsOver: ->
        @.isMouseOver = true

    showTextWhenMouseIsLeave: ->
        @.isMouseOver = false

    toggleLike: ->
        @.loading = true

        if not @.project.get("is_fan")
            promise = @._like()
        else
            promise = @._unlike()

        promise.finally () => @.loading = false

        return promise

    _like: ->
        return @likeButtonService.like(@.project.get('id'))
            .then =>
                @.showTextWhenMouseIsLeave()
            .catch =>
                @confirm.notify("error")

    _unlike: ->
        return @likeButtonService.unlike(@.project.get('id')).catch =>
            @confirm.notify("error")

angular.module("taigaProjects").controller("LikeProjectButton", LikeProjectButtonController)
