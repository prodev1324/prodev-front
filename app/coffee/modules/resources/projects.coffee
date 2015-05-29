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
# File: modules/resources/projects.coffee
###


taiga = @.taiga
sizeFormat = @.taiga.sizeFormat


resourceProvider = ($config, $repo, $http, $urls, $auth, $q, $translate) ->
    service = {}

    service.get = (projectId) ->
        return $repo.queryOne("projects", projectId)

    service.getBySlug = (projectSlug) ->
        return $repo.queryOne("projects", "by_slug?slug=#{projectSlug}")

    service.list = ->
        return $repo.queryMany("projects")

    service.listByMember = (memberId) ->
        params = {"member": memberId, "order_by": "memberships__user_order"}
        return $repo.queryMany("projects", params)

    service.templates = ->
        return $repo.queryMany("project-templates")

    service.usersList = (projectId) ->
        params = {"project": projectId}
        return $repo.queryMany("users", params)

    service.rolesList = (projectId) ->
        params = {"project": projectId}
        return $repo.queryMany("roles", params)

    service.stats = (projectId) ->
        return $repo.queryOneRaw("projects", "#{projectId}/stats")

    service.bulkUpdateOrder = (bulkData) ->
        url = $urls.resolve("bulk-update-projects-order")
        return $http.post(url, bulkData)

    service.regenerate_userstories_csv_uuid = (projectId) ->
        url = "#{$urls.resolve("projects")}/#{projectId}/regenerate_userstories_csv_uuid"
        return $http.post(url)

    service.regenerate_issues_csv_uuid = (projectId) ->
        url = "#{$urls.resolve("projects")}/#{projectId}/regenerate_issues_csv_uuid"
        return $http.post(url)

    service.regenerate_tasks_csv_uuid = (projectId) ->
        url = "#{$urls.resolve("projects")}/#{projectId}/regenerate_tasks_csv_uuid"
        return $http.post(url)

    service.leave = (projectId) ->
        url = "#{$urls.resolve("projects")}/#{projectId}/leave"
        return $http.post(url)

    service.memberStats = (projectId) ->
        return $repo.queryOneRaw("projects", "#{projectId}/member_stats")

    service.tagsColors = (projectId) ->
        return $repo.queryOne("projects", "#{projectId}/tags_colors")

    service.export = (projectId) ->
        url = "#{$urls.resolve("exporter")}/#{projectId}"
        return $http.get(url)

    service.import = (file, statusUpdater) ->
        defered = $q.defer()

        maxFileSize = $config.get("maxUploadFileSize", null)
        if maxFileSize and file.size > maxFileSize
            errorMsg = $translate.instant("PROJECT.IMPORT.ERROR_MAX_SIZE_EXCEEDED", {
                fileName: file.name
                fileSize: sizeFormat(file.size)
                maxFileSize: sizeFormat(maxFileSize)
            })

            response = {
                status: 413,
                data: _error_message: errorMsg
            }
            defered.reject(response)
            return defered.promise

        uploadProgress = (evt) =>
            percent = Math.round((evt.loaded / evt.total) * 100)
            message = $translate.instant("PROJECT.IMPORT.UPLOAD_IN_PROGRESS_MESSAGE", {
                uploadedSize: sizeFormat(evt.loaded)
                totalSize: sizeFormat(evt.total)
            })
            statusUpdater("in-progress", null, message, percent)

        uploadComplete = (evt) =>
            statusUpdater("done",
                          $translate.instant("PROJECT.IMPORT.TITLE"),
                          $translate.instant("PROJECT.IMPORT.DESCRIPTION"))

        uploadFailed = (evt) =>
            statusUpdater("error")

        complete = (evt) =>
            response = {}
            try
                response.data = JSON.parse(evt.target.responseText)
            catch
                response.data = {}
            response.status = evt.target.status

            defered.resolve(response) if response.status in [201, 202]
            defered.reject(response)

        failed = (evt) =>
            defered.reject("fail")

        data = new FormData()
        data.append('dump', file)

        xhr = new XMLHttpRequest()
        xhr.upload.addEventListener("progress", uploadProgress, false)
        xhr.upload.addEventListener("load", uploadComplete, false)
        xhr.upload.addEventListener("error", uploadFailed, false)
        xhr.upload.addEventListener("abort", uploadFailed, false)
        xhr.addEventListener("load", complete, false)
        xhr.addEventListener("error", failed, false)

        xhr.open("POST", $urls.resolve("importer"))
        xhr.setRequestHeader("Authorization", "Bearer #{$auth.getToken()}")
        xhr.setRequestHeader('Accept', 'application/json')
        xhr.send(data)

        return defered.promise

    return (instance) ->
        instance.projects = service


module = angular.module("taigaResources")
module.factory("$tgProjectsResourcesProvider", ["$tgConfig", "$tgRepo", "$tgHttp", "$tgUrls", "$tgAuth",
                                                "$q", "$translate", resourceProvider])
