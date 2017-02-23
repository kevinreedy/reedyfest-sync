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

# Money Sheet and Columns
def money_sheet
  @money_sheet ||= spreadsheet.worksheet_by_title('Money')
end

def money_date_column
  @money_date_column ||= (1..money_sheet.num_cols).find { |n| money_sheet[1, n] == 'Date' }
end

def money_entity_column
  @money_entity_column ||= (1..money_sheet.num_cols).find { |n| money_sheet[1, n] == 'Entity' }
end

def money_amount_column
  @money_amount_column ||= (1..money_sheet.num_cols).find { |n| money_sheet[1, n] == 'Amount' }
end

def money_payment_type_column
  @money_payment_type_column ||= (1..money_sheet.num_cols).find { |n| money_sheet[1, n] == 'Payment Type' }
end

def money_eventbrite_column
  @money_eventbrite_column ||= (1..money_sheet.num_cols).find { |n| money_sheet[1, n] == 'Eventbrite ID' }
end

def money_first_empty_row
  (1..money_sheet.num_rows).find { |n| money_sheet[n, money_date_column] == '' }
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
  people_sheet[attendee, people_shirt_size_column] = a.answers[2].answer

  if a.ticket_class_name == 'Camping Thursday - Sunday' || a.ticket_class_name == 'Camping Friday - Sunday'
    people_sheet[attendee, people_sleeping_type_column] = 'Camping'
  else
    people_sheet[attendee, people_sleeping_type_column] = a.ticket_class_name.sub(/^Cabin - /, '')
  end

  if a.answers[0].answer == 'Thursday'
    people_sheet[attendee, people_nights_column] = '3'
  elsif a.answers[0].answer == 'Friday'
    people_sheet[attendee, people_nights_column] = '2'
  else
    people_sheet[attendee, people_nights_column] = '?'
  end

  # Add Payments
  next if a.costs.base_price.value == 0

  # Find existing payment
  payment = (1..money_sheet.num_rows).find { |n| money_sheet[n, money_eventbrite_column] == a.id }

  unless payment
    payment = money_first_empty_row
    money_sheet[payment, money_eventbrite_column] = a.id
  end

  money_sheet[payment, money_date_column] = DateTime.strptime(a.created).to_date.iso8601
  money_sheet[payment, money_entity_column] = a.profile.name
  money_sheet[payment, money_amount_column] = a.costs.base_price.major_value
  money_sheet[payment, money_payment_type_column] = "Eventbrite"
end

people_sheet.save
money_sheet.save
