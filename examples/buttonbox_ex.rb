#!/usr/bin/env ruby
require './example'

class ButtonboxExample < Example
  # This program demonstrates the Cdk buttonbox widget.
  def ButtonboxExample.main
    buttons = [" OK ", " Cancel "]

    # Set up CDK.
    curses_win = Ncurses.initscr
    cdkscreen = CDK::SCREEN.new(curses_win)

    # Start color.
    CDK::Draw.initCDKColor

    # Create the entry widget.
    entry = CDK::ENTRY.new(cdkscreen, CDK::CENTER, CDK::CENTER,
        "<C>Enter a name", "Name ", Ncurses::A_NORMAL, '.', :MIXED,
        40, 0, 256, true, false)

    if entry.nil?
      cdkscreen.destroy
      CDK::SCREEN.endCDK

      $stderr.puts "Cannot create entry-widget"
      exit # EXIT_FAILURE
    end

    # Create the button box widget.
    button_widget = CDK::BUTTONBOX.new(cdkscreen,
        entry.win.getbegx, entry.win.getbegy + entry.box_height - 1,
        1, entry.box_width - 1, '', 1, 2, buttons, 2, Ncurses::A_REVERSE,
        true, false)

    if button_widget.nil?
      cdkscreen.destroy
      CDK::SCREEN.endCDK

      $stderr.puts "Cannot create buttonbox-widget"
      exit # EXIT_FAILURE
    end

    # Set the lower left and right characters of the box.
    entry.setLLchar(Ncurses::ACS_LTEE)
    entry.setLRchar(Ncurses::ACS_RTEE)
    button_widget.setULchar(Ncurses::ACS_LTEE)
    button_widget.setURchar(Ncurses::ACS_RTEE)

    # Bind the Tab key in the entry field to send a
    # Tab key to the button box widget.
    entryCB = lambda do |cdktype, object, client_data, key|
      client_data.inject(key)
      return true
    end

    entry.bind(:ENTRY, CDK::KEY_TAB, entryCB, button_widget)
    
    # Activate the entry field.
    button_widget.draw(true)
    info = entry.activate('')
    selection = button_widget.current_button

    # Clean up.
    button_widget.destroy
    entry.destroy
    cdkscreen.destroy
    CDK::SCREEN.endCDK

    puts "You typed in (%s) and selected button (%s)" % [
        if !(info.nil?) && info.size > 0 then info else '<null>' end,
        buttons[selection]
    ]
    exit # EXIT_SUCCESS
  end
end

ButtonboxExample.main
