#!/usr/bin/env ruby
require './example'

class Viewer2Example < CLIExample
  def Viewer2Example.parse_opts(opts, params)
    opts.banner = 'Usage: viewer_ex.rb [options]'

    # default values
    params.box = true
    params.shadow = false
    params.x_value = CDK::CENTER
    params.y_value = CDK::CENTER
    params.h_value = 20
    params.w_value = 65
    params.filename = ''
    params.directory = '.'
    params.interp = false

    super(opts, params)

    opts.on('-f FILENAME', String, 'Filename to open') do |f|
      params.filename = f
    end

    opts.on('-d DIR', String, 'Default directory') do |d|
      params.directory = d
    end

    opts.on('-i', String, 'Interpret embedded markup') do
      params.interp = true
    end
  end

  # Demonstrate a scrolling-window.
  def Viewer2Example.main
    title = "<C>Pick\n<C>A\n<C>File"
    label = 'File: '
    button = [
        '</5><OK><!5>',
        '</5><Cancel><!5>',
    ]

    # Declare variables.
    params = parse(ARGV)

    # Start curses
    curses_win = Ncurses.initscr
    cdkscreen = CDK::SCREEN.new(curses_win)

    # Start CDK colors.
    CDK::Draw.initCDKColor

    f_select = nil
    if params.filename == ''
      f_select = CDK::FSELECT.new(cdkscreen, params.x_value, params.y_value,
          params.h_value, params.w_value, title, label, Ncurses::A_NORMAL,
          '_', Ncurses::A_REVERSE, '</5>', '</48>', '</N>', '</N',
          params.box, params.shadow)

      if f_select.nil?
        cdkscreen.destroy
        CDK::SCREEN.endCDK

        $stderr.puts 'Cannot create fselect-widget'
        exit  # EXIT_FAILURE
      end

      # Set the starting directory. This is not necessary because when
      # the file selector starts it uses the present directory as a default.
      f_select.set(params.directory, Ncurses::A_NORMAL, '.',
          Ncurses::A_REVERSE, '</5>', '</48>', '</N>', '</N>', @box)

      # Activate the file selector.
      params.filename = f_select.activate([])

      # Check how the person exited from the widget.
      if f_select.exit_type == :ESCAPE_HIT
        # Pop up a message for the user.
        mesg = [
            '<C>Escape hit. No file selected.',
            '',
            '<C>Press any key to continue.',
        ]
        cdkscreen.popupLabel(mesg, 3)

        # Exit CDK.
        f_select.destroy
        cdkscreen.destroy
        CDK::SCREEN.endCDK
        exit  # EXIT_SUCCESS
      end
    end

    # Set up the viewer title and the contents to the widget.
    v_title = '<C></B/21>Filename:<!21></22>%20s<!22!B>' % [params.filename]

    selected = CDK.viewFile(cdkscreen, v_title, params.filename, button, 2)

    # Destroy the file selector widget (do not need filename anymore)
    unless f_select.nil?
      f_select.destroy
    end

    # Check how the person exited from the widget.
    mesg = [
        '<C>You selected button %d' % [selected],
        '',
        '<C>Press any key to continue.'
    ]
    cdkscreen.popupLabel(mesg, 3)

    # Clean up.
    cdkscreen.destroy
    CDK::SCREEN.endCDK
    exit  # EXIT_SUCCESS
  end
end

Viewer2Example.main
