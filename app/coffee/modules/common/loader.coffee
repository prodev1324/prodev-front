taiga = @.taiga
sizeFormat = @.taiga.sizeFormat

module = angular.module("taigaCommon")

LoaderDirective = (tgLoader, $rootscope) ->
    link = ($scope, $el, $attrs) ->
        tgLoader.onStart () ->
            $(document.body).addClass("loader-active")
            $el.addClass("active")

        tgLoader.onEnd () ->
            $(document.body).removeClass("loader-active")
            $el.removeClass("active")

        $rootscope.$on "$routeChangeSuccess", (e) ->
            tgLoader.start()

        $rootscope.$on "$locationChangeSuccess", (e) ->
            tgLoader.reset()

    return {
        link: link
    }

module.directive("tgLoader", ["tgLoader", "$rootScope", LoaderDirective])

Loader = () ->
    forceDisabled = false

    defaultLog = {
        request: {
            count: 0,
            time: 0
        }
        response: {
            count: 0,
            time: 0
        }
    }

    defaultConfig = {
        enabled: false,
        minTime: 1000,
        auto: false
    }

    log = _.merge({}, defaultLog)
    config = _.merge({}, defaultConfig)

    reset = () ->
        log = _.merge({}, defaultLog)
        config = _.merge({}, defaultConfig)

    @.add = (auto = false) ->
        return () ->
            if !forceDisabled
                config.auto = auto
                config.enabled = true

    @.$get = ["$rootScope", ($rootscope) ->
        interval = null
        startLoadTime = 0

        return {
            reset: () ->
                reset()

            pageLoaded: () ->
                reset()

                endTime = new Date().getTime()
                diff = endTime - startLoadTime

                if diff < config.minTime
                    timeout = config.minTime - diff
                else
                    timeout = 0

                setTimeout ( ->
                    $rootscope.$broadcast("loader:end");
                ), timeout

            start: () ->
                if config.enabled
                    if config.auto
                        interval = setInterval ( ->
                            currentDate = new Date().getTime()

                            if log.request.count == log.response.count && currentDate - log.response.time  > 200
                                clearInterval(interval)
                                pageLoaded()

                        ), 100

                    startLoadTime = new Date().getTime()
                    $rootscope.$broadcast("loader:start");

            onStart: (fn) ->
                $rootscope.$on("loader:start", fn);

            onEnd: (fn) ->
                $rootscope.$on("loader:end", fn);

            logRequest: () ->
                log.request.count++
                log.request.time = new Date().getTime()

            logResponse: () ->
                log.response.count++
                log.response.time = new Date().getTime()

            preventLoading: () ->
                forceDisabled = true

            disablePreventLoading: () ->
                forceDisabled = false
        }
    ]

    return

module.provider("tgLoader", [Loader])

loaderInterceptor = (tgLoader) ->
    return {
        request: (config) ->
            tgLoader.logRequest()

            return config
        response: (response) ->
            tgLoader.logResponse()

            return response
    }

module.factory('loaderInterceptor', ['tgLoader', loaderInterceptor])
