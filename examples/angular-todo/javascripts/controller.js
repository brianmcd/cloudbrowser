var todo = angular.module('todo', []);

todo.controller('TodoCtrl', function($scope) {
  $scope.todoList = [];
  $scope.newItem = "";
  $scope.state = 0;
  $scope.plural = "s";
  $scope.remainingCount = 0;
  $scope.$watch('remainingCount', function(newValue, oldValue){
    if(newValue == 1)
      $scope.plural = "";
    else
      $scope.plural = "s";
  });
  var i, countItems = $scope.todoList.length;
  for(i = 0; i < countItems; i++){
    if($scope.todoList[i] == false){
      $scope.remainingCount++;
    }
  }
  $scope.addItem = function(){
    if($scope.newItem == "")
      return;
    else{
      var item = {name:$scope.newItem,done:false};
      $scope.todoList.push(item);
      $scope.newItem = "";
      $scope.remainingCount++;
    }
  };
  $scope.$on("updateCount", function(event, decrement){
    if(decrement){
      $scope.remainingCount--;
    }else{
      $scope.remainingCount++;
    }
  });
});

todo.controller('ItemCtrl', function($scope){
  var item = $scope.todoList[$scope.$index];
  $scope.toggleCompleted = function(){
    item.done = !item.done;
    $scope.$emit("updateCount", item.done);
  };
  $scope.removeItem = function(){
    $scope.todoList.splice($scope.$index, 1); 
    if(!item.done){
      $scope.$emit("updateCount", !item.done);
    }
  }
});
