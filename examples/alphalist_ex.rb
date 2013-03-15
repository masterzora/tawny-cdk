#!/usr/bin/env ruby
require 'etc'
require_relative 'example'

class AlphalistExample < CLIExample
  @@my_undo_list = []
  @@my_user_list = []

  def AlphalistExample.getUserList(list)
    while (ent = Etc.getpwent)
      list << ent.name
    end
    Etc.endpwent
    list.sort!

    return list.size
  end

  def AlphalistExample.fill_undo(widget, deleted, data)
    top = widget.scroll_field.getCurrentTop
    item = widget.getCurrentItem

    undo = OpenStruct.new
    undo.deleted = deleted
    undo.topline = top
    undo.original = -1
    undo.position = item

    @@my_undo_list << undo
    (0...@@my_user_list.size).each do |n|
      if @@my_user_list[n] == data
        @@my_undo_list[-1].original = n
        break
      end
    end
  end

  def AlphalistExample.parse_opts(opts, params)
    opts.banner = 'Usage: alpha_ex.rb [options]'

    # default values
    params.box = true
    params.shadow = false
    params.x_value = CDK::CENTER
    params.y_value = CDK::CENTER
    params.h_value = 0
    params.w_value = 0
    params.c = false

    super(opts, params)

    opts.on('-c', 'create the data after the widget') do
      params.c = true
    end
  end

  # This program demonstrates the Cdk alphalist widget.
  #
  # Options (in addition to normal CLI parameters):
  #   -c      create the data after the widget
  def AlphalistExample.main
    params = parse(ARGV)
    title = "<C></B/24>Alpha List\n<C>Title"
    label = "</B>Account: "
    word = ''
    user_list = []

    # Get the user list.
    user_size = AlphalistExample.getUserList(user_list)

    if user_size <= 0
      $stderr.puts "Cannot get user list"
      exit  # EXIT_FAILURE
    end

    @@my_user_list = user_list.clone

    # Set up CDK
    curses_win = Ncurses.initscr
    cdkscreen = CDK::SCREEN.new(curses_win)

    # Set up CDK colors
    CDK::Draw.initCDKColor

    # Create the alphalist list.
    alpha_list = CDK::ALPHALIST.new(cdkscreen,
        params.x_value, params.y_value, params.h_value, params.w_value,
        title, label,
        if params.c then nil else user_list end,
        if params.c then 0 else user_size end,
        '_', Ncurses::A_REVERSE, params.box, params.shadow)

    if alpha_list.nil?
      cdkscreen.destroy
      CDK::SCREEN.endCDK

      $stderr.puts "Cannot create widget."
      exit #EXIT_FAILURE
    end

    do_delete = lambda do |cdktype, object, widget, key|
      size = []
      list = widget.getContents(size)
      size = size[0]
      result = false

      if size > 0
        save = widget.scroll_field.getCurrentTop
        first = widget.getCurrentItem

        AlphalistExample.fill_undo(widget, first, list[first])
        list = list[0...first] + list[first+1..-1]
        widget.setContents(list, size - 1)
        widget.scroll_field.setCurrentTop(save)
        widget.setCurrentItem(first)
        widget.draw(widget.border_size)
        result = true
      end
      return result
    end

    do_delete1 = lambda do |cdktype, object, widget, key|
      size = []
      list = widget.getContents(size)
      size = size[0]
      result = false

      if size > 0
        save = widget.scroll_field.getCurrentTop
        first = widget.getCurrentItem

        first -= 1
        if first + 1 > 0
          AlphalistExample.fill_undo(widget, first, list[first])
          list = list[0...first] + list[first+1..-1]
          widget.setContents(list, size - 1)
          widget.scroll_field.setCurrentTop(save)
          widget.setCurrentItem(first)
          widget.draw(widget.border_size)
          result = true
        end
      end
      return result
    end

    do_help = lambda do |cdktype, object, client_data, key|
      message = [
          'Alpha List tests:',
          '',
          'F1 = help (this message)',
          'F2 = delete current item',
          'F3 = delete previous item',
          'F4 = reload all items',
          'F5 = undo deletion',
      ]
      cdkscreen.popupLabel(message, message.size)
      return true
    end

    do_reload = lambda do |cdktype, object, widget, key|
      result = false

      if @@my_user_list.size > 0
        widget.setContents(@@my_user_list, @@my_user_list.size)
        widget.setCurrentItem(0)
        widget.draw(widget.border_size)
        result = true
      end
      return result
    end

    do_undo = lambda do |cdktype, object, widget, key|
      result = false
      if @@my_undo_list.size > 0
        size = []
        oldlist = widget.getContents(size)
        size = size[0] + 1
        deleted = @@my_undo_list[-1].deleted
        original = @@my_user_list[@@my_undo_list[-1].original]
        newlist = oldlist[0..deleted-1] + [original] + oldlist[deleted..-1]
        widget.setContents(newlist, size)
        widget.scroll_field.setCurrentTop(@@my_undo_list[-1].topline)
        widget.setCurrentItem(@@my_undo_list[-1].position)
        widget.draw(widget.border_size)
        @@my_undo_list = @@my_undo_list[0...-1]
        result = true
      end
      return result
    end

    alpha_list.bind(:ALPHALIST, '?', do_help, nil)
    alpha_list.bind(:ALPHALIST, CDK::KEY_F(1), do_help, nil)
    alpha_list.bind(:ALPHALIST, CDK::KEY_F(2), do_delete, alpha_list)
    alpha_list.bind(:ALPHALIST, CDK::KEY_F(3), do_delete1, alpha_list)
    alpha_list.bind(:ALPHALIST, CDK::KEY_F(4), do_reload, alpha_list)
    alpha_list.bind(:ALPHALIST, CDK::KEY_F(5), do_undo, alpha_list)

    if params.c
      alpha_list.setContents(user_list, user_size)
    end

    # Let them play with the alpha list.
    word = alpha_list.activate([])

    # Determine what the user did.
    if alpha_list.exit_type == :ESCAPE_HIT
      mesg = [
          '<C>You hit escape. No word was selected.',
          '',
          '<C>Press any key to continue.'
      ]
      cdkscreen.popupLabel(mesg, 3)
    elsif alpha_list.exit_type == :NORMAL
      mesg = ['<C>You selected the following',
          "<C>(%.*s)" % [246, word],  # FIXME magic number
          '',
          '<C>Press any key to continue.'
      ]
      cdkscreen.popupLabel(mesg, 4);
    end

    # Clean up.
    alpha_list.destroy
    cdkscreen.destroy
    CDK::SCREEN.endCDK
    exit  # EXIT_SUCCESS
  end
end

AlphalistExample.main
