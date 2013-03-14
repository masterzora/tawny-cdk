#!/usr/bin/env ruby
require './example'

class FSliderExample < Example
  def FSliderExample.parse_opts(opts, param)
    opts.banner = 'Usage: fslider_ex.rb [options]'

    param.x_value = CDK::CENTER
    param.y_value = CDK::CENTER
    param.box = true
    param.shadow = false
    param.high = 100
    param.low = 1
    param.inc = 1
    param.width = 50
    param.digits = 0

    super(opts, param)

    opts.on('-h HIGH', OptionParser::DecimalInteger, 'High value') do |h|
      param.high = h
    end

    opts.on('-l LOW', OptionParser::DecimalInteger, 'Low value') do |l|
      param.low = l
    end

    opts.on('-i INC', OptionParser::DecimalInteger, 'Increment amount') do |i|
      param.inc = i
    end

    opts.on('-w WIDTH', OptionParser::DecimalInteger, 'Widget width') do |w|
      param.width = w
    end

    opts.on('-p DIGITS', OptionParser::DecimalInteger, 'Digits') do |p|
      param.digits = p
    end
  end

  # This program demonstrates the Cdk slider widget.
  def FSliderExample.main
    # Declare variables.
    title = '<C></U>Enter a value'
    label = '</B>Current Value:'
    params = parse(ARGV)

    scale = 1.0
    (0...params.digits).each do |n|
      scale = scale * 10.0
    end

    params.high = params.high / scale
    params.inc = params.inc / scale
    params.low = params.low / scale

    # Set up CDK
    curses_win = Ncurses.initscr
    cdkscreen = CDK::SCREEN.new(curses_win)

    # Set up CDK colors
    CDK::Draw.initCDKColor

    # Create the widget
    widget = CDK::FSLIDER.new(cdkscreen, params.x_value, params.y_value,
        title, label,
        Ncurses::A_REVERSE | Ncurses.COLOR_PAIR(29) | ' '.ord,
        params.width, params.low, params.low, params.high, params.inc,
        (params.inc * 2), params.digits, params.box, params.shadow)

    # Is the widget nll?
    if widget.nil?
      # Exit CDK.
      cdkscreen.destroy
      CDK::SCREEN.endCDK

      puts "Cannot make the widget. Is the window too small?"
      exit  # EXIT_FAILURE
    end

    # Activate the widget.
    selection = widget.activate([])

    # Check the exit value of the widget.
    if widget.exit_type == :ESCAPE_HIT
      mesg = [
          '<C>You hit escape. No value selected.',
          '',
          '<C>Press any key to continue.',
      ]
      cdkscreen.popupLabel(mesg, 3)
    elsif widget.exit_type == :NORMAL
      mesg = [
          '<C>You selected %.*f' % [params.digits, selection],
          '',
          '<C>Press any key to continue.',
      ]
      cdkscreen.popupLabel(mesg, 3)
    end

    # Clean up
    widget.destroy
    cdkscreen.destroy
    CDK::SCREEN.endCDK
    #ExitProgram (EXIT_SUCCESS);
  end
end

FSliderExample.main
