PaginateResponse = () ->
    return (result) ->
        paginateResponse = Immutable.Map({
            "data": result.get("data"),
            "next": !!result.get("headers")("x-pagination-next"),
            "prev": !!result.get("headers")("x-pagination-prev"),
            "current": result.get("headers")("x-pagination-current"),
            "count": result.get("headers")("x-pagination-count")
        })

        return paginateResponse

angular.module("taigaCommon").factory("tgPaginateResponseService", PaginateResponse)
