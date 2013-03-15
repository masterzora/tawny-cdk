#!/usr/bin/env ruby
require_relative 'example'

class CDKScreenExample < Example
  # This demonstrates how to create four different Cdk screens
  # and flip between them.
  def CDKScreenExample.main
    buttons = ["Continue", "Exit"]

    # Create the curses window.
    curses_win = Ncurses.initscr

    # Create the screens
    cdkscreen1 = CDK::SCREEN.new(curses_win)
    cdkscreen2 = CDK::SCREEN.new(curses_win)
    cdkscreen3 = CDK::SCREEN.new(curses_win)
    cdkscreen4 = CDK::SCREEN.new(curses_win)
    cdkscreen5 = CDK::SCREEN.new(curses_win)

    # Create the first screen.
    title1_mesg = [
        "<C><#HL(30)>",
        "<C></R>This is the first screen.",
        "<C>Hit space to go to the next screen",
        "<C><#HL(30)>"
    ]
    label1 = CDK::LABEL.new(cdkscreen1, CDK::CENTER, CDK::TOP, title1_mesg,
        4, false, false)

    # Create the second screen.
    title2_mesg = [
        "<C><#HL(30)>",
        "<C></R>This is the second screen.",
        "<C>Hit space to go to the next screen",
        "<C><#HL(30)>"
    ]
    label2 = CDK::LABEL.new(cdkscreen2, CDK::RIGHT, CDK::CENTER, title2_mesg,
        4, false, false)

    # Create the third screen.
    title3_mesg = [
        "<C><#HL(30)>",
        "<C></R>This is the third screen.",
        "<C>Hit space to go to the next screen",
        "<C><#HL(30)>"
    ]
    label3 = CDK::LABEL.new(cdkscreen3, CDK::CENTER, CDK::BOTTOM, title3_mesg,
        4, false, false)

    # Create the fourth screen.
    title4_mesg = [
        "<C><#HL(30)>",
        "<C></R>This is the fourth screen.",
        "<C>Hit space to go to the next screen",
        "<C><#HL(30)>"
    ]
    label4 = CDK::LABEL.new(cdkscreen4, CDK::LEFT, CDK::CENTER, title4_mesg,
        4, false, false)

    # Create the fifth screen.
    dialog_mesg = [
        "<C><#HL(30)>",
        "<C>Screen 5",
        "<C>This is the last of 5 screens. If you want",
        "<C>to continue press the 'Continue' button.",
        "<C>Otherwise press the 'Exit' button",
        "<C><#HL(30)>"
    ]
    dialog = CDK::DIALOG.new(cdkscreen5, CDK::CENTER, CDK::CENTER, dialog_mesg,
        6, buttons, 2, Ncurses::A_REVERSE, true, true, false)

    # Do this forever... (almost)
    while true
      # Draw the first screen.
      cdkscreen1.draw
      label1.wait(' ')
      cdkscreen1.erase

      # Draw the second screen.
      cdkscreen2.draw
      label2.wait(' ')
      cdkscreen2.erase

      # Draw the third screen.
      cdkscreen3.draw
      label3.wait(' ')
      cdkscreen3.erase

      # Draw the fourth screen.
      cdkscreen4.draw
      label4.wait(' ')
      cdkscreen4.erase

      # Draw the fifth screen
      cdkscreen5.draw
      answer = dialog.activate('')

      # Check the user's answer.
      if answer == 1
        label1.destroy
        label2.destroy
        label3.destroy
        label4.destroy
        dialog.destroy
        cdkscreen1.destroy
        cdkscreen2.destroy
        cdkscreen3.destroy
        cdkscreen4.destroy
        cdkscreen5.destroy
        CDK::SCREEN.endCDK
        exit  # EXIT__SUCCESS
      end
    end
  end
end

CDKScreenExample.main
