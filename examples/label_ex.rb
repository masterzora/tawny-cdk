#!/usr/bin/env ruby
require './example'

class LabelExample < Example
  def LabelExample.parse_opts(opts, param)
    opts.banner = 'Usage: label_ex.rb [options]'

    param.x_value = CDK::CENTER
    param.y_value = CDK::CENTER
    param.box = true
    param.shadow = true
    super(opts, param)
  end

  # This program demonstrates the Cdk label widget.
  def LabelExample.main
    # Declare variables.
    mesg = []

    params = parse(ARGV)

    # Set up CDK
    curses_win = Ncurses.initscr
    cdkscreen = CDK::SCREEN.new(curses_win)

    # Set up CDK colors
    CDK::Draw.initCDKColor

    # Set the labels up.
    mesg = [
        "</29/B>This line should have a yellow foreground and a blue background.",
        "</5/B>This line should have a white  foreground and a blue background.",
        "</26/B>This line should have a yellow foreground and a red  background.",
        "<C>This line should be set to whatever the screen default is."
    ]

    # Declare the labels.
    demo = CDK::LABEL.new(cdkscreen,
        params.x_value, params.y_value, mesg, 4,
        params.box, params.shadow)

    # if (demo == 0)
    # {
    #   /* Clean up the memory.
    #   destroyCDKScreen (cdkscreen);
    #
    #   # End curses...
    #   endCDK ();
    #
    #   printf ("Cannot create the label. Is the window too small?\n");
    #   ExitProgram (EXIT_FAILURE);
    # }

    # Draw the CDK screen.
    cdkscreen.refresh
    demo.wait(' ')

    # Clean up
    demo.destroy
    cdkscreen.destroy
    CDK::SCREEN.endCDK
    #ExitProgram (EXIT_SUCCESS);
  end
end

LabelExample.main
