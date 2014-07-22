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
# File: modules/resources/memberships.coffee
###


taiga = @.taiga

resourceProvider = ($repo) ->
    service = {}

    service.get = (id) ->
        return $repo.queryOne("memberships", id)

    service.list = (projectId, filters) ->
        params = {project: projectId}
        params = _.extend({}, params, filters or {})
        return $repo.queryPaginated("memberships", params)

    return (instance) ->
        instance.memberships = service


module = angular.module("taigaResources")
module.factory("$tgMembershipsResourcesProvider", ["$tgRepo", resourceProvider])
