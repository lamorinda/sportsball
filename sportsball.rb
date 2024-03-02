require 'sinatra'
require 'csv'
require 'icalendar'
require 'http'
require 'base64'

before do
  # Fetch and save the CSV data
  url = "https://docs.google.com/spreadsheets/d/1tDTAHYOe-hjks_0zYVs9f9lgJbYBU3Vj4a3DQ6kYZVc/export?format=csv&id=1tDTAHYOe-hjks_0zYVs9f9lgJbYBU3Vj4a3DQ6kYZVc&gid=156180468"
  response = HTTP.follow.get(url)
  CSV_FILE_PATH = './games.csv'
  File.write(CSV_FILE_PATH, response.to_s)
end

get '/' do
  # Parse the CSV to get divisions and teams
  @divisions_teams = parse_divisions_and_teams(CSV_FILE_PATH)
  erb :index
end

get '/:division/:team' do |division, team|
  division = Base64.urlsafe_decode64(division)
  team = Base64.urlsafe_decode64(team)

  filtered_games = filter_games(CSV_FILE_PATH, division, team)
  ics_content = generate_ics(filtered_games)
  content_type 'text/calendar'
  ics_content
end

def parse_divisions_and_teams(csv_file_path)
  divisions_teams = {}
  CSV.foreach(csv_file_path, headers: true) do |row|
    division = row['Division'].strip
    teams = row['Teams'].split('v').map(&:strip)
    divisions_teams[division] ||= []
    divisions_teams[division].concat(teams)
  end
  divisions_teams.each { |division, teams| divisions_teams[division] = teams.uniq.sort }
  divisions_teams
end

def filter_games(csv_file_path, division, team)
  games = []
  CSV.foreach(csv_file_path, headers: true) do |row|
    if row['Division'].strip.downcase == division.downcase && row['Teams'].include?(team)
      games << row
    end
  end
  games
end

def generate_ics(games)
  cal = Icalendar::Calendar.new
  games.each do |game|
    cal.event do |e|
      e.dtstart     = Icalendar::Values::DateTime.new(DateTime.parse("#{game['Date']} #{game['Time']}"))
      e.dtend       = Icalendar::Values::DateTime.new(DateTime.parse("#{game['Date']} #{game['Time']}") + Rational(1, 24))
      e.summary     = "Game: #{game['Teams']}"
      e.description = "Location: #{game['Location']} at #{game['Site']}"
    end
  end
  cal.to_ical
end

__END__

@@ index
<!DOCTYPE html>
<html>
<head>
  <title>Sports Schedule</title>
  <!-- Centered viewport -->
  <link
    rel="stylesheet"
    href="https://cdn.jsdelivr.net/npm/@picocss/pico@2/css/pico.classless.min.css"
  />
</head>
<body>
  <header>
    <hgroup>
      <h1>Sports Schedule</h1>
      <h2>Find your team and divsion below to add to your calendar</h2>
    </hgroup>
  </header>
  <main>
    <% @divisions_teams.each do |division, teams| %>
      <h3><%= division %></h3>
      <% teams.each do |team| %>
        <p><a href="/<%= Base64.urlsafe_encode64(division) %>/<%= Base64.urlsafe_encode64(team) %>">Team <%= team %></a></p>
      <% end %>
    <% end %>
  </main>
  <footer>
    <p>
      This script was made in haste. Fix bugs and/or contributes <a href="https://github.com/lamorinda/sportsball">on Github</a>.
    </p>
  </footer>
</body>
</html>
