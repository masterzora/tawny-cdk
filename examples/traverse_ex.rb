#!/usr/bin/env ruby
require './example'

class TraverseExample < Example
  MY_MAX = 3
  YES_NO = ['Yes', 'NO']
  MONTHS = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep',
      'Oct', 'Nov', 'Dec']
  CHOICES = ['[ ]', '[*]']
  # Exercise all widgets except
  #     CDKMENU
  #     CDKTRAVERSE
  # The names in parentheses do not accept input, so they will never have
  # focus for traversal.  The names with leading '*' have some limitation
  # that makes them not useful in traversal.
  MENU_TABLE = [
    ['(CDKGRAPH)',      :GRAPH],     # no traversal (not active)
    ['(CDKHISTOGRAM)',  :HISTOGRAM], # no traversal (not active)
    ['(CDKLABEL)',      :LABEL],     # no traversal (not active)
    ['(CDKMARQUEE)',    :MARQUEE],   # hangs (leaves trash)
    ['*CDKVIEWER',      :VIEWER],    # traversal out-only on OK
    ['ALPHALIST',       :ALPHALIST],
    ['BUTTON',          :BUTTON],
    ['BUTTONBOX',       :BUTTONBOX],
    ['CALENDAR',        :CALENDAR],
    ['DIALOG',          :DIALOG],
    ['DSCALE',          :DSCALE],
    ['ENTRY',           :ENTRY],
    ['FSCALE',          :FSCALE],
    ['FSELECT',         :FSELECT],
    ['FSLIDER',         :FSLIDER],
    ['ITEMLIST',        :ITEMLIST],
    ['MATRIX',          :MATRIX],
    ['MENTRY',          :MENTRY],
    ['RADIO',           :RADIO],
    ['SCALE',           :SCALE],
    ['SCROLL',          :SCROLL],
    ['SELECTION',       :SELECTION],
    ['SLIDER',          :SLIDER],
    ['SWINDOW',         :SWINDOW],
    ['TEMPLATE',        :TEMPLATE],
    ['USCALE',          :USCALE],
    ['USLIDER',         :USLIDER],
  ]
  @@all_objects = [nil] * MY_MAX

  def self.make_alphalist(cdkscreen, x, y)
    return CDK::ALPHALIST.new(cdkscreen, x, y, 10, 15, 'AlphaList', '->',
        TraverseExample::MONTHS, TraverseExample::MONTHS.size,
        '_'.ord, Ncurses::A_REVERSE, true, false)
  end

  def self.make_button(cdkscreen, x, y)
    return CDK::BUTTON.new(cdkscreen, x, y, 'A Button!', nil, true, false)
  end

  def self.make_buttonbox(cdkscreen, x, y)
    return CDK::BUTTONBOX.new(cdkscreen, x, y, 10, 16, 'ButtonBox', 6, 2,
        TraverseExample::MONTHS, TraverseExample::MONTHS.size,
        Ncurses::A_REVERSE, true, false)
  end

  def self.make_calendar(cdkscreen, x, y)
    return CDK::CALENDAR.new(cdkscreen, x, y, 'Calendar', 25, 1, 2000,
        Ncurses.COLOR_PAIR(16) | Ncurses::A_BOLD,
        Ncurses.COLOR_PAIR(24) | Ncurses::A_BOLD,
        Ncurses.COLOR_PAIR(32) | Ncurses::A_BOLD,
        Ncurses.COLOR_PAIR(40) | Ncurses::A_REVERSE,
        true, false)
  end

  def self.make_dialog(cdkscreen, x, y)
    mesg = [
        'This is a simple dialog box',
        'Is it simple enough?',
    ]

    return CDK::DIALOG.new(cdkscreen, x,y, mesg, mesg.size,
        TraverseExample::YES_NO, TraverseExample::YES_NO.size,
        Ncurses.COLOR_PAIR(2) | Ncurses::A_REVERSE,
        true, true, false)
  end

  def self.make_dscale(cdkscreen, x, y)
    return CDK::DSCALE.new(cdkscreen, x, y, 'DScale', 'Value',
        Ncurses::A_NORMAL, 15, 0.0, 0.0, 100.0, 1.0, (1.0 * 2.0), 1,
        true, false)
  end

  def self.make_entry(cdkscreen, x, y)
    return CDK::ENTRY.new(cdkscreen, x, y, '', 'Entry:', Ncurses::A_NORMAL,
        '.'.ord, :MIXED, 40, 0, 256, true, false)
  end

  def self.make_fscale(cdkscreen, x, y)
    return CDK::FSCALE.new(cdkscreen, x, y, 'FScale', 'Value',
        Ncurses::A_NORMAL, 15, 0.0, 0.0, 100.0, 1.0, (1.0 * 2.0), 1,
        true, false)
  end

  def self.make_fslider(cdkscreen, x, y)
    low = -32.0
    high = 64.0
    inc = 0.1
    return CDK::FSLIDER.new(cdkscreen, x, y, 'FSlider', 'Label',
        Ncurses::A_REVERSE | Ncurses.COLOR_PAIR(29) | ' '.ord,
        20, low, low, high, inc, (inc * 2), 3, true, false)
  end

  def self.make_fselect(cdkscreen, x, y)
    return CDK::FSELECT.new(cdkscreen, x, y, 15, 25, 'FSelect', '->',
        Ncurses::A_NORMAL, '_'.ord, Ncurses::A_REVERSE, '</5>', '</48>',
        '</N>', '</N>', true, false)
  end

  def self.make_graph(cdkscreen, x, y)
    values = [10, 15, 20, 25, 30, 35, 40, 45, 50, 55]
    graph_chars = '0123456789'
    widget = CDK::GRAPH.new(cdkscreen, x, y, 10, 25, 'title', 'X-axis',
        'Y-axis')
    widget.set(values, values.size, graph_chars, true, :PLOT)
    return widget
  end

  def self.make_histogram(cdkscreen, x, y)
    widget = CDK::HISTOGRAM.new(cdkscreen, x, y, 1, 20, CDK::HORIZONTAL,
        'Histogram', true, false)
    widget.set(:PERCENT, CDK::CENTER, Ncurses::A_BOLD, 0, 10, 6,
        ' '.ord | Ncurses::A_REVERSE, true)
    return widget
  end

  def self.make_itemlist(cdkscreen, x, y)
    return CDK::ITEMLIST.new(cdkscreen, x, y, '', 'Month',
        TraverseExample::MONTHS, TraverseExample::MONTHS.size, 1, true, false)
  end

  def self.make_label(cdkscreen, x, y)
    mesg = [
        'This is a simple label.',
        'Is it simple enough?',
    ]
    return CDK::LABEL.new(cdkscreen, x, y, mesg, mesg.size, true, true)
  end

  def self.make_marquee(cdkscreen, x, y)
    widget = CDK::MARQUEE.new(cdkscreen, x, y, 30, true, true)
    widget.activate('This is a message', 5, 3, true)
    widget.destroy
    return nil
  end

  def self.make_matrix(cdkscreen, x, y)
    numrows = 8
    numcols = 5
    coltitle = []
    rowtitle = []
    cols = numcols
    colwidth = []
    coltypes = []
    maxwidth = 0
    rows = numrows
    vcols = 3
    vrows = 3

    (0..numrows).each do |n|
      rowtitle << 'row%d' % [n]
    end

    (0..numcols).each do |n|
      coltitle << 'col%d' % [n]
      colwidth << coltitle[n].size
      coltypes << :UCHAR
      if colwidth[n] > maxwidth
        maxwidth = colwidth[n]
      end
    end

    return CDK::MATRIX.new(cdkscreen, x, y, rows, cols, vrows, vcols,
        'Matrix', rowtitle, coltitle, colwidth, coltypes, -1, -1, '.'.ord,
        CDK::COL, true, true, false)
  end

  def self.make_mentry(cdkscreen, x, y)
    return CDK::MENTRY.new(cdkscreen, x, y, 'MEntry', 'Label',
        Ncurses::A_BOLD, '.', :MIXED, 20, 5, 20, 0, true, false)
  end

  def self.make_radio(cdkscreen, x, y)
    return CDK::RADIO.new(cdkscreen, x, y, CDK::RIGHT, 10, 20, 'Radio',
        TraverseExample::MONTHS, TraverseExample::MONTHS.size,
        '#'.ord | Ncurses::A_REVERSE, 1, Ncurses::A_REVERSE, true, false)
  end

  def self.make_scale(cdkscreen, x, y)
    low = 2
    high = 25
    inc = 2
    return CDK::SCALE.new(cdkscreen, x, y, 'Scale', 'Label',
        Ncurses::A_NORMAL, 5, low, low, high, inc, (inc * 2), true, false)
  end

  def self.make_scroll(cdkscreen, x, y)
    return CDK::SCROLL.new(cdkscreen, x, y, CDK::RIGHT, 10, 20, 'Scroll',
        TraverseExample::MONTHS, TraverseExample::MONTHS.size,
        true, Ncurses::A_REVERSE, true, false)
  end

  def self.make_slider(cdkscreen, x, y)
    low = 2
    high = 25
    inc = 1
    return CDK::SLIDER.new(cdkscreen, x, y, 'Slider', 'Label',
        Ncurses::A_REVERSE | Ncurses.COLOR_PAIR(29) | ' '.ord,
        20, low, low, high, inc, (inc * 2), true, false)
  end

  def self.make_selection(cdkscreen, x, y)
    return CDK::SELECTION.new(cdkscreen, x, y, CDK::NONE, 8, 20,
        'Selection', TraverseExample::MONTHS, TraverseExample::MONTHS.size,
        TraverseExample::CHOICES, TraverseExample::CHOICES.size,
        Ncurses::A_REVERSE, true, false)
  end

  def self.make_swindow(cdkscreen, x, y)
    widget = CDK::SWINDOW.new(cdkscreen, x, y, 6, 25,
        'SWindow', 100, true, false)
    (0...30).each do |n|
      widget.add('Line %d' % [n], CDK::BOTTOM)
    end
    widget.activate([])
    return widget
  end

  def self.make_template(cdkscreen, x, y)
    overlay = '</B/6>(___)<!6> </5>___-____'
    plate = '(###) ###-####'
    widget = CDK::TEMPLATE.new(cdkscreen, x, y, 'Template', 'Label',
        plate, overlay, true, false)
    widget.activate([])
    return widget
  end

  def self.make_uscale(cdkscreen, x, y)
    low = 0
    high = 65535
    inc = 1
    return CDK::USCALE.new(cdkscreen, x, y, 'UScale', 'Label',
        Ncurses::A_NORMAL, 5, low, low, high, inc, (inc * 32), true, false)
  end

  def self.make_uslider(cdkscreen, x, y)
    low = 0
    high = 65535
    inc = 1
    return CDK::USLIDER.new(cdkscreen, x, y, 'USlider', 'Label',
        Ncurses::A_REVERSE | Ncurses.COLOR_PAIR(29) | ' '.ord, 20,
        low, low, high, inc, (inc * 32), true, false)
  end

  def self.make_viewer(cdkscreen, x, y)
    button = ['Ok']
    widget = CDK::VIEWER.new(cdkscreen, x, y, 10, 20, button, 1,
        Ncurses::A_REVERSE, true, false)

    widget.set('Viewer', TraverseExample::MONTHS, TraverseExample::MONTHS.size,
        Ncurses::A_REVERSE, false, true, true)
    widget.activate([])
    return widget
  end

  def self.rebind_esc(obj)
    obj.bind(obj.object_type, CDK::KEY_F(1), :getc, CDK::KEY_ESC)
  end

  def self.make_any(cdkscreen, menu, type)
    func = nil
    # setup positions, staggered a little
    case menu
    when 0
      x = CDK::LEFT
      y = 2
    when 1
      x = CDK::CENTER
      y = 4
    when 2
      x = CDK::RIGHT
      y = 2
    else
      CDK.Beep
      return
    end

    # Find the function to make a widget of the given type
    case type
    when :ALPHALIST
      func = :make_alphalist
    when :BUTTON
      func = :make_button
    when :BUTTONBOX
      func = :make_buttonbox
    when :CALENDAR
      func = :make_calendar
    when :DIALOG
      func = :make_dialog
    when :DSCALE
      func = :make_dscale
    when :ENTRY
      func = :make_entry
    when :FSCALE
      func = :make_fscale
    when :FSELECT
      func = :make_fselect
    when :FSLIDER
      func = :make_fslider
    when :GRAPH
      func = :make_graph
    when :HISTOGRAM
      func = :make_histogram
    when :ITEMLIST
      func = :make_itemlist
    when :LABEL
      func = :make_label
    when :MARQUEE
      func = :make_marquee
    when :MATRIX
      func = :make_matrix
    when :MENTRY
      func = :make_mentry
    when :RADIO
      func = :make_radio
    when :SCALE
      func = :make_scale
    when :SCROLL
      func = :make_scroll
    when :SELECTION
      func = :make_selection
    when :SLIDER
      func = :make_slider
    when :SWINDOW
      func = :make_swindow
    when :TEMPLATE
      func = :make_template
    when :USCALE
      func = :make_uscale
    when :USLIDER
      func = :make_uslider
    when :VIEWER
      func = :make_viewer
    when :MENU, :TRAVERSE, :NULL
      CDK.Beep
      return
    end

    # erase the old widget
    unless (prior = @@all_objects[menu]).nil?
      prior.erase
      prior.destroy
      @@all_objects[menu] = nil
    end

    # Create the new widget
    if func.nil?
      CDK.Beep
    else
      widget = self.send(func, cdkscreen, x, y)
      if widget.nil?
        Ncurses.flash
      else
        @@all_objects[menu] = widget
        self.rebind_esc(widget)
      end
    end
  end

  # Whenever we get a menu selection, create the selected widget.
  def self.preHandler(cdktype, object, client_data, input)
    screen = nil
    window = nil

    case input
    when Ncurses::KEY_ENTER, CDK::KEY_RETURN
      mtmp = []
      stmp = []
      object.getCurrentItem(mtmp, stmp)
      mp = mtmp[0]
      sp = stmp[0]

      screen = object.screen
      window = screen.window

      window.mvwprintw(window.getmaxy - 1, 0, 'selection %d/%d', mp, sp)
      Ncurses.clrtoeol
      Ncurses.refresh
      if sp >= 0 && sp < TraverseExample::MENU_TABLE.size
        self.make_any(screen, mp, TraverseExample::MENU_TABLE[sp][1])
      end
    end 
    return 1
  end
  
  # This demonstrates the Cdk widget-traversal
  def TraverseExample.main
    menulist = [['Left'], ['Center'], ['Right']]
    submenusize = [TraverseExample::MENU_TABLE.size + 1] * 3
    menuloc = [CDK::LEFT, CDK::LEFT, CDK::RIGHT]

    (0...TraverseExample::MY_MAX).each do |j|
      (0...TraverseExample::MENU_TABLE.size).each do |k|
        menulist[j] << TraverseExample::MENU_TABLE[k][0]
      end
    end

    # Create the curses window.
    curses_win = Ncurses.initscr
    cdkscreen = CDK::SCREEN.new(curses_win)

    # Start CDK colours.
    CDK::Draw.initCDKColor

    menu = CDK::MENU.new(cdkscreen, menulist, TraverseExample::MY_MAX,
        submenusize, menuloc, CDK::TOP, Ncurses::A_UNDERLINE,
        Ncurses::A_REVERSE)

    if menu.nil?
      cdkscreen.destroy
      CDK::SCREEN.endCDK

      puts '? Cannot create menus'
      exit  # EXIT_FAILURE
    end
    TraverseExample.rebind_esc(menu)

    pre_handler = lambda do |cdktype, object, client_data, input|
      TraverseExample.preHandler(cdktype, object, client_data, input)
    end

    menu.setPreProcess(pre_handler, nil)

    # Set up the initial display
    TraverseExample.make_any(cdkscreen, 0, :ENTRY)
    if TraverseExample::MY_MAX > 1
      TraverseExample.make_any(cdkscreen, 1, :ITEMLIST)
    end
    if TraverseExample::MY_MAX > 2
      TraverseExample.make_any(cdkscreen, 2, :SELECTION)
    end

    # Draw the screen
    cdkscreen.refresh

    # Traverse the screen
    CDK::Traverse.traverseCDKScreen(cdkscreen)

    mesg = [
        'Done',
        '',
        '<C>Press any key to continue'
    ]
    cdkscreen.popupLabel(mesg, 3)

    # clean up and exit
    (0...TraverseExample::MY_MAX).each do |j|
      if j < @@all_objects.size && !(@@all_objects[j]).nil?
        @@all_objects[j].destroy
      end
    end
    menu.destroy
    cdkscreen.destroy
    CDK::SCREEN.endCDK

    exit  # EXIT_SUCCESS
  end
end

TraverseExample.main
