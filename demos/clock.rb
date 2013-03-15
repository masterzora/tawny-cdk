#!/usr/bin/env ruby
require 'optparse'
require_relative '../lib/cdk'

class Clock
  def Clock.main
    box_label = OptionParser.getopts('b')['b']

    # Set up CDK
    curses_win = Ncurses.initscr
    cdkscreen = CDK::SCREEN.new(curses_win)

    # Set up CDK colors
    CDK::Draw.initCDKColor

    # Set the labels up.
    mesg = [
        '</1/B>HH:MM:SS',
    ]

    # Declare the labels.
    demo = CDK::LABEL.new(cdkscreen, CDK::CENTER, CDK::CENTER,
        mesg, 1, box_label, false)

    # Is the label nil?
    if demo.nil?
      # Clean up the memory.
      cdkscreen.destroy

      # End curses...
      CDK.endCDK

      puts "Cannot create the label. Is the window too small?"
      exit  # EXIT_FAILURE
    end

    Ncurses.curs_set(0)
    demo.screen.window.wtimeout(50)

    # Do this for a while
    begin
      # Get the current time.
      current_time = Time.now.getlocal

      # Put the current time in a string.
      mesg = [
          '<C></B/29>%02d:%02d:%02d' % [
             current_time.hour, current_time.min, current_time.sec]
      ]

      # Set the label contents
      demo.set(mesg, 1, demo.box)

      # Draw the label and sleep
      demo.draw(demo.box)
      Ncurses.napms(500)
    end while (demo.screen.window.wgetch) == Ncurses::ERR

    # Clean up
    demo.destroy
    cdkscreen.destroy
    CDK::SCREEN.endCDK
    #ExitProgram (EXIT_SUCCESS);
  end
end

Clock.main
