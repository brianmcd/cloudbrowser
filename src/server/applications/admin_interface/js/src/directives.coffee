app = angular.module('CBAdminInterface.directives', [])

app.directive 'cbHasfocus', () ->
    return (scope, element, attrs) ->
        scope.$watch attrs.cbHasfocus, (nVal, oVal) ->
            if (nVal) then element[0].focus()
        element.bind 'blur', () ->
            scope.$apply(
                attrs.cbHasfocus + " = false"
                app = scope.selectedApp
                app.api.setDescription(app.description)
            )
        element.bind 'keydown', (e) ->
            if e.which is 13
                scope.$apply(
                    attrs.cbHasfocus + " = false"
                    app = scope.selectedApp
                    app.api.setDescription(app.description)
                )
