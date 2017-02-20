###
# Copyright (C) 2014-2016 Taiga Agile LLC <taiga@taiga.io>
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
# File: import-project.controller.coffee
###

class ImportProjectController
    @.$inject = [
        'tgTrelloImportService',
        'tgJiraImportService',
        'tgGithubImportService',
        'tgAsanaImportService',
        '$location',
        '$window',
        '$routeParams',
        '$tgNavUrls',
        '$tgConfig',
    ]

    constructor: (@trelloService, @jiraService, @githubService, @asanaService, @location, @window, @routeParams, @tgNavUrls, @config) ->

    start: ->
        @.token = null
        @.from = @routeParams.platform

        locationSearch = @location.search()

        if @.from == "asana"
            asanaOauthToken = locationSearch.code
            if locationSearch.code
                asanaOauthToken = locationSearch.code

                return @asanaService.authorize(asanaOauthToken).then ((token) =>
                    @location.search({token: encodeURIComponent(JSON.stringify(token))})
                ), @.cancelCurrentImport.bind(this)
            else
                @.token = JSON.parse(decodeURIComponent(locationSearch.token))
                @asanaService.setToken(@.token)

        if @.from  == 'trello'
            if locationSearch.oauth_verifier
                trelloOauthToken = locationSearch.oauth_verifier
                return @trelloService.authorize(trelloOauthToken).then ((token) =>
                    @location.search({token: token})
                ), @.cancelCurrentImport.bind(this)
            else if locationSearch.token
                @.token = locationSearch.token
                @trelloService.setToken(locationSearch.token)

        if @.from == "github"
            if locationSearch.code
                githubOauthToken = locationSearch.code

                return @githubService.authorize(githubOauthToken).then ((token) =>
                    @location.search({token: token})
                ), @.cancelCurrentImport.bind(this)
            else if locationSearch.token
                @.token = locationSearch.token
                @githubService.setToken(locationSearch.token)

        if @.from == "jira"
            jiraOauthToken = locationSearch.oauth_token

            if jiraOauthToken
                return @jiraService.authorize().then ((data) =>
                    @location.search({token: data.token, url: data.url})
                ), @.cancelCurrentImport.bind(this)
            else
                @.token = locationSearch.token
                @jiraService.setToken(locationSearch.token, locationSearch.url)

    select: (from) ->
        if from == "trello"
            @trelloService.getAuthUrl().then (url) =>
                @window.open(url, "_self")
        else if from == "jira"
            @jiraService.getAuthUrl(@.jiraUrl).then (url) =>
                @window.open(url, "_self")
        else if from == "github"
            callbackUri = @location.absUrl() + "/github"
            @githubService.getAuthUrl(callbackUri).then (url) =>
                @window.open(url, "_self")
        else if from == "asana"
            @asanaService.getAuthUrl().then (url) =>
                @window.open(url, "_self")
        else
            @.from = from

    unfoldOptions: (options) ->
        @.unfoldedOptions = options

    isActiveImporter: (importer) ->
        if @config.get('importers').indexOf(importer) == -1
            return false
        return true

    cancelCurrentImport: () ->
        @location.url(@tgNavUrls.resolve('create-project-import'))

angular.module("taigaProjects").controller("ImportProjectCtrl", ImportProjectController)
