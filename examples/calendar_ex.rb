#!/usr/bin/env ruby
require './example'

class CalendarExample < Example
  def CalendarExample.parse_opts(opts, param)
    opts.banner = 'Usage: calendar_ex.rb [options]'

    param.x_value = CDK::CENTER
    param.y_value = CDK::CENTER
    param.box = true
    param.shadow = false
    param.day = 0
    param.month = 0
    param.year = 0
    param.week_base = 0
    param.title = "<C></U>CDK Calendar Widget\n<C>Demo"

    super(opts, param)

    opts.on('-d DAY', OptionParser::DecimalInteger, 'Starting day') do |d|
      param.day = d
    end

    opts.on('-m MONTH', OptionParser::DecimalInteger, 'Starting month') do |m|
      param.month = m
    end

    opts.on('-y YEAR', OptionParser::DecimalInteger, 'Starting year') do |y|
      param.year = y
    end

    opts.on('-t TITLE', String, 'Calendar title') do |title|
      param.title = title
    end

    opts.on('-w WEEKBASE', OptionParser::DecimalInteger, 'Week start') do |w|
      param.week_base = w
    end
  end

  # This program demonstrates the Cdk calendar widget.
  def CalendarExample.main
    params = parse(ARGV)

    # Get the current dates and set the default values for the
    # day/month/year values for the calendar.
    date_info = Time.now.gmtime

    if params.day == 0
      params.day = date_info.day
    end

    if params.month == 0
      params.month = date_info.month
    end

    if params.year == 0
      params.year = date_info.year
    end

    # Set up CDK
    curses_win = Ncurses.initscr
    cdkscreen = CDK::SCREEN.new(curses_win)

    # Set up CDK colors
    CDK::Draw.initCDKColor

    # Declare the calendar widget.
    calendar = CDK::CALENDAR.new(cdkscreen, params.x_value, params.y_value,
        params.title, params.day, params.month, params.year,
        Ncurses.COLOR_PAIR(16) | Ncurses::A_BOLD,
        Ncurses.COLOR_PAIR(24) | Ncurses::A_BOLD,
        Ncurses.COLOR_PAIR(32) | Ncurses::A_BOLD,
        Ncurses.COLOR_PAIR(40) | Ncurses::A_REVERSE,
        params.box, params.shadow)

    if calendar.nil?
      # Exit CDK.
      cdkscreen.destroy
      CDK::SCREEN.endCDK
    
      puts 'Cannot create the calendar. Is the window too small?'
      exit  # EXIT_FAILURE
    end

    # This adds a marker ot the calendar.
    create_calendar_mark = lambda do |object_type, calendar, client_data, key|
      calendar.setMarker(calendar.day, calendar.month, calendar.year)
      calendar.draw(calendar.box)
      return false
    end

    # This removes a marker from the calendar.
    remove_calendar_mark = lambda do |object_type, calendar, client_data, key|
      calendar.removeMarker(calendar.day, calendar.month, calendar.year)
      calendar.draw(calendar.box)
      return false
    end

    # Create a key binding to mark days on the calendar.
    calendar.bind(:CALENDAR, 'm', create_calendar_mark, calendar)
    calendar.bind(:CALENDAR, 'M', create_calendar_mark, calendar)
    calendar.bind(:CALENDAR, 'r', remove_calendar_mark, calendar)
    calendar.bind(:CALENDAR, 'R', remove_calendar_mark, calendar)

    calendar.week_base = params.week_base

    # Let the user play with the widget.
    ret_val = calendar.activate([])

    # Check which day they selected.
    if calendar.exit_type == :ESCAPE_HIT
      mesg = [
          '<C>You hit escape. No date selected.',
          '',
          '<C>Press any key to continue.'
      ]
      cdkscreen.popupLabel(mesg, 3)
    elsif calendar.exit_type == :NORMAL
      mesg = [
          'You selected the following date',
          '<C></B/16>%02d/%02d/%d (dd/mm/yyyy)' % [
              calendar.day, calendar.month, calendar.year],
          '<C>Press any key to continue.'
      ]
      cdkscreen.popupLabel(mesg, 3)
    end

    # Clean up
    calendar.destroy
    cdkscreen.destroy
    CDK::SCREEN.endCDK
    $stdout.flush
    puts 'Selected Time: %s' % ret_val.ctime
    #ExitProgram (EXIT_SUCCESS);
  end
end

CalendarExample.main
