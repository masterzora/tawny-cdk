#!/usr/bin/env ruby
require_relative 'example'

class SwindowExample < CLIExample
  def SwindowExample.parse_opts(opts, params)
    opts.banner = 'Usage: swindow_ex.rb [options]'

    # default values
    params.box = true
    params.shadow = false
    params.x_value = CDK::CENTER
    params.y_value = CDK::CENTER
    params.h_value = 6
    params.w_value = 65

    super(opts, params)
  end

  # Demonstrate a scrolling-window.
  def SwindowExample.main
    title = '<C></5>Error Log'

    # Declare variables.
    params = parse(ARGV)

    # Start curses
    curses_win = Ncurses.initscr
    cdkscreen = CDK::SCREEN.new(curses_win)

    # Start CDK colors.
    CDK::Draw.initCDKColor

    # Create the scrolling window.
    swindow = CDK::SWINDOW.new(cdkscreen, params.x_value, params.y_value,
        params.h_value, params.w_value, title, 100, params.box, params.shadow)

    # Is the window nil.
    if swindow.nil?
      # Exit CDK.
      cdkscreen.destroy
      CDK::SCREEN.endCDK

      puts "Cannot create the scrolling window. Is the window too small?"
      exit  # EXIT_FAILURE
    end

    # Draw the scrolling window.
    swindow.draw(swindow.box)

    # Load up the scrolling window.
    swindow.add('<C></11>TOP: This is the first line.', CDK::BOTTOM)
    swindow.add('<C>Sleeping for 1 second.', CDK::BOTTOM)
    sleep(1)

    swindow.add('<L></11>1: This is another line.', CDK::BOTTOM)
    swindow.add('<C>Sleeping for 1 second', CDK::BOTTOM)
    sleep(1)

    swindow.add('<C></11>2: This is another line.', CDK::BOTTOM)
    swindow.add('<C>Sleeping for 1 second.', CDK::BOTTOM)
    sleep(1)

    swindow.add('<R></11>3: This is another line.', CDK::BOTTOM)
    swindow.add('<C>Sleeping for 1 second', CDK::BOTTOM)
    sleep(1)

    swindow.add('<C></11>4: This is another line.', CDK::BOTTOM)
    swindow.add('<C>Sleeping for 1 second.', CDK::BOTTOM)
    sleep(1)

    swindow.add('<L></11>5: This is another line.', CDK::BOTTOM)
    swindow.add('<C>Sleeping for 1 second', CDK::BOTTOM)
    sleep(1)

    swindow.add('<C></11>6: This is another line.', CDK::BOTTOM)
    swindow.add('<C>Sleeping for 1 second.', CDK::BOTTOM)
    sleep(1)

    swindow.add('<C>Done. You can now play.', CDK::BOTTOM)

    swindow.add('<C>This is being added to the top.', CDK::TOP)

    # Activate the scrolling window.
    swindow.activate([])

    # Check how the user exited this widget.
    if swindow.exit_type == :ESCAPE_HIT
      mesg = [
          '<C>You hit escape to leave this widget.',
          '',
          '<C>Press any key to continue.',
      ]
      cdkscreen.popupLabel(mesg, 3)
    elsif swindow.exit_type == :NORMAL
      mesg = [
          '<C>You hit return to exit this widget.',
          '',
          '<C>Press any key to continue.'
      ]
      cdkscreen.popupLabel(mesg, 3)
    end

    # Clean up.
    swindow.destroy
    cdkscreen.destroy
    CDK::SCREEN.endCDK
    exit # EXIT_SUCCESS
  end
end

SwindowExample.main
