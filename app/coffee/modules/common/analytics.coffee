###
# Copyright (C) 2014-2018 Taiga Agile LLC
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
# File: modules/common/analytics.coffee
###

taiga = @.taiga
module = angular.module("taigaCommon")


class AnalyticsService extends taiga.Service
    @.$inject = ["$rootScope", "$log", "$tgConfig", "$window", "$document", "$location"]

    constructor: (@rootscope, @log, @config, @win, @doc, @location) ->
        @.initialized = false

        conf = @config.get("analytics", {})

        @.accountId = conf.accountId
        @.pageEvent = conf.pageEvent or "$routeChangeSuccess"
        @.trackRoutes = conf.trackRoutes or true
        @.ignoreFirstPageLoad = conf.ignoreFirstPageLoad or false

    initialize: ->
        if not @.accountId
            @log.debug "Analytics: no acount id provided. Disabling."
            return

        @.injectAnalytics()

        @win.ga("create", @.accountId, "auto")
        @win.ga("require", "ec")
        @win.ga("require", "displayfeatures")

        if @.trackRoutes and (not @.ignoreFirstPageLoad)
            @win.ga("send", "pageview", @.getUrl())

        # activates page tracking
        if @.trackRoutes
            @rootscope.$on @.pageEvent, =>
                @.trackPage(@.getUrl(), "Taiga")

        @.initialized = true
        @.setUserId()

    setUserId: ->
        return if not @.initialized
        return if not @win.ga
        @win.ga('set', 'userId', @rootscope?.user?.uuid)

    getUrl: ->
        return @location.path()

    injectAnalytics: ->
        fn = `(function(i,s,o,g,r,a,m){i["GoogleAnalyticsObject"]=r;i[r]=i[r]||function(){
              (i[r].q=i[r].q||[]).push(arguments);},i[r].l=1*new Date();a=s.createElement(o),
              m=s.getElementsByTagName(o)[0];a.async=1;a.src=g;m.parentNode.insertBefore(a,m);})`
        fn(window, document, "script", "//www.google-analytics.com/analytics.js", "ga")

    trackPage: (url, title) ->
        return if not @.initialized
        return if not @win.ga

        title = title or @doc[0].title
        @win.ga("send", "pageview", {
            "page": url,
            "title": title
        })

    trackEvent: (category, action, label, value) ->
        return if not @.initialized
        return if not @win.ga

        @win.ga("send", "event", category, action, label, value)

    ecViewPlan: (plan) ->
        return if not @.initialized
        return if not @win.ga

        @win.ga('ec:addProduct', {
            'id': plan.plan_id,
            'name': plan.name,
            'category': "plans",
            'quantity': 1,
            'position': 1,
        })
        @win.ga('ec:setAction','detail')
        @.trackEvent("ecommerce", "view-product-detail", plan.name, plan.plan_id)

    ecClickPlan: (plan) ->
        return if not @.initialized
        return if not @win.ga

        @win.ga('ec:addProduct', {
            'id': plan.plan_id,
            'name': plan.name,
            'category': "plans",
            'quantity': 1,
            'position': 1,
        })
        @win.ga('ec:setAction','click')
        @.trackEvent("ecommerce", "click-product", plan.name, plan.plan_id)

    ecListPlans: ([plans], page) ->
        return if not @.initialized
        return if not @win.ga

        position = 1
        for plan in plans
            @win.ga('ec:addImpression', {
               'id': plan.plan_id,
               'name': plan.name,
               'list': page,
               'position': position,
            })
            position++
        @.trackEvent("ecommerce", "list-plans")

    ecAddToCart: (plan_id, plan_name, plan_price) ->
        return if not @.initialized
        return if not @win.ga

        @win.ga('ec:addProduct', {
            'id': plan_id,
            'name': plan_name,
            'price': plan_price,
            'category': "plans",
            'quantity': 1,
            'position': 1,
        })
        @win.ga('ec:setAction','add')
        @.trackEvent('ecommerce', 'add-to-cart', 'Collect Payment Info', null)

    ecConfirmChange: (plan_id, plan_name, plan_price) ->
        return if not @.initialized
        return if not @win.ga

        @win.ga('ec:addProduct', {
            'id': plan_id,
            'name': plan_name,
            'price': plan_price,
            'category': "plans",
            'quantity': 1,
            'position': 1,
        })
        @win.ga('ec:setAction','checkout', {'step': 1,})
        @.trackEvent("ecommerce", "start-checkout", "start", 1)

    ecPurchase: (plan_id, plan_name, plan_price) ->
        return if not @.initialized
        return if not @win.ga

        @win.ga('ec:addProduct', {
            'id': plan_id,
            'name': plan_name,
            'price': plan_price,
            'category': "plans",
            'quantity': 1,
            'position': 1,
        })

        @win.ga('ec:setAction','checkout', {'step': 2,})
        @.trackEvent("ecommerce", "end-checkout", "end", 2)

        @win.ga('ec:addProduct', {
            'id': plan_id,
            'name': plan_name,
            'price': plan_price,
            'category': "plans",
            'quantity': 1,
            'position': 1,
        })
        @win.ga('ec:setAction','purchase', {
            'id': plan_id,
            'revenue': plan_price,
        })
        @.trackEvent('ecommerce', 'checkout', 'Plan checkout', null)

module.service("$tgAnalytics", AnalyticsService)
