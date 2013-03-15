#!/usr/bin/env ruby
require_relative 'example'

class MatrixExample < Example
  def MatrixExample.parse_opts(opts, param)
    opts.banner = 'Usage: matrix_ex.rb [options]'

    param.x_value = CDK::CENTER
    param.y_value = CDK::CENTER
    param.box = true
    param.shadow = true
    param.title =
        "<C>This is the CDK\n<C>matrix widget.\n<C><#LT><#HL(30)><#RT>"
    param.cancel_title = false
    param.cancel_row = false
    param.cancel_col = false

    super(opts, param)

    opts.on('-T TITLE', String, 'Matrix title') do |title|
      param.title = title
    end

    opts.on('-t', 'Turn off matrix title') do
      param.cancel_title = true
    end

    opts.on('-c', 'Turn off column titles') do
      param.cancel_col = true
    end

    opts.on('-r', 'Turn off row titles') do
      param.cancel_row = true
    end
  end

  # This program demonstrates the Cdk calendar widget.
  def MatrixExample.main
    rows = 8
    cols = 5
    vrows = 3
    vcols = 5

    params = parse(ARGV)

    # Set up CDK
    curses_win = Ncurses.initscr
    cdkscreen = CDK::SCREEN.new(curses_win)

    # Set up CDK colors
    CDK::Draw.initCDKColor

    coltitle = []
    unless params.cancel_col
      coltitle = ['', '</B/5>Course', '</B/33>Lec 1', '</B/33>Lec 2',
          '</B/33>Lec 3', '</B/7>Flag']
    end
    colwidth = [0, 7, 7, 7, 7, 1]
    colvalue = [:UMIXED, :UMIXED, :UMIXED, :UMIXED, :UMIXED, :UMIXED]

    rowtitle = []
    unless params.cancel_row
      rowtitle << ''
      (1..rows).each do |x|
        rowtitle << '<C></B/6>Course %d' % [x]
      end
    end

    # Create the matrix object
    course_list = CDK::MATRIX.new(cdkscreen, params.x_value, params.y_value,
        rows, cols, vrows, vcols,
        if params.cancel_title then '' else params.title end,
        rowtitle, coltitle, colwidth, colvalue, -1, -1, '.',
        2, params.box, params.box, params.shadow)

    if course_list.nil?
      # Exit CDK.
      cdkscreen.destroy
      CDK::SCREEN.endCDK
    
      puts 'Cannot create the matrix widget. Is the window too small?'
      exit  # EXIT_FAILURE
    end

    # Activate the matrix
    course_list.activate([])

    # Check if the user hit escape or not.
    if course_list.exit_type == :ESCAPE_HIT
      mesg = [
          '<C>You hit escape. No information passed back.',
          '',
          '<C>Press any key to continue.'
      ]
      cdkscreen.popupLabel(mesg, 3)
    elsif course_list.exit_type == :NORMAL
      mesg = [
          '<L>You exited the matrix normally',
          'Current cell (%d,%d)' % [course_list.crow, course_list.ccol],
          '<L>To get the contents of the matrix cell, you can',
          '<L>use getCell():',
          course_list.getCell(course_list.crow, course_list.ccol),
          '',
          '<C>Press any key to continue.'
      ]
      cdkscreen.popupLabel(mesg, 7)
    end

    # Clean up
    course_list.destroy
    cdkscreen.destroy
    CDK::SCREEN.endCDK
    #ExitProgram (EXIT_SUCCESS);
  end
end

MatrixExample.main
