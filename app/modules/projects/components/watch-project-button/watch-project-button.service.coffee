taiga = @.taiga

class WatchProjectButtonService extends taiga.Service
    @.$inject = [
        "tgResources",
        "tgCurrentUserService",
        "tgProjectService"
    ]

    constructor: (@rs, @currentUserService, @projectService) ->

    _getProjectIndex: (projectId) ->
        return @currentUserService.projects
                .get('all')
                .findIndex (project) -> project.get('id') == projectId


    _updateProjects: (projectId, notifyLevel, isWatcher) ->
        projectIndex = @._getProjectIndex(projectId)

        projects = @currentUserService.projects
            .get('all')
            .update projectIndex, (project) =>
                totalWatchers = project.get('total_watchers')

                if isWatcher then totalWatchers++ else totalWatchers--

                return project.merge({
                    is_watcher: isWatcher,
                    total_watchers: totalWatchers
                    notify_level: notifyLevel
                })

        @currentUserService.setProjects(projects)

    _updateCurrentProject: (notifyLevel, isWatcher) ->
        totalWatchers = @projectService.project.get("total_watchers")

        if isWatcher then totalWatchers++ else totalWatchers--

        project = @projectService.project.merge({
            is_watcher: isWatcher,
            total_watchers: totalWatchers
            notify_level: notifyLevel
        })

        @projectService.setProject(project)

    watch: (projectId, notifyLevel) ->
        return @rs.projects.watchProject(projectId, notifyLevel).then =>
            @._updateProjects(projectId, notifyLevel, true)
            @._updateCurrentProject(notifyLevel, true)

    unwatch: (projectId) ->
        return @rs.projects.unwatchProject(projectId).then =>
            @._updateProjects(projectId, null, false)
            @._updateCurrentProject(null, false)

angular.module("taigaProjects").service("tgWatchProjectButtonService", WatchProjectButtonService)
