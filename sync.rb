require 'eventbrite'
require 'google_drive'
require 'pry'
require 'dotenv'
Dotenv.load

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

eventbrite_attendees.each do |a|
  next if a.cancelled
  puts a.profile.name
end
