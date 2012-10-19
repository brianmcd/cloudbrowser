class Participant
  constructor: (@name, times, @email = 'none', @editing = false) ->
    @available = { }
    for start, time of times
      @available[start] = avail:false

  addTimeSlot: (time) ->
    @available[time.start] = avail:false if time.start not in @available

class TimeSlot
  constructor:  (@start, @end) ->

  toString: =>
      start = moment(@start).format('MMMM ddd DD h:mma')
      end = moment(@end).format('h:mma')
      "#{start} - #{end}"

appModel =
  times:  {}
  addTimeSlot: () ->
      maxTime = Math.max.apply @, (time.start for start, time of @times)
      nextSlot = new TimeSlot(maxTime + 24*60*60*1000, maxTime + 26*60*60*1000)
      @times[nextSlot.start] = nextSlot
      for p in @participants
          p.addTimeSlot nextSlot

  possibleTimes: () ->
    (@times[time] for time of @times).filter (time) =>
      @participants.reduce (v, p) ->
        v && p.available[time.start]?.avail
      , true

  participants:  []
  addParticipant: () ->
    @participants.push new Participant('New Participant', @times)

  removeParticipant: (pt) ->
    @participants.splice (@participants.indexOf pt), 1

for time in (1000*stime for stime in [1347897600, 1347940800, 1348070400])
  appModel.times[time] = new TimeSlot(time, time + 2*60*60*1000)

appModel.addParticipant()

angular.module('doodleApp', ['focus']).controller 'doodleController', ($scope) ->
    $scope.model = appModel
