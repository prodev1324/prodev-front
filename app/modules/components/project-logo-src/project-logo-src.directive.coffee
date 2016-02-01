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
# File: project-logo.directive.coffee
###


IMAGES = [
    "/#{window._version}/images/project-logos/project-logo-01.png"
    "/#{window._version}/images/project-logos/project-logo-02.png"
    "/#{window._version}/images/project-logos/project-logo-03.png"
    "/#{window._version}/images/project-logos/project-logo-04.png"
    "/#{window._version}/images/project-logos/project-logo-05.png"
]

COLORS = [
    "rgba( 153,  214, 220, 1 )"
    "rgba( 213,  156,  156, 1 )"
    "rgba( 214, 161, 212,  1 )"
    "rgba( 164, 162, 219, 1 )"
    "rgba( 152, 224, 168,  1 )"
]

LOGOS = _.cartesianProduct(IMAGES, COLORS)


ProjectLogoSrcDirective = ($parse) ->
    _getDefaultProjectLogo = (project) ->
        key = "#{project.get("slug")}-#{project.get("id")}"
        idx = murmurhash3_32_gc(key, 42) %% LOGOS.length
        logo = LOGOS[idx]

        return { src: logo[0], color: logo[1] }

    link = (scope, el, attrs) ->
        scope.$watch "project", (project) ->
            project = Immutable.fromJS(project) # Necesary for old code

            return if not project

            projectLogo = project.get('logo_big_url')

            if projectLogo
                el.attr("src", projectLogo)
                el.css('background', "")
            else
                logo = _getDefaultProjectLogo(project)
                el.attr("src", logo.src)
                el.css('background', logo.color)

        scope.$on "$destroy", -> el.off()

    return {
        link: link
        scope: {
             project: "=tgProjectLogoSrc"
        }
    }

ProjectLogoSrcDirective.$inject = [
    "$parse"
]

angular.module("taigaComponents").directive("tgProjectLogoSrc", ProjectLogoSrcDirective)
