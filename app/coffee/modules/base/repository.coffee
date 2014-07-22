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
# File: modules/base/repository.coffee
###

taiga = @.taiga

class RepositoryService extends taiga.Service
    @.$inject = ["$q", "$tgModel", "$tgStorage", "$tgHttp", "$tgUrls"]

    constructor: (@q, @model, @storage, @http, @urls) ->
        super()

    resolveUrlForModel: (model) ->
        idAttrName = model.getIdAttrName()
        return "#{@urls.resolve(model.getName())}/#{model[idAttrName]}"

    create: (name, data, dataTypes={}, extraParams={}) ->
        defered = @q.defer()
        url = @urls.resolve(name)

        promise = @http.post(url, JSON.stringify(data))
        promise.success (_data, _status) =>
            defered.resolve(@model.make_model(name, _data, null, dataTypes))

        promise.error (data, status) =>
            defered.reject(data)

        return defered.promise

    remove: (model) ->
        defered = @q.defer()
        url = @.resolveUrlForModel(model)

        promise = @http.delete(url)
        promise.success (data, status) ->
            defered.resolve(model)

        promise.error (data, status) ->
            defered.reject(model)

        return defered.promise

    saveAll: (models, patch=true) ->
        promises = _.map(models, (x) => @.save(x, true))
        return @q.all.apply(@q, promises)

    save: (model, patch=true) ->
        defered = @q.defer()

        if not model.isModified() and patch
            defered.resolve(model)
            return defered.promise

        url = @.resolveUrlForModel(model)
        data = JSON.stringify(model.getAttrs(patch))

        if patch
            promise = @http.patch(url, data)
        else
            promise = @http.put(url, data)

        promise.success (data, status) =>
            model._isModified = false
            model._attrs = _.extend(model.getAttrs(), data)
            model._modifiedAttrs = {}

            model.applyCasts()
            defered.resolve(model)

        promise.error (data, status) ->
            defered.reject(data)

        return defered.promise

    refresh: (model) ->
        defered = @q.defer()

        url = @.resolveUrlForModel(model)
        promise = @http.get(url)
        promise.success (data, status) ->
            model._modifiedAttrs = {}
            model._attrs = data
            model._isModified = false
            model.applyCasts()
            defered.resolve(model)

        promise.error (data, status) ->
            defered.reject(data)

        return defered.promise

    queryMany: (name, params, options={}) ->
        url = @urls.resolve(name)
        httpOptions = {headers: {}}
        if not options.enablePagination
            httpOptions.headers["x-disable-pagination"] =  "1"

        return @http.get(url, params, httpOptions).then (data) =>
            return _.map(data.data, (x) => @model.make_model(name, x))

    queryOne: (name, id, params) ->
        url = @urls.resolve(name)
        url = "#{url}/#{id}" if id

        return @http.get(url, params).then (data) =>
            return @model.make_model(name, data.data)

    queryOneRaw: (name, id, params) ->
        url = @urls.resolve(name)
        url = "#{url}/#{id}" if id

        return @http.get(url, params).then (data) =>
            return data.data

    queryPaginated: (name, params) ->
        url = @urls.resolve(name)
        return @http.get(url, params).then (data) =>
            headers = data.headers()
            result = {}
            result.models = _.map(data.data, (x) => @model.make_model(name, x))
            result.count = parseInt(headers["x-pagination-count"], 10)
            result.current = parseInt(headers["x-pagination-current"] or 1, 10)
            result.paginatedBy = parseInt(headers["x-paginated-by"], 10)
            return result

    resolve: (options) ->
        params = {}
        params.project = options.pslug if options.pslug?
        params.us = options.usref if options.usref?
        params.task = options.taskref if options.taskref?
        params.issue = options.issueref if options.issueref?
        params.milestone = options.mlref if options.mlref?
        return @.queryOneRaw("resolver", null, params)


module = angular.module("taigaBase")
module.service("$tgRepo", RepositoryService)
