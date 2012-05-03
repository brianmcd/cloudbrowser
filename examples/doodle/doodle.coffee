{EventEmitter} = require('events')

class Participant extends EventEmitter
  constructor: (name, editing) ->
    @name = ko.observable(name)
    @email = ko.observable('none')
    @editing = ko.observable(editing)
    @available = ko.observableArray()
    for i in [0..appModel.times().length - 1]
      do (i) =>
        toggle = ko.observable(false)
        toggle.subscribe((value) => @emit('change', i, value))
        @available.push({avail: toggle})

class Time
  constructor:  (@start, @duration) ->
  getMonth: () => moment(@start).format('MMMM')
  getDay: () => moment(@start).format('ddd DD')
  getTimeRange: () =>
    moment(@start).format('h:mma') + ' - ' +
    moment(@start+@duration).format('h:mma')
  toString: => str = "#{@getMonth()} #{@getDay()} #{@getTimeRange()}"

findAvailableTimes = (i, isAvailable) ->
  time = appModel.times()[i]
  return appModel.possibleTimes.remove(time) if !isAvailable
  for p in appModel.participants()
    return if !p.available()[i].avail()
  appModel.possibleTimes.push(time)
  appModel.possibleTimes.sort (a, b) -> a.start - b.start

appModel =
  times: ko.observableArray([
    new Time(1334678400000, 7200000)
    new Time(1334754900000, 7200000)
    new Time(1334774700000, 7200000)
    new Time(1334927700000, 7200000)
    new Time(1334904300000, 7200000)
  ])
  possibleTimes: ko.observableArray()
  participants:  ko.observableArray()
  addParticipant: () ->
    participant = new Participant('New Participant', true)
    participant.on('change', findAvailableTimes)
    appModel.participants.push(participant)
    appModel.possibleTimes([])
    participant.available.subscribe(findAvailableTimes)
  removeParticipant : (participant) ->
    appModel.participants.remove(participant)

appModel.addParticipant()
ko.applyBindings(appModel)

FS = require('fs')
nodemailer = require('nodemailer')

smtp = nodemailer.createTransport 'SMTP',
  service: 'Gmail'
  auth:
    user: 'cloudbrowserframework@gmail.com'
    pass: FS.readFileSync('emailpass.txt', 'utf8')

$('#send-mail').click () ->
  $('#send-mail').attr('disabled', 'disabled')
  for p in appModel.participants()
    addr = p.email()
    return if addr == 'none'
    msg = "Hey #{p.name()}, here are the available times:\n"
    msg += "\t#{time}\n" for time in appModel.possibleTimes()
    mail =
      from: "CloudBrowser <cloudbrowserframework@gmail.com>"
      to: addr
      subject: "Available Meeting Times"
      text: msg
    smtp.sendMail(mail)
  $('#send-mail').removeAttr('disabled')

