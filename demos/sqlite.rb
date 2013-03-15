#!/usr/bin/env ruby
require 'optparse'
require 'ostruct'
require 'sqlite3'
require_relative '../lib/cdk'

class SQLiteDemo
  MAXWIDTH = 5000
  MAXHISTORY = 1000
  GPUsage = '[-p Command Prompt] [-f databasefile] [-h help]'
  @@gp_current_database = ''
  @@gp_cdk_screen = nil

  # This saves the history into RC file.
  def SQLiteDemo.saveHistory(history, count)
    if (home = ENV['HOME']).nil?
      home = '.'
    end
    filename = '%s/.tawnysqlite.rc' % [home]

    # Open the file for writing.
    begin
      fd = File.open(filename, 'w')
    rescue
      return
    end

    # Start saving the history.
    history.cmd_history.each do |cmd|
      fd.puts cmd
    end

    fd.close
  end

  # This loads the history into the editor from the RC file.
  def SQLiteDemo.loadHistory(history)
    home = ''
    filename = ''

    # Create the RC filename.
    if (home = ENV['HOME']).nil?
      home = '.'
    end
    filename = '%s/.tawnysqlite.rc' % [home]

    # Set some variables.
    history.current = 0

    # Read the file.
    if (history.count = CDK.readFile(filename, history.cmd_history)) != -1
      history.current = history.count
    end
  end

  # This displays a little introduction screen.
  def SQLiteDemo.intro(screen)
    # Create the message.
    mesg = [
        '',
        '<C></B/16>SQLite Command Interface',
        '<C>Written By Chris Sauro',
        '',
        '<C>Type </B>help<!B> to get help.',
    ]
    
    # Display the message.
    screen.popupLabel(mesg, mesg.size)
  end

  def SQLiteDemo.help(entry)
    # Create the help message.
    mesg = [
        '<C></B/29>Help',
        '',
        '</B/24>When in the command line.',
        '<B=Up Arrow  > Scrolls back one command.',
        '<B=Down Arrow> Scrolls forward one command.',
        '<B=Tab       > Activates the scrolling window.',
        '<B=help      > Displays this help window.',
        '',
        '</B/24>When in the scrolling window.',
        '<B=l or L    > Loads a file into the window.',
        '<B=s or S    > Saves the contents of the window to a file.',
        '<B=Up Arrow  > Scrolls up one line.',
        '<B=Down Arrow> Scrolls down one line.',
        '<B=Page Up   > Scrolls back one page.',
        '<B=Page Down > Scrolls forward one page.',
        '<B=Tab or Esc> Returns to the command line.',
        '<B=?         > Displays this help window.',
        '',
        '<C> (</B/24>Refer to the scrolling window online manual for more help<!B!24.)',
    ]

    # Pop up the help message.
    entry.screen.popupLabel(mesg, mesg.size)
  end

  def SQLiteDemo.main
    history = OpenStruct.new
    history.used = 0
    history.count = 0
    history.current = 0
    history.cmd_history = []
    count = 0

    prompt = ''
    dbfile = ''
    opts = OptionParser.getopts('p:f:h')
    if opts['p']
      prompt = opts['p']
    end
    if opts['f']
      dbfile = opts['f']
    end
    if opts['h']
      puts 'Usage: %s %s' % [File.basename($PROGRAM_NAME), SQLiteDemo::GPUsage]
      exit  # EXIT_SUCCESS
    end

    dsquery = ''

    # Set up the command prompt.
    if prompt == ''
      if dbfile == ''
        prompt = '</B/24>Command >'
      else
        prompt = '</B/24>[%s] Command >' % [prompt]
      end
    end

    # Set up CDK
    curses_win = Ncurses.initscr
    @@gp_cdk_screen = CDK::SCREEN.new(curses_win)

    # Set up CDK colors
    CDK::Draw.initCDKColor

    begin
      sqlitedb = SQLite3::Database.new(dbfile)
    rescue
      mesg = ['<C></U>Fatal Error', '<C>Could not connect to the database.']
      @gp_cdk_screen.popupLabel(mesg, mesg.size)
      exit  # EXIT_FAILURE
    end

    # Load the history.
    SQLiteDemo.loadHistory(history)

    # Create the scrolling window.
    command_output = CDK::SWINDOW.new(@@gp_cdk_screen, CDK::CENTER, CDK::TOP,
        -8, -2, '<C></B/5>Command Output Window', SQLiteDemo::MAXWIDTH,
        true, false)

    # Create the entry field.
    width = Ncurses.COLS - prompt.size - 1
    command_entry = CDK::ENTRY.new(@@gp_cdk_screen, CDK::CENTER, CDK::BOTTOM,
        '', prompt, Ncurses::A_BOLD | Ncurses.COLOR_PAIR(8),
        Ncurses.COLOR_PAIR(24) | '_'.ord, :MIXED, width, 1, 512, false, false)

    # Create the key bindings.

    history_up_cb = lambda do |cdktype, entry, history, key|
      # Make sure we don't go out of bounds
      if history.current == 0
        CDK.Beep
        return true
      end

      # Decrement the counter.
      history.current -= 1

      # Display the command.
      entry.setValue(history.cmd_history[history.current])
      entry.draw(entry.box)
      return true
    end

    history_down_cb = lambda do |cdktype, entry, history, key|
      # Make sure we don't go out of bounds.
      if history.current == history.count
        CDK.Beep
        return true
      end

      # Increment the counter...
      history.current += 1

      # If we are at the end, clear the entry field.
      if history.current == history.count
        entry.clean
        entry.draw(entry.box)
        return true
      end

      # Display the command.
      entry.setValue(history.cmd_history[history.current])
      entry.draw(entry.box)
      return true
    end

    list_history_cb = lambda do |cdktype, entry, history, key|
      height = [history.count, 10].min + 3

      # No history, no list.
      if history.count == 0
        # Popup a little window telling the user there are no commands.
        mesg = ['<C></B/16>No Commands Entered', '<C>No History']
        entry.screen.popupLabel(mesg, mesg.size)

        # Redraw the screen.
        entry.erase
        entry.screen.draw

        # And leave...
        return true
      end

      # Create the scrolling list of previous commands.
      scroll_list = CDK::SCROLL.new(entry.screen, CDK::CENTER, CDK::CENTER,
          CDK::RIGHT, height, -10, '<C></B/29>Command History',
          history.cmd_history, history.count, true, Ncurses::A_REVERSE,
          true, false)

      # Get the command to execute.
      selection = scroll_list.activate([])
      scroll_list.destroy

      # Check the results of the selection.
      if selection >= 0
        # Get the command and stick it back in the entry field.
        entry.setValue(history.cmd_history[selection])
      end

      # Redraw the screen.
      entry.erase
      entry.screen.draw
      return true
    end

    view_history_cb = lambda do |cdktype, entry, swindow, key|
      swindow.activate([])
      entry.draw(entry.box)
      return true
    end

    swindow_help_cb = lambda do |cdktype, object, entry, key|
      SQLiteDemo.help(entry)
      return true
    end

    command_entry.bind(:ENTRY, Ncurses::KEY_UP, history_up_cb, history)
    command_entry.bind(:ENTRY, Ncurses::KEY_DOWN, history_down_cb, history)
    command_entry.bind(:ENTRY, CDK.CTRL('^'), list_history_cb, history)
    command_entry.bind(:ENTRY, CDK::KEY_TAB, view_history_cb, command_output)
    command_output.bind(:SWINDOW, '?', swindow_help_cb, command_entry)

    # Draw the screen.
    @@gp_cdk_screen.refresh

    # Display the introduction window.
    SQLiteDemo.intro(@@gp_cdk_screen)

    while true
      # Get the command.
      command = command_entry.activate([]).strip
      upper = command.upcase

      # Check the output of the command.
      if ['QUIT', 'EXIT', 'Q', 'E'].include?(upper) ||
          command_entry.exit_type == :ESCAPE_HIT
        # Save the history.
        SQLiteDemo.saveHistory(history, 100)

        # Exit
        if !sqlitedb.closed?
          sqlitedb.close
        end

        # All done.
        command_entry.destroy
        command_output.destroy
        CDK::SCREEN.endCDK
        exit  # EXIT_SUCCESS
      elsif command == 'clear'
        # Clear the scrolling window.
        command_output.clean
      elsif command == 'history'
        list_history_cb.call(:ENTRY, command_entry, history, nil)
        next
      elsif command == 'tables'
        command = "SELECT * FROM sqlite_master WHERE type='table';"
        command_output.add('</R>%d<!R> %s' % [count + 1, command], CDK::BOTTOM)
        count += 1
        sqlitedb.execute(command) do |row|
          if row.size >= 3
            command_output.add(row[2], CDK::BOTTOM)
          end
        end
      elsif command == 'help'
        # Display the help.
        SQLiteDemo.help(command_entry)
      else
        command_output.add('</R>%d<!R> %s' % [count + 1, command], CDK::BOTTOM)
        count += 1
        begin
          sqlitedb.execute(command) do |row|
            command_output.add(row.join(' '), CDK::BOTTOM)
          end
        rescue Exception => e
          command_output.add('Error: %s' % [e.message], CDK::BOTTOM)
        end
      end

      # Keep the history.
      history.cmd_history << command
      history.count += 1
      history.used += 1
      history.current = history.count

      # Clear the entry field.
      command_entry.clean
    end

    # Clean up
    @@gp_cdk_screen.destroy
    CDK::SCREEN.endCDK
    exit  # EXIT_SUCCESS
  end
end

SQLiteDemo.main
