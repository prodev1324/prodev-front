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
# File: components/terms-of-service-and-privacy-policy-notice/terms-of-service-and-privacy-policy-notice.directive.coffee
###


TermsOfServiceAndPrivacyPolicyNoticeDirective = ($config) ->
    link = (scope, el, attrs) ->
        scope.privacyPolicyUrl = $config.get("privacyPolicyUrl")
        scope.termsOfServiceUrl = $config.get("termsOfServiceUrl")
        scope.target = false

        if !scope.privacyPolicyUrl || !scope.termsOfServiceUrl
            scope.target = true

        el.on "change", "input[name='accepted_terms']", (event) ->
            target = angular.element(event.currentTarget)
            scope.target = target.is(":checked")
            scope.$apply()

    return {
        restrict: "AE",
        link: link,
        scope: {
            target: "="
        }
        templateUrl: "components/terms-of-service-and-privacy-policy-notice/terms-of-service-and-privacy-policy-notice.html"
    }

angular.module("taigaComponents")
    .directive("tgTermsOfServiceAndPrivacyPolicyNotice", [
        "$tgConfig",
        TermsOfServiceAndPrivacyPolicyNoticeDirective
    ])
