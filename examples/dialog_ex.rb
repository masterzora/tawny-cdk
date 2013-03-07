#!/usr/bin/env ruby
require './example'

class DialogExample < Example
  def DialogExample.parse_opts(opts, param)
    opts.banner = 'Usage: dialog_ex.rb [options]'

    param.x_value = CDK::CENTER
    param.y_value = CDK::CENTER
    param.box = true
    param.shadow = false
    super(opts, param)
  end
  # This program demonstrates the Cdk dialog widget.
  def DialogExample.main
    buttons = ["</B/24>Ok", "</B16>Cancel"]

    params = parse(ARGV)

    # Set up CDK.
    curses_win = Ncurses.initscr
    cdkscreen = CDK::SCREEN.new(curses_win)

    # Start color.
    CDK::Draw.initCDKColor

    # Create the message within the dialog box.
    message = [
        "<C></U>Dialog Widget Demo",
        " ",
        "<C>The dialog widget allows the programmer to create",
        "<C>a popup dialog box with buttons. The dialog box",
        "<C>can contain </B/32>colours<!B!32>, </R>character attributes<!R>",
        "<R>and even be right justified.",
        "<L>and left."
    ]

    # Create the dialog box.
    question = CDK::DIALOG.new(cdkscreen, params.x_value, params.y_value,
        message, 7, buttons, 2, Ncurses.COLOR_PAIR(2) | Ncurses::A_REVERSE,
        true, params.box, params.shadow)

    # Check if we got a nil value back
    if question.nil?
      # Shut down Cdk.
      cdkscreen.destroy
      CDK::SCREEN.endCDK

      puts "Cannot create the dialog box. Is the window too small?"
      exit # EXIT_FAILURE
    end

    # Activate the dialog box.
    selection = question.activate([])

    # Tell them what was selected.
    if question.exit_type == :ESCAPE_HIT
      mesg = [
          "<C>You hit escape. No button selected.",
          "",
          "<C>Press any key to continue."
      ]
      cdkscreen.popupLabel(mesg, 3)
    elsif
      mesg = [
          "<C>You selected button #%d" % [selection],
          "",
          "<C>Press any key to continue."
      ]
      cdkscreen.popupLabel(mesg, 3)
    end

    # Clean up.
    question.destroy
    cdkscreen.destroy
    CDK::SCREEN.endCDK
    exit # EXIT_SUCCESS
  end
end

DialogExample.main
