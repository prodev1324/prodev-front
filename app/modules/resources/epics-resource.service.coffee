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
# File: epics-resource.service.coffee
###

Resource = (urlsService, http) ->
    service = {}

    service.listAll = (params) ->
        url = urlsService.resolve("epics")

        httpOptions = {}

        return http.get(url, params, httpOptions).then (result) ->
            return Immutable.fromJS(result.data)

    service.list = (projectId) ->
        url = urlsService.resolve("epics")

        params = {project: projectId}

        return http.get(url, params)
            .then (result) -> Immutable.fromJS(result.data)

    service.patch = (id, patch) ->
        url = urlsService.resolve("epics") + "/#{id}"

        return http.patch(url, patch)

    return () ->
        return {"epics": service}

Resource.$inject = ["$tgUrls", "$tgHttp"]

module = angular.module("taigaResources2")
module.factory("tgEpicsResource", Resource)
