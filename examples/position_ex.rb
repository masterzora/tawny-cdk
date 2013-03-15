#!/usr/bin/env ruby
require_relative 'example'

class PositionExample < Example
  def PositionExample.parse_opts(opts, param)
    opts.banner = 'Usage: position_ex.rb [options]'

    param.x_value = CDK::CENTER
    param.y_value = CDK::CENTER
    param.box = true
    param.shadow = false
    param.w_value = 40

    super(opts, param)

    opts.on('-w WIDTH', OptionParser::DecimalInteger, 'Field width') do |w|
      param.w_value = w
    end
  end

  # This demonstrates the positioning of a Cdk entry field widget.
  def PositionExample.main
    label = "</U/5>Directory:<!U!5> "
    params = parse(ARGV)

    # Set up CDK
    curses_win = Ncurses.initscr
    cdkscreen = CDK::SCREEN.new(curses_win)

    # Set up CDK colors
    CDK::Draw.initCDKColor

    # Create the entry field widget.
    directory = CDK::ENTRY.new(cdkscreen, params.x_value, params.y_value,
        '', label, Ncurses::A_NORMAL, '.', :MIXED, params.w_value, 0, 256,
        params.box, params.shadow)

    # Is the widget nil?
    if directory.nil?
      # Clean up.
      cdkscreen.destroy
      CDK::SCREEN.endCDK

      puts "Cannot create the entry box. Is the window too small?"
      exit  # EXIT_FAILURE
    end

    # Let the user move the widget around the window.
    directory.draw(directory.box)
    directory.position

    # Activate the entry field.
    info = directory.activate('')

    # Tell them what they typed.
    if directory.exit_type == :ESCAPE_HIT
      mesg = [
          "<C>You hit escape. No information passed back.",
          "",
          "<C>Press any key to continue."
      ]
      cdkscreen.popupLabel(mesg, 3)
    elsif directory.exit_type == :NORMAL
      mesg = [
          "<C>You typed in the following",
          "<C>%.*s" % [236, info],  # FIXME magic number
          "",
          "<C>Press any key to continue."
      ]
          cdkscreen.popupLabel(mesg, 4)
    end

    # Clean up
    directory.destroy
    cdkscreen.destroy
    CDK::SCREEN.endCDK
    #ExitProgram (EXIT_SUCCESS);
  end
end

PositionExample.main
