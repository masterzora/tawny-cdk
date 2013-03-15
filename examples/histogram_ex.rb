#!/usr/bin/env ruby
require_relative 'example'

class HistogramExample < CLIExample
  def HistogramExample.parse_opts(opts, params)
    opts.banner = 'Usage: histogram_ex.rb [options]'

    # default values
    params.box = true
    params.shadow = false
    params.x_value = 10
    params.y_value = false
    params.y_vol = 10
    params.y_bass = 14
    params.y_treb = 18
    params.h_value = 1
    params.w_value = -2

    super(opts, params)

    if params.y_value != false
      params.y_vol = params.y_value
      params.y_bass = params.y_value
      params.y_treb = params.y_value
    end
  end

  def HistogramExample.main
    params = parse(ARGV)

    # Set up CDK
    curses_win = Ncurses.initscr
    cdkscreen = CDK::SCREEN.new(curses_win)

    # Set up CDK colors
    CDK::Draw.initCDKColor

    # Create the histogram objects.
    volume_title = "<C></5>Volume<!5>"
    bass_title = "<C></5>Bass  <!5>"
    treble_title = "<C></5>Treble<!5>"
    box = params.box

    volume = CDK::HISTOGRAM.new(cdkscreen, params.x_value, params.y_vol,
        params.h_value, params.w_value, CDK::HORIZONTAL, volume_title,
        box, params.shadow)

    # Is the volume null?
    if volume.nil?
      cdkscreen.destroy
      CDK::SCREEN.endCDK

      puts "Cannot make volume histogram.  Is the window big enough?"
      exit #EXIT_FAILURE
    end

    bass = CDK::HISTOGRAM.new(cdkscreen, params.x_value, params.y_bass,
        params.h_value, params.w_value, CDK::HORIZONTAL, bass_title,
        box, params.shadow)

    if bass.nil?
      volume.destroy
      cdkscreen.destroy
      CDK::SCREEN.endCDK

      puts "Cannot make bass histogram.  Is the window big enough?"
      exit  # EXIT_FAILURE
    end


    treble = CDK::HISTOGRAM.new(cdkscreen, params.x_value, params.y_treb,
        params.h_value, params.w_value, CDK::HORIZONTAL, treble_title,
        box, params.shadow)

    if treble.nil?
      volume.destroy
      bass.destroy
      cdkscreen.destroy
      CDK::SCREEN.endCDK

      puts "Cannot make treble histogram.  Is the window big enough?"
      exit  # EXIT_FAILURE
    end

    # Set the histogram values.
    volume.set(:PERCENT, CDK::CENTER, Ncurses::A_BOLD, 0, 10, 6,
        ' '.ord | Ncurses::A_REVERSE | Ncurses.COLOR_PAIR(3), box)
    bass.set(:PERCENT, CDK::CENTER, Ncurses::A_BOLD, 0, 10, 3,
        ' '.ord | Ncurses::A_REVERSE | Ncurses.COLOR_PAIR(3), box)
    treble.set(:PERCENT, CDK::CENTER, Ncurses::A_BOLD, 0, 10, 7,
        ' '.ord | Ncurses::A_REVERSE | Ncurses.COLOR_PAIR(3), box)
    cdkscreen.refresh
    sleep(4)

    # Set the histogram values.
    volume.set(:PERCENT, CDK::CENTER, Ncurses::A_BOLD, 0, 10, 8,
        ' '.ord | Ncurses::A_REVERSE | Ncurses.COLOR_PAIR(3), box)
    bass.set(:PERCENT, CDK::CENTER, Ncurses::A_BOLD, 0, 10, 1,
        ' '.ord | Ncurses::A_REVERSE | Ncurses.COLOR_PAIR(3), box)
    treble.set(:PERCENT, CDK::CENTER, Ncurses::A_BOLD, 0, 10, 9,
        ' '.ord | Ncurses::A_REVERSE | Ncurses.COLOR_PAIR(3), box)
    cdkscreen.refresh
    sleep(4)

    # Set the histogram values.
    volume.set(:PERCENT, CDK::CENTER, Ncurses::A_BOLD, 0, 10, 10,
        ' '.ord | Ncurses::A_REVERSE | Ncurses.COLOR_PAIR(3), box)
    bass.set(:PERCENT, CDK::CENTER, Ncurses::A_BOLD, 0, 10, 7,
        ' '.ord | Ncurses::A_REVERSE | Ncurses.COLOR_PAIR(3), box)
    treble.set(:PERCENT, CDK::CENTER, Ncurses::A_BOLD, 0, 10, 10,
        ' '.ord | Ncurses::A_REVERSE | Ncurses.COLOR_PAIR(3), box)
    cdkscreen.refresh
    sleep(4)

    # Set the histogram values.
    volume.set(:PERCENT, CDK::CENTER, Ncurses::A_BOLD, 0, 10, 1,
        ' '.ord | Ncurses::A_REVERSE | Ncurses.COLOR_PAIR(3), box)
    bass.set(:PERCENT, CDK::CENTER, Ncurses::A_BOLD, 0, 10, 8,
        ' '.ord | Ncurses::A_REVERSE | Ncurses.COLOR_PAIR(3), box)
    treble.set(:PERCENT, CDK::CENTER, Ncurses::A_BOLD, 0, 10, 3,
        ' '.ord | Ncurses::A_REVERSE | Ncurses.COLOR_PAIR(3), box)
    cdkscreen.refresh
    sleep(4)

    # Set the histogram values.
    volume.set(:PERCENT, CDK::CENTER, Ncurses::A_BOLD, 0, 10, 3,
        ' '.ord | Ncurses::A_REVERSE | Ncurses.COLOR_PAIR(3), box)
    bass.set(:PERCENT, CDK::CENTER, Ncurses::A_BOLD, 0, 10, 3,
        ' '.ord | Ncurses::A_REVERSE | Ncurses.COLOR_PAIR(3), box)
    treble.set(:PERCENT, CDK::CENTER, Ncurses::A_BOLD, 0, 10, 3,
        ' '.ord | Ncurses::A_REVERSE | Ncurses.COLOR_PAIR(3), box)
    cdkscreen.refresh
    sleep(4)

    # Set the histogram values.
    volume.set(:PERCENT, CDK::CENTER, Ncurses::A_BOLD, 0, 10, 10,
        ' '.ord | Ncurses::A_REVERSE | Ncurses.COLOR_PAIR(3), box)
    bass.set(:PERCENT, CDK::CENTER, Ncurses::A_BOLD, 0, 10, 10,
        ' '.ord | Ncurses::A_REVERSE | Ncurses.COLOR_PAIR(3), box)
    treble.set(:PERCENT, CDK::CENTER, Ncurses::A_BOLD, 0, 10, 10,
        ' '.ord | Ncurses::A_REVERSE | Ncurses.COLOR_PAIR(3), box)
    cdkscreen.refresh
    sleep(4)

    # Clean up
    volume.destroy
    bass.destroy
    treble.destroy
    cdkscreen.destroy
    CDK::SCREEN.endCDK
    exit  # EXIT_SUCCESS
  end
end

HistogramExample.main
