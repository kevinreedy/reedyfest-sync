require 'eventbrite'
require 'google_drive'
require 'pry'
require 'dotenv'
Dotenv.load

drive_session = GoogleDrive::Session.from_config('config.json')

def eventbrite_attendees
  # Get all attendees
  Eventbrite.token = ENV['EVENTBRITE_ACCESS_TOKEN']
  attendees = Eventbrite::Attendee.all({ event_id: ENV['EVENTBRITE_EVENT_ID'] })

  all_attendees = attendees.attendees
  while attendees.next?
    attendees = Eventbrite::Attendee.all({ event_id: ENV['EVENTBRITE_EVENT_ID'], page: attendees.next_page })
    all_attendees.concat(attendees.attendees)
  end

  all_attendees
end

def spreadsheet
  drive_session.spreadsheet_by_key(ENV['DRIVE_SPREADSHEET_ID'])
end

def people
  spreadsheet.worksheet_by_title('People')
end

eventbrite_attendees.each do |a|
  next if a.cancelled # TODO: remove new cancelations

  puts a.id
  puts a.profile.name
  puts a.costs.base_price.display
  puts a.answers[0].answer # arrival day
  puts a.ticket_class_name # sleeping type
  puts a.answers[2].answer # shirt size
  puts '----------'
end
