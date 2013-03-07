#!/usr/bin/env ruby
require './example'

class EntryExample < Example
  def EntryExample.parse_opts(opts, param)
    opts.banner = 'Usage: dialog_ex.rb [options]'

    param.x_value = CDK::CENTER
    param.y_value = CDK::CENTER
    param.box = true
    param.shadow = false
    super(opts, param)
  end

  # This program demonstrates the Cdk dialog widget.
  def EntryExample.main
    title = "<C>Enter a\n<C>directory name."
    label = "</U/5>Directory:<!U!5>"

    params = parse(ARGV)

    # Set up CDK.
    curses_win = Ncurses.initscr
    cdkscreen = CDK::SCREEN.new(curses_win)

    # Start color.
    CDK::Draw.initCDKColor

    # Create the entry field widget.
    directory = CDK::ENTRY.new(cdkscreen, params.x_value, params.y_value,
        title, label, Ncurses::A_NORMAL, '.', :MIXED, 40, 0, 256,
        params.box, params.shadow)

    xxxcb = lambda do |cdktype, object, client_data, key|
      return true
    end

    directory.bind(:ENTRY, '?', xxxcb, 0)

    # Is the widget nil?
    if directory.nil?
      # Clean p
      cdkscreen.destroy
      CDK::SCREEN.endCDK

      puts "Cannot create the entry box. Is the window too small?"
      exit # EXIT_FAILURE
    end

    # Draw the screen.
    cdkscreen.refresh

    # Pass in whatever was given off of the command line.
    arg = if ARGV.size > 0 then ARGV[0] else nil end
    directory.set(arg, 0, 256, true)

    # Activate the entry field.
    info = directory.activate([])

    # Tell them what they typed.
    if directory.exit_type == :ESCAPE_HIT
      mesg = [
          "<C>You hit escape. No information passed back.",
          "",
          "<C>Press any key to continue."
      ]

      directory.destroy

      cdkscreen.popupLabel(mesg, 3)
    elsif directory.exit_type == :NORMAL
      mesg = [
          "<C>You typed in the following",
          "<C>(%.*s)" % [246, info],  # FIXME: magic number
          "",
          "<C>Press any key to continue."
      ]

      directory.destroy

      cdkscreen.popupLabel(mesg, 4)
    else
      directory.destroy
    end

    # Clean up and exit.
    cdkscreen.destroy
    CDK::SCREEN.endCDK
    exit  # EXIT_SUCCESS
  end
end

EntryExample.main
