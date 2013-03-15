#!/usr/bin/env ruby
require_relative 'example'

class RadioExample < CLIExample
  def RadioExample.parse_opts(opts, params)
    opts.banner = 'Usage: radio_ex.rb [options]'

    # default values
    params.box = true
    params.shadow = false
    params.x_value = CDK::CENTER
    params.y_value = CDK::CENTER
    params.h_value = 10
    params.w_value = 40
    params.c = false
    params.spos = CDK::RIGHT
    params.title = "<C></5>Select a filename"

    super(opts, params)

    opts.on('-c', 'create the data after the widget') do
      params.c = true
    end

    opts.on('-s SCROLL_POS', OptionParser::DecimalInteger,
        'location for the scrollbar') do |spos|
      params.spos = spos
    end

    opts.on('-t TITLE', String, 'title for the widget') do |title|
      params.title = title
    end
  end

  # This program demonstrates the Cdk radio widget.
  #
  # Options (in addition to normal CLI parameters):
  #   -c      create the data after the widget
  #   -s SPOS location for the scrollbar
  #   -t TEXT title for the widget
  def RadioExample.main
    params = parse(ARGV)

    # Use the current directory list to fill the radio list
    item = []
    count = CDK.getDirectoryContents(".", item)
    if count <= 0
      $stderr.puts "Cannot get directory list"
      exit  # EXIT_FAILURE
    end

    # Set up CDK
    curses_win = Ncurses.initscr
    cdkscreen = CDK::SCREEN.new(curses_win)

    # Set up CDK colors
    CDK::Draw.initCDKColor

    # Create the radio list.
    radio = CDK::RADIO.new(cdkscreen,
        params.x_value, params.y_value, params.spos,
        params.h_value, params.w_value, params.title,
        if params.c then [] else item end,
        if params.c then 0 else count end,
        '#'.ord | Ncurses::A_REVERSE, true, Ncurses::A_REVERSE,
        params.box, params.shadow)

    if radio.nil?
      cdkscreen.destroyCDKScreen
      CDK::SCREEN.endCDK

      puts "Cannot make radio widget.  Is the window too small?"
      exit #EXIT_FAILURE
    end

    if params.c
      radio.setItems(item, count)
    end

    # Loop until the user selects a file, or cancels
    while true
    
      # Activate the radio widget.
      selection = radio.activate([])

      # Check the exit status of the widget.
      if radio.exit_type == :ESCAPE_HIT
        mesg = [
            '<C>You hit escape. No item selected',
            '',
            '<C>Press any key to continue.'
        ]
        cdkscreen.popupLabel(mesg, 3)
        break
      elsif radio.exit_type == :NORMAL
        if File.directory?(item[selection])
          mesg = [
              "<C> You selected a directory",
              "<C>%.*s" % [236, item[selection]],  # FIXME magic number
              "",
              "<C>Press any key to continue"
          ]
          cdkscreen.popupLabel(mesg, 4)
          nitem = []
          count = CDK.getDirectoryContents(item[selection], nitem)
          if count > 0
            Dir.chdir(item[selection])
            item = nitem
            radio.setItems(item, count)
          end
        else
          mesg = ['<C>You selected the filename',
            "<C>%.*s" % [236, item[selection]],  # FIXME magic number
            "",
            "<C>Press any key to continue."
          ]
          cdkscreen.popupLabel(mesg, 4);
          break
        end
      end
    end

    # Clean up.
    radio.destroy
    cdkscreen.destroy
    CDK::SCREEN.endCDK
    exit #EXIT_SUCCESS
  end
end

RadioExample.main
