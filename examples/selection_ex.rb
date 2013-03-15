#!/usr/bin/env ruby
require 'etc'
require_relative 'example'

class SelectionExample < CLIExample
  def SelectionExample.parse_opts(opts, params)
    opts.banner = 'Usage: selection_ex.rb [options]'

    # default values
    params.box = true
    params.shadow = false

    params.header =  ''
    params.footer = ''

    params.x_value = CDK::CENTER
    params.y_value = nil
    params.h_value = 10
    params.w_value = 50
    params.box = true
    params.c = false
    params.spos = CDK::RIGHT
    params.title = "<C></5>Pick one or more accounts."
    params.shadow = false

    super(opts, params)

    opts.on('-c', 'create the data after the widget') do
      params.c = true
    end

    opts.on('-f TEXT', String, 'title for a footer label') do |footer|
      params.footer = footer
    end

    opts.on('-h TEXT', String, 'title for a header label') do |header|
      params.header = header
    end

    opts.on('-s SPOS', OptionParser::DecimalInteger,
        'location for the scrollbar') do |spos|
      params.spos = spos
    end

    opts.on('-t TEXT', String, 'title for the widget') do |title|
      params.title = title
    end
  end

  # This program demonstrates the Cdk selection widget.
  #
  # Options (in addition to normal CLI parameters):
  #   -c      create the data after the widget
  #   -f TEXT title for a footer label
  #   -h TEXT title for a header label
  #   -s SPOS location for the scrollbar
  #   -t TEXT title for the widget
  def SelectionExample.main
    choices = [
        "   ",
        "-->"
    ]

    item = []
    params = parse(ARGV)

    # Use the account names to create a list.
    until (ent = Etc.getpwent).nil?
      item << ent.name
    end
    Etc.endpwent

    # Set up CDK
    curses_win = Ncurses.initscr
    cdkscreen = CDK::SCREEN.new(curses_win)

    # Set up CDK colors
    CDK::Draw.initCDKColor

    if params.header != ''
      list = [params.header]
      header = CDK::LABEL.new(cdkscreen, params.x_value,
          if params.y_value.nil? then CDK::TOP else params.y_value end,
          list, 1, params.box, !params.shadow)
      unless header.nil?
        header.activate([])
      end
    end

    if params.footer != ''
      list = [params.footer]
      footer = CDK::LABEL.new(cdkscreen, params.x_value,
          if params.y_value.nil? then CDK::BOTTOM else params.y_value end,
          list, 1, params.box, !params.shadow)
      unless footer.nil?
        footer.activate([])
      end
    end

    # Create the selection list.
    selection = CDK::SELECTION.new(cdkscreen, params.x_value,
        if params.y_value.nil? then CDK::CENTER else params.y_value end,
        params.spos, params.h_value, params.w_value,
        params.title,
        if params.c then [] else item end,
        if params.c then 0 else item.size end,
        choices, 2, Ncurses::A_REVERSE, params.box, params.shadow)

    if selection.nil?
      cdkscreen.destroyCDKScreen
      CDK::SCREEN.endCDK

      puts "Cannot make selection list.  Is the window too small?"
      exit #EXIT_FAILURE
    end

    if params.c
      selection.setItems(item, item.size)
    end

    # Activate the selection list.
    selection.activate([])

    # Check the exit status of the widget
    if selection.exit_type == :ESCAPE_HIT
      mesg = [
          '<C>You hit escape. No item selected',
          '',
          '<C>Press any key to continue.'
      ]
      cdkscreen.popupLabel(mesg, 3)
    elsif selection.exit_type == :NORMAL
      mesg = ["<C>Here are the accounts you selected."]
      (0...item.size).each do |x|
        if selection.selections[x] == 1
          mesg << "<C></5>%.*s" % [236, item[x]]  # FIXME magic number
        end
      end
      cdkscreen.popupLabel(mesg, mesg.size)
    else
      mesg = ["<C>Unknown failure."]
      cdkscreen.popupLabel(mesg, mesg.size)
    end

    # Clean up.
    selection.destroy
    cdkscreen.destroy
    CDK::SCREEN.endCDK
    exit #EXIT_SUCCESS
  end
end

SelectionExample.main
