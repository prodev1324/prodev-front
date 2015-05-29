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
# File: modules/profile/profile-timeline/profile-timeline.controller.coffee
###

taiga = @.taiga

mixOf = @.taiga.mixOf

class UserTimelineController extends mixOf(taiga.Controller, taiga.PageMixin, taiga.FiltersMixin)
    @.$inject = [
        "tgUserTimelineService"
    ]

    constructor: (@userTimelineService) ->
        @.timelineList = Immutable.List()
        @.page = 1
        @.loadingData = false

    loadTimeline: () ->
        @.loadingData = true

        if @.projectId
            @userTimelineService
                .getProjectTimeline(@.projectId, @.page)
                .then (newTimelineList) =>
                    @._timelineLoaded(newTimelineList)
        else
            @userTimelineService
                .getTimeline(@.userId, @.page)
                .then (newTimelineList) =>
                    @._timelineLoaded(newTimelineList)

    _timelineLoaded: (newTimelineList) ->
        @.timelineList = @.timelineList.concat(newTimelineList)
        @.page++
        @.loadingData = false

angular.module("taigaUserTimeline")
    .controller("UserTimeline", UserTimelineController)
