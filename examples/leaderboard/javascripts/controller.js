var leaderboard = angular.module('leaderboard', []);

leaderboard.controller('LeaderboardCtrl', function($scope) {
  $scope.contestants = [];
  $scope.addState = false;
  $scope.newContestant = "";
  $scope.selected=null;
  $scope.toggleAddForm = function(){
    $scope.addState = !$scope.addState;
  };
  $scope.addContestant = function(){
    var contestant = {name:$scope.newContestant,score:0};
    $scope.contestants.push(contestant);
    $scope.newContestant = "";
    console.log($scope.contestants);
  }
  $scope.$on('select', function(event, contestant){
    $scope.selected = contestant;
  });
  $scope.addPoints = function(){
    $scope.selected.score++;
  }
  $scope.dockPoints = function(){
    if($scope.selected.score != 0)
      $scope.selected.score--;
  }
});

leaderboard.controller('ContestantCtrl', function($scope){
  var contestant = $scope.contestants[$scope.$index];
  //This is wrong, change it
  $scope.removeContestant = function(){
    $scope.contestants.splice($scope.$index, 1);
  }
  $scope.select = function(){
    $scope.$emit('select', contestant);
  }
});
