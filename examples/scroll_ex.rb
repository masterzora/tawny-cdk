#!/usr/bin/env ruby
require './example'

class ScrollExample < CLIExample
  @@count = 0
  def ScrollExample.newLabel(prefix)
    result = "%s%d" % [prefix, @@count]
    @@count += 1
    return result
  end

  def ScrollExample.parse_opts(opts, params)
    opts.banner = 'Usage: scroll_ex.rb [options]'

    # default values
    params.box = true
    params.shadow = false
    params.x_value = CDK::CENTER
    params.y_value = CDK::CENTER
    params.h_value = 10
    params.w_value = 50
    params.c = false
    params.spos = CDK::RIGHT
    params.title = "<C></5>Pick a file"

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

  # This program demonstrates the Cdk scrolling list widget.
  #
  # Options (in addition to normal CLI parameters):
  #   -c      create the data after the widget
  #   -s SPOS location for the scrollbar
  #   -t TEXT title for the widget
  def ScrollExample.main
    # Declare variables.
    temp = ''

    params = parse(ARGV)

    # Set up CDK
    curses_win = Ncurses.initscr
    cdkscreen = CDK::SCREEN.new(curses_win)

    # Set up CDK colors
    CDK::Draw.initCDKColor

    # Use the current directory list to fill the radio list
    item = []
    count = CDK.getDirectoryContents(".", item)

    # Create the scrolling list.
    scroll_list = CDK::SCROLL.new(cdkscreen,
        params.x_value, params.y_value, params.spos,
        params.h_value, params.w_value, params.title,
        if params.c then nil else item end,
        if params.c then 0 else count end,
        true, Ncurses::A_REVERSE, params.box, params.shadow)

    if scroll_list.nil?
      cdkscreen.destroyCDKScreen
      CDK::SCREEN.endCDK
      r

      puts "Cannot make scrolling list.  Is the window too small?"
      exit #EXIT_FAILURE
    end

    if params.c
      scroll_list.setCDKScrollItems(item, count, true)
    end

  #def ScrollExample.addItemCB(cdktype, object, client_data, input)
  #  object.addCDKScrollItem(ScrollExample.newLabel("add"))
  #  object.screen.refreshCDKScreen
  #  return true
  #end
    addItemCB = lambda do |type, object, client_data, input|
      object.addCDKScrollItem(ScrollExample.newLabel("add"))
      object.screen.refresh
      return true
    end
  #def ScrollExample.insItemCB(cdktype, object, client_data, input)
  #  object.insertCDKScrollItem(ScrollExample.newLabel("insert"))
  #  object.screen.refreshCDKScreen
  #  return true
  #end
    insItemCB = lambda do |type, object, client_data, input|
      object.insertCDKScrollItem(ScrollExample.newLabel("insert"))
      object.screen.refresh
      return true
    end

  #def ScrollExample.delItemCB(cdktype, object, client_data, input)
  #  object.deleteCDKScrollItem(object.getCDKScrollCurrent)
  #  object.screen.refreshCDKScreen
  #  return true
  #end
    delItemCB = lambda do |type, object, client_data, input|
      object.deleteCDKScrollItem(object.getCDKScrollCurrentItem)
      object.screen.refresh
      return true
    end

    scroll_list.bind(:SCROLL, 'a', addItemCB, nil)
    scroll_list.bind(:SCROLL, 'i', insItemCB, nil);
    scroll_list.bind(:SCROLL, 'd', delItemCB, nil);
    
    # Activate the scrolling list.
    
    selection = scroll_list.activate('')

    # Determine how the widget was exited
    if scroll_list.exit_type == :ESCAPE_HIT
      msg = ['<C>You hit escape. No file selected']
      msg << ''
      msg << '<C>Press any key to continue.'
      cdkscreen.popupLabel(msg, 3)
    elsif scroll_list.exit_type == :NORMAL
      the_item = CDK.chtype2Char(scroll_list.item[selection])
      msg = ['<C>You selected the following file',
          "<C>%.*s" % [236, the_item],  # FIXME magic number
          "<C>Press any key to continue."
      ]
      cdkscreen.popupLabel(msg, 3);
      #freeChar (theItem);
    end

    # Clean up.
    # CDKfreeStrings (item);
    scroll_list.destroy
    cdkscreen.destroy
    CDK::SCREEN.endCDK
    exit #EXIT_SUCCESS
  end
end

ScrollExample.main
