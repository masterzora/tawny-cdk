#!/usr/bin/env ruby
require 'optparse'
require 'fileutils'
require_relative '../lib/cdk'

class Vinstall
  FPUsage = '-f filename [-s source directory] [-d destination directory]' <<
      ' [-t title] [-o Output file] [q]'

  # Copy the file.
  def Vinstall.copyFile(cdkscreen, src, dest)
    # TODO: error handling
    FileUtils.cp(src, dest)
    return :OK
  end

  # This makes sure the given directory exists.  If it doesn't then it will
  # make it.
  def Vinstall.verifyDirectory(cdkscreen, directory)
    status = 0
    buttons = [
        'Yes',
        'No',
    ]
    if !(Dir.exists?(directory))
      # Create the question.
      mesg = [
          '<C>The directory',
          '<C>%.256s' % [directory],
          '<C>Does not exist. Do you want to',
          '<C>create it?',
      ]

      # Ask them if they want to create the directory.
      if cdkscreen.popupDialog(mesg, mesg.size, buttons, buttons.size) == 0
        # TODO error handling
        if Dir.mkdir(directory, 0754) != 0
          # Create the error message.
          error = [
              '<C>Could not create the directory',
              '<C>%.256s' % [directory],
              #'<C>%.256s' % [strerror (errno)]
              '<C>Check the permissions and try again.',
          ]

          # Pop up the error message.
          cdkscreen.popupLabel(error, error.size)

          status = -1
        end
      else
        # Create the message
        error = ['<C>Installation aborted.']

        # Pop up the error message.
        cdkscreen.popupLabel(error, error.size)

        status = -1
      end
    end
    return status
  end

  def Vinstall.main
    source_path = ''
    dest_path = ''
    filename = ''
    title = ''
    output = ''
    quiet = false

    # Check the command line for options
    opts = OptionParser.getopts('d:s:f:t:o:q')
    if opts['d']
      dest_path = opts['d']
    end
    if opts['s']
      source_path = opts['s']
    end
    if opts['f']
      filename = opts['f']
    end
    if opts['t']
      title = opts['t']
    end
    if opts['o']
      output = opts['o']
    end
    if opts['q']
      quiet = true
    end

    # Make sure we have everything we need.
    if filename == ''
      $stderr.puts 'Usage: %s %s' % [File.basename($PROGRAM_NAME), Vinstall::FPUsage]
      exit  # EXIT_FAILURE
    end

    file_list = []
    # Open the file list file and read it in.
    count = CDK.readFile(filename, file_list)
    if count == 0
      $stderr.puts '%s: Input filename <%s> is empty.' % [ARGV[0], filename]
    end

    # Cycle through what was given to us and save it.
    file_list.each do |file|
      file.strip!
    end
    
    # Set up CDK
    curses_win = Ncurses.initscr
    cdkscreen = CDK::SCREEN.new(curses_win)

    # Set up CDK colors
    CDK::Draw.initCDKColor

    # Create the title label.
    title_mesg = [
        '<C></32/B<#HL(30)>',
        if title == ''
        then '<C></32/B>CDK Installer'
        else '<C></32/B>%.256s' % [title]
        end,
        '<C></32/B><#HL(30)>'
    ]
    title_win = CDK::LABEL.new(cdkscreen, CDK::CENTER, CDK::TOP,
        title_mesg, 3, false, false)

    source_entry = nil
    dest_entry = nil

    # Allow them to change the install directory.
    if source_path == ''
      source_entry = CDK::ENTRY.new(cdkscreen, CDK::CENTER, 8, '',
          'Source Directory        :', Ncurses::A_NORMAL, '.'.ord,
          :MIXED, 40, 0, 256, true, false)
    end

    if dest_path == ''
      dest_entry = CDK::ENTRY.new(cdkscreen, CDK::CENTER, 11, '',
          'Destination Directory:', Ncurses::A_NORMAL, '.'.ord, :MIXED,
          40, 0, 256, true, false)
    end

    # Get the source install path.
    source_dir = source_path
    unless source_entry.nil?
      cdkscreen.draw
      source_dir = source_entry.activate([])
    end

    # Get the destination install path.
    dest_dir = dest_path
    unless dest_entry.nil?
      cdkscreen.draw
      dest_dir = dest_entry.activate([])
    end

    # Destroy the path entry fields.
    unless source_entry.nil?
      source_entry.destroy
    end
    unless dest_entry.nil?
      dest_entry.destroy
    end

    # Verify that the source directory is valid.
    if Vinstall.verifyDirectory(cdkscreen, source_dir) != 0
      # Clean up and leave.
      title_win.destroy
      cdkscreen.destroy
      CDK::SCREEN.endCDK
      exit  # EXIT_FAILURE
    end

    # Verify that the destination directory is valid.
    if Vinstall.verifyDirectory(cdkscreen, dest_dir) != 0
      title_win.destroy
      cdkscreen.destroy
      CDK::SCREEN.endCDK
      exit  # EXIT_FAILURE
    end

    # Create the histogram.
    progress_bar = CDK::HISTOGRAM.new(cdkscreen, CDK::CENTER, 5, 3, 0,
        CDK::HORIZONTAL, '<C></56/B>Install Progress', true, false)

    # Set the top left/right characters of the histogram.
    progress_bar.setLLchar(Ncurses::ACS_LTEE)
    progress_bar.setLRchar(Ncurses::ACS_RTEE)

    # Set the initial value fo the histgoram.
    progress_bar.set(:PERCENT, CDK::TOP, Ncurses::A_BOLD, 1, count, 1,
        Ncurses.COLOR_PAIR(24) | Ncurses::A_REVERSE | ' '.ord, true)

    # Determine the height of the scrolling window.
    swndow_height = 3
    if Ncurses.LINES >= 16
      swindow_height = Ncurses.LINES - 13
    end

    # Create the scrolling window.
    install_output = CDK::SWINDOW.new(cdkscreen, CDK::CENTER, CDK::BOTTOM,
        swindow_height, 0, '<C></56/B>Install Results', 2000, true, false)

    # Set the top left/right characters of the scrolling window.
    install_output.setULchar(Ncurses::ACS_LTEE)
    install_output.setURchar(Ncurses::ACS_RTEE)

    # Draw the screen.
    cdkscreen.draw

    errors = 0

    # Start copying the files.
    (0...count).each do |x|
      # If the 'file' list file has 2 columns, the first is the source
      # filename, the second being the destination
      files = file_list[x].split
      old_path = '%s/%s' % [source_dir, file_list[x]]
      new_path = '%s/%s' % [dest_dir, file_list[x]]
      if files.size == 2
        # Create the correct paths.
        old_path = '%s/%s' % [source_dir, files[0]]
        new_path = '%s/%s' % [dest_dir, files[1]]
      end

      # Copy the file from the source to the destiation.
      ret = Vinstall.copyFile(cdkscreen, old_path, new_path)
      temp = ''
      if ret == :CanNotOpenSource
        temp = '</16>Error: Can not open source file "%.256s"<!16>' % [old_path]
        errors += 1
      elsif ret == :CanNotOpenDest
        temp = '</16>Error: Can not open destination file "%.256s"<!16>' %
            [new_path]
        errors += 1
      else
        temp = '</25>%.256s -> %.256s' % [old_path, new_path]
      end

      # Add the message to the scrolling window.
      install_output.add(temp, CDK::BOTTOM)
      install_output.draw(install_output.box)

      # Update the histogram.
      progress_bar.set(:PERCENT, CDK::TOP, Ncurses::A_BOLD, 1, count,
          x + 1, Ncurses.COLOR_PAIR(24) | Ncurses::A_REVERSE | ' '.ord, true)

      # Update the screen.
      progress_bar.draw(true)
    end

    # If there were errors, inform the user and allow them to look at the
    # errors in the scrolling window.
    if errors > 0
      # Create the information for the dialog box.
      buttons = [
          'Look At Errors Now',
          'Save Output To A File',
          'Ignore Errors',
      ]
      mesg = [
          '<C>There were errors in the installation.',
          '<C>If you want, you may scroll through the',
          '<C>messages of the scrolling window to see',
          '<C>what the errors were. If you want to save',
          '<C>the output of the window you may press</R>s<!R>',
          '<C>while in the window, or you may save the output',
          '<C>of the install now and look at the install',
          '<C>histoyr at a later date.'
      ]

      # Popup the dialog box.
      ret = cdkscreen.popupDialog(mesg, mesg.size, buttons, buttons.size)

      if ret == 0
        install_output.activate([])
      elsif ret == 1
        install_output.inject('s'.ord)
      end
    else
      # If they specified the name of an output file, then save the
      # results of the installation to that file.
      if output != ''
        install_output.dump(output)
      else
        # Ask them if they want to save the output of the scrolling window.
        if quiet == false
          buttons = [
              'No',
              'Yes',
          ]
          mesg = [
              '<C>Do you want to save the output of the',
              '<C>scrolling window to a file?',
          ]

          if cdkscreen.popupDialog(mesg, 2, buttons, 2) == 1
            install_output.inject('s'.ord)
          end
        end
      end
    end

    # Clean up.
    title_win.destroy
    progress_bar.destroy
    install_output.destroy
    cdkscreen.destroy
    CDK::SCREEN.endCDK
    exit  # EXIT_SUCCESS
  end
end

Vinstall.main
