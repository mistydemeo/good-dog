#!/usr/bin/env ruby

require 'slop'
require 'sequel'
require './lib/coordinates'
require './lib/running_check'

STAY_DATABASE_PATH = File.expand_path '~/Library/Application Support/Stay/Stored Windows.sqlite'

def list_windows
  unless File.exist? STAY_DATABASE_PATH
    puts "Couldn't find a Stay database!"
    exit 1
  end

  warn_if_running

  # TODO:
  # Check for args, accept window ID and workspace ID
  # Copy a config as proof of concept

  Sequel.sqlite STAY_DATABASE_PATH do |db|
    displays = db.from(:ZDISPLAY)
    workspaces = db.from(:ZWORKSPACE)
    applications = db.from(:ZAPPLICATION)
    stored_windows = db.from(:ZSTOREDWINDOW)
    windows = db.from(:ZWINDOW)

    puts "#{workspaces.count} workspaces with #{applications.count} application profiles found"

    workspaces.order(:ZNAME).each do |row|
      workspace_displays = displays.where(:ZWORKSPACE => row[:Z_PK])
      workspace_applications = applications.where(:ZWORKSPACE => row[:Z_PK])
      puts " • “#{row[:ZNAME]}” (Workspace \##{row[:Z_PK]})"

      puts "   Displays (#{workspace_displays.count}):"
      parsed_displays = workspace_displays.map do |display|
        display_position, display_dimensions = parse_coordinates display[:ZDISPLAYBOUNDS]

        puts "   • “#{display[:ZPRODUCTNAME]}”, #{display_dimensions.join '×'} at #{display_position} (Display \##{display[:Z_PK]})"

        display_extents = [
          display_position[0] + display_dimensions[0],
          display_position[1] + display_dimensions[1],
        ]

        {
          display: display,
          parsed_position: display_position,
          parsed_dimensions: display_dimensions,
          parsed_extents: display_extents
        }
      end

      puts "   Applications (#{workspace_applications.count}):"
      workspace_applications.order(:ZNAME).each do |application|
        application_stored_windows = stored_windows.where(:ZAPPLICATION => application[:Z_PK])
        puts "   • “#{application[:ZNAME]}” (#{application_stored_windows.count} windows)"

        application_stored_windows.each do |stored_window|
          window = windows.where(:ZSTOREDWINDOW => stored_window[:Z_PK]).first
          window_position, window_dimensions = parse_coordinates stored_window[:ZFRAMESTRING]

          title = "“#{window[:ZTITLE]}”"
          title = "/#{stored_window[:ZTITLEREGULAREXPRESSION]}/" if stored_window[:ZTITLEREGULAREXPRESSION]
          title = "Any window" if title == '/.*/'

          display_info = nil

          if parsed_displays.count > 1
            parsed_displays.each do |display_data|
              if window_position[0] >= display_data[:parsed_position][0] && window_position[1] >= display_data[:parsed_position][1] && window_position[0] < display_data[:parsed_extents][0] && window_position[1] < display_data[:parsed_extents][1]
                display_info = ", shown on ”#{display_data[:display][:ZPRODUCTNAME]}” (Display \##{display_data[:display][:Z_PK]})"
                break
              end
            end
          end

          puts "     • #{title}, #{window_dimensions.join '×'} at #{window_position} (\##{stored_window[:Z_PK]})#{display_info}"
        end
      end
    end
  end
end

opts = Slop.parse do |o|
  o.on '--list', 'List configurations' do
    list_windows
    exit
  end

  o.on '--help', 'Show usage' do
    puts o
    exit
  end
end

puts opts
