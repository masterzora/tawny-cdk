#!/usr/bin/env ruby
require_relative '../lib/cdk'

class StopSign
  def StopSign.main
    # Set up CDK
    curses_win = Ncurses.initscr
    cdkscreen = CDK::SCREEN.new(curses_win)

    # Set up CDK colors
    CDK::Draw.initCDKColor

    # Set the labels up.
    mesg = [
        '<C><#HL(40)>',
        '<C>Press </B/16>r<!B!16> for the </B/16>red light',
        '<C>Press </B/32>y<!B!32> for the </B/32>yellow light',
        '<C>Press </B/24>g<!B!24> for the </B/24>green light',
        '<C><#HL(40)>',
    ]
    sign = [
        ' <#DI> ',
        ' <#DI> ',
        ' <#DI> ',
    ]

    # Declare the labels.
    title = CDK::LABEL.new(cdkscreen, CDK::CENTER, CDK::TOP,
        mesg, 5, false, false)
    stop_sign = CDK::LABEL.new(cdkscreen, CDK::CENTER, CDK::CENTER,
        sign, 3, true, true)

    # Do this until they hit q or escape.
    while true
      title.draw(false)
      stop_sign.draw(true)

      key = stop_sign.getch([])
      if key == CDK::KEY_ESC || key == 'q'.ord || key == 'Q'.ord
        break
      elsif key == 'r'.ord || key == 'R'.ord
        sign[0] = ' </B/16><#DI> '
        sign[1] = ' o '
        sign[2] = ' o '
      elsif key == 'y'.ord || key == 'Y'.ord
        sign[0] = ' o '
        sign[1] = ' </B/32><#DI> '
        sign[2] = ' o '
      elsif key == 'g'.ord || key == 'G'.ord
        sign[0] = ' o '
        sign[1] = ' o '
        sign[2] = ' </B/24><#DI> '
      end

      # Set the contents of the label and re-draw it.
      stop_sign.set(sign, 3, true)
    end

    # Clean up
    title.destroy
    stop_sign.destroy
    cdkscreen.destroy
    CDK::SCREEN.endCDK
    #ExitProgram (EXIT_SUCCESS);
  end
end

StopSign.main
