#
# Support the directive 'focuschange' 
# which sets an ng expression to true/false
# if the focus does not stay in elements
# having this attribute.
#
focusModule = angular.module 'focus', []

focusModule.directive 'focuschange', ($parse, $timeout) ->
  (scope, element, attr) ->
    element.bind 'focus', (event) ->
      scope["_focusgroup_" + attr.focuschange] = true

    element.bind 'blur', (event) ->
      scope["_focusgroup_" + attr.focuschange] = false
      
      $timeout () ->
        if not scope["_focusgroup_" + attr.focuschange]
          scope.$apply attr.focuschange + " = false"
      , 10

#
# Support the directive 'focuson' 
# focus an element if a condition turns true
#
focusModule.directive 'focuson', ($parse, $timeout) ->
  (scope, element, attr) ->
    expr = $parse attr.focuson
    scope.$watch expr, (nVal, oVal) ->
       if nVal != oVal and nVal
         $timeout () ->
           element[0].focus()
           element[0].select()
         , 10

