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

# People Sheet and Columns
def people_sheet
  @people_sheet ||= spreadsheet.worksheet_by_title('People')
end

def people_eventbrite_column
  @people_eventbrite_column ||= (1..people_sheet.num_cols).find { |n| people_sheet[1, n] == 'Eventbrite ID' }
end

def people_name_column
  @people_name_column ||= (1..people_sheet.num_cols).find { |n| people_sheet[1, n] == 'Name' }
end

def people_sleeping_type_column
  @people_sleeping_type_column ||= (1..people_sheet.num_cols).find { |n| people_sheet[1, n] == 'Sleeping Type' }
end

def people_nights_column
  @people_nights_column ||= (1..people_sheet.num_cols).find { |n| people_sheet[1, n] == 'Nights' }
end

def people_shirt_size_column
  @people_shirt_size_column ||= (1..people_sheet.num_cols).find { |n| people_sheet[1, n] == 'T-Shirt Size' }
end

def people_first_empty_row
  (1..people_sheet.num_rows).find { |n| people_sheet[n, people_eventbrite_column] == '' }
end

# Main Loop
eventbrite_attendees.each do |a|
  next if a.cancelled # TODO: remove new cancelations

  # Find existing user
  attendee = (1..people_sheet.num_rows).find { |n| people_sheet[n, people_eventbrite_column] == a.id }

  # Populate eventbrite id if no user found
  unless attendee
    attendee = people_first_empty_row
    people_sheet[attendee, people_eventbrite_column] = a.id
  end

  people_sheet[attendee, people_name_column] = a.profile.name
  people_sheet[attendee, people_sleeping_type_column] = a.ticket_class_name # TODO: group camping
  people_sheet[attendee, people_nights_column] = a.answers[0].answer # TODO: 2/3 instead of arrival day
  people_sheet[attendee, people_shirt_size_column] = a.answers[2].answer
end

people_sheet.save
