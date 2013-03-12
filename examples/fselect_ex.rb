#!/usr/bin/env ruby
require './example'
require 'etc'

class FselectExample < CLIExample
  @@my_undo_list = []
  @@my_user_list = []

  def FselectExample.getUserList(list)
    while (ent = Etc.getpwent)
      list << ent.name
    end
    Etc.endpwent
    list.sort!

    return list.size
  end

  def FselectExample.fill_undo(widget, deleted, data)
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

  def FselectExample.parse_opts(opts, params)
    opts.banner = 'Usage: alpha_ex.rb [options]'

    # default values
    params.box = true
    params.shadow = false
    params.x_value = CDK::CENTER
    params.y_value = CDK::CENTER
    params.h_value = 20
    params.w_value = 65
    params.dir = '.'

    super(opts, params)

    opts.on('-d DIR', String, 'default directory') do |dir|
      params.dir = dir
    end
  end

  # This program demonstrates the Cdk alphalist widget.
  #
  # Options (in addition to normal CLI parameters):
  #   -c      create the data after the widget
  def FselectExample.main
    params = parse(ARGV)
    title = "<C>Pick\n<C>A\n<C>File"
    label = "File: "
    button = [
        '</5><OK><!5>',
        '</5><Cancel><!5>'
    ]

    # Set up CDK
    curses_win = Ncurses.initscr
    cdkscreen = CDK::SCREEN.new(curses_win)

    # Set up CDK colors
    CDK::Draw.initCDKColor

    # Get the filename.
    fselect = CDK::FSELECT.new(cdkscreen, params.x_value, params.y_value,
        params.h_value, params.w_value, title, label, Ncurses::A_NORMAL,
        '_', Ncurses::A_REVERSE, "</5>", "</48>", "</N>", "</N>",
        params.box, params.shadow)

    if fselect.nil?
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

        FselectExample.fill_undo(widget, first, list[first])
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
          FselectExample.fill_undo(widget, first, list[first])
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
          'File Selection tests:',
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

    fselect.bind(:FSELECT, '?', do_help, nil)
    fselect.bind(:FSELECT, CDK::KEY_F(1), do_help, nil)
    fselect.bind(:FSELECT, CDK::KEY_F(2), do_delete, fselect)
    fselect.bind(:FSELECT, CDK::KEY_F(3), do_delete1, fselect)
    fselect.bind(:FSELECT, CDK::KEY_F(4), do_reload, fselect)
    fselect.bind(:FSELECT, CDK::KEY_F(5), do_undo, fselect)

    # Set the starting directory. This is not necessary because when
    # the file selector starts it uses the present directory as a default.
    fselect.set(params.dir, Ncurses::A_NORMAL, ' ', Ncurses::A_REVERSE,
        "</5>", "</48>", "</N>", "</N>", fselect.box)
    @@my_user_list = fselect.getContents([]).clone
    @@my_undo_list = []

    # Activate the file selector.
    filename = fselect.activate([])

    # Check how the person exited from the widget.
    if fselect.exit_type == :ESCAPE_HIT
      mesg = [
          '<C>Escape hit. No file selected.',
          '',
          '<C>Press any key to continue.'
      ]
      cdkscreen.popupLabel(mesg, 3)

      # Exit CDK.
      fselect.destroy
      cdkscreen.destroy
      CDK::SCREEN.endCDK
      exit  # EXIT_SUCCESS
    end

    # Create the file viewer to view the file selected.
    example = CDK::VIEWER.new(cdkscreen, CDK::CENTER, CDK::CENTER, 20, -2,
        button, 2, Ncurses::A_REVERSE, true, false)

    # Could we create the viewer widget?
    if example.nil?
      # Exit CDK.
      fselect.destroy
      cdkscreen.destroy
      CDK::SCREEN.endCDK

      puts "Can't seem to create viewer. Is the window too small?"
      exit  # EXIT_SUCCESS
    end

    # Open the file and read the contents.
    info = []
    lines = CDK::readFile(filename, info)
    if lines == -1
      fselect.destroy
      cdkscreen.destroy
      CDK::SCREEN.endCDK

      puts "Coult not open \"%s\"" % [filename]

      exit  # EXIT_FAILURE
    end

    # Set up the viewer title and the contents to the widget.
    vtitle = "<C></B/21>Filename:<!21></22>%20s<!22!B>" % [filename]
    example.set(vtitle, info, lines, Ncurses::A_REVERSE, true, true, true)

    # Destroy the file selector widget.
    fselect.destroy

    # Activate the viewer widget.
    selected = example.activate([])

    # Check how the person exited from the widget.
    if example.exit_type == :ESCAPE_HIT
      mesg = [
          "<C>Escape hit. No Button selected.",
          "",
          "<C>Press any key to continue."
      ]
      cdkscreen.popupLabel(mesg, 3)
    elsif example.exit_type == :NORMAL
      mesg = [
          '<C>You selected button %d' % [selected],
          '',
          '<C>Press any key to continue.'
      ]
      cdkscreen.popupLabel(mesg, 3)
    end

    # Clean up.
    example.destroy
    cdkscreen.destroy
    CDK::SCREEN.endCDK
    exit  # EXIT_SUCCESS
  end
end

FselectExample.main
