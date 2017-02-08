require 'eventbrite'
require 'google_drive'
require 'pry'
require 'dotenv'
Dotenv.load

@drive_session = GoogleDrive::Session.from_config('config.json')

def eventbrite_attendees
  # Get all attendees
  Eventbrite.token = ENV['EVENTBRITE_ACCESS_TOKEN']
  attendees = Eventbrite::Attendee.all(event_id: ENV['EVENTBRITE_EVENT_ID'])

  all_attendees = attendees.attendees
  while attendees.next?
    attendees = Eventbrite::Attendee.all(event_id: ENV['EVENTBRITE_EVENT_ID'], page: attendees.next_page)
    all_attendees.concat(attendees.attendees)
  end

  all_attendees
end

def spreadsheet
  @drive_session.spreadsheet_by_key(ENV['DRIVE_SPREADSHEET_ID'])
end

def people_sheet
  @people_sheet ||= spreadsheet.worksheet_by_title('People')
end

def eventbrite_column
  @eventbrite_column ||= (1..people_sheet.num_cols).find { |n| people_sheet[1, n] == 'Eventbrite ID' }
end

def name_column
  @name_column ||= (1..people_sheet.num_cols).find { |n| people_sheet[1, n] == 'Name' }
end

def sleeping_type_column
  @sleeping_type_column ||= (1..people_sheet.num_cols).find { |n| people_sheet[1, n] == 'Sleeping Type' }
end

def nights_column
  @nights_column ||= (1..people_sheet.num_cols).find { |n| people_sheet[1, n] == 'Nights' }
end

def shirt_size_column
  @shirt_size_column ||= (1..people_sheet.num_cols).find { |n| people_sheet[1, n] == 'T-Shirt Size' }
end

def first_empty_eventbrite_row
  (1..people_sheet.num_rows).find { |n| people_sheet[n, eventbrite_column] == '' }
end

eventbrite_attendees.each do |a|
  next if a.cancelled # TODO: remove new cancelations

  # Find existing user
  attendee = (1..people_sheet.num_rows).find { |n| people_sheet[n, eventbrite_column] == a.id }

  # Populate eventbrite id if no user found
  unless attendee
    attendee = first_empty_eventbrite_row
    people_sheet[attendee, eventbrite_column] = a.id
  end

  people_sheet[attendee, name_column] = a.profile.name
  people_sheet[attendee, sleeping_type_column] = a.ticket_class_name # TODO: group camping
  people_sheet[attendee, nights_column] = a.answers[0].answer # TODO: 2/3 instead of arrival day
  people_sheet[attendee, shirt_size_column] = a.answers[2].answer
end

people_sheet.save
