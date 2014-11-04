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
# File: modules/base/navurl.coffee
###

taiga = @.taiga
trim = @.taiga.trim
bindOnce = @.taiga.bindOnce

module = angular.module("taigaBase")


#############################################################################
## Navigation Urls Service
#############################################################################

class NavigationUrlsService extends taiga.Service
    constructor: ->
        @.urls = {}

    update: (urls) ->
        @.urls = _.merge({}, @.urls, urls or {})

    formatUrl: (url, ctx={}) ->
        replacer = (match) ->
            match = trim(match, ":")
            return ctx[match] or "undefined"
        return url.replace(/(:\w+)/g, replacer)

    resolve: (name, ctx) ->
        url = @.urls[name]
        return "" if not url
        return @.formatUrl(url, ctx) if ctx
        return url

module.service("$tgNavUrls", NavigationUrlsService)


#############################################################################
## Navigation Urls Directive
#############################################################################

NavigationUrlsDirective = ($navurls, $auth, $q, $location) ->
    # Example:
    # link(tg-nav="project-backlog:project='sss',")

    # bindOnce version that uses $q for offer
    # promise based api
    bindOnceP = ($scope, attr) ->
        defered = $q.defer()
        bindOnce $scope, attr, (v) ->
            defered.resolve(v)
        return defered.promise

    parseNav = (data, $scope) ->
        [name, params] = _.map(data.split(":"), trim)
        if params
            params = _.map(params.split(","), trim)
        else
            params = []
        values = _.map(params, (x) -> trim(x.split("=")[1]))
        promises = _.map(values, (x) -> bindOnceP($scope, x))

        return $q.all(promises).then ->
            options = {}
            for item in params
                [key, value] = _.map(item.split("="), trim)
                options[key] = $scope.$eval(value)
            return [name, options]

    link = ($scope, $el, $attrs) ->
        if $el.is("a")
            $el.attr("href", "#")

        $el.on "mouseenter", (event) ->
            target = $(event.currentTarget)

            if !target.data("fullUrl")
                parseNav($attrs.tgNav, $scope).then (result) ->
                    [name, options] = result
                    user = $auth.getUser()
                    options.user = user.username if user

                    url = $navurls.resolve(name)
                    fullUrl = $navurls.formatUrl(url, options)

                    target.data("fullUrl", fullUrl)

                    if target.is("a")
                        target.attr("href", fullUrl)

        $el.on "click", (event) ->
            event.preventDefault()
            target = $(event.currentTarget)

            if target.hasClass('noclick')
                return

            fullUrl = target.data("fullUrl")

            switch event.which
                when 1
                    $location.url(fullUrl)
                    $scope.$apply()
                when 2
                    window.open fullUrl

        $scope.$on "$destroy", ->
            $el.off()

    return {link: link}

module.directive("tgNav", ["$tgNavUrls", "$tgAuth", "$q", "$tgLocation", NavigationUrlsDirective])
