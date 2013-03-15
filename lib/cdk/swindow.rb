require_relative 'cdk_objs'

module CDK
  class SWINDOW < CDK::CDKOBJS
    def initialize(cdkscreen, xplace, yplace, height, width, title,
        save_lines, box, shadow)
      super()
      parent_width = cdkscreen.window.getmaxx
      parent_height = cdkscreen.window.getmaxy
      box_width = width
      box_height = height
      bindings = {
        CDK::BACKCHAR => Ncurses::KEY_PPAGE,
        'b'           => Ncurses::KEY_PPAGE,
        'B'           => Ncurses::KEY_PPAGE,
        CDK::FORCHAR  => Ncurses::KEY_NPAGE,
        ' '           => Ncurses::KEY_NPAGE,
        'f'           => Ncurses::KEY_NPAGE,
        'F'           => Ncurses::KEY_NPAGE,
        '|'           => Ncurses::KEY_HOME,
        '$'           => Ncurses::KEY_END,
      }

      self.setBox(box)

      # If the height is a negative value, the height will be
      # ROWS-height, otherwise the height will be the given height.
      box_height = CDK.setWidgetDimension(parent_height, height, 0)

      # If the width is a negative value, the width will be
      # COLS-width, otherwise the widget will be the given width.
      box_width = CDK.setWidgetDimension(parent_width, width, 0)
      box_width = self.setTitle(title, box_width)

      # Set the box height.
      box_height += @title_lines + 1

      # Make sure we didn't extend beyond the dimensions of the window.
      box_width = [box_width, parent_width].min
      box_height = [box_height, parent_height].min

      # Set the rest of the variables.
      @title_adj = @title_lines + 1

      # Rejustify the x and y positions if we need to.
      xtmp = [xplace]
      ytmp = [yplace]
      CDK.alignxy(cdkscreen.window, xtmp, ytmp, box_width, box_height)
      xpos = xtmp[0]
      ypos = ytmp[0]

      # Make the scrolling window.
      @win = Ncurses::WINDOW.new(box_height, box_width, ypos, xpos)
      if @win.nil?
        self.destroy
        return nil
      end
      @win.keypad(true)

      # Make the field window
      @field_win = @win.subwin(box_height - @title_lines - 2, box_width - 2,
          ypos + @title_lines + 1, xpos + 1)
      @field_win.keypad(true)

      # Set the rest of the variables
      @screen = cdkscreen
      @parent = cdkscreen.window
      @shadow_win = nil
      @box_height = box_height
      @box_width = box_width
      @view_size = box_height - @title_lines - 2
      @current_top = 0
      @max_top_line = 0
      @left_char = 0
      @max_left_char = 0
      @list_size = 0
      @widest_line = -1
      @save_lines = save_lines
      @accepts_focus = true
      @input_window = @win
      @shadow = shadow

      if !self.createList(save_lines)
        self.destroy
        return nil
      end

      # Do we need to create a shadow?
      if shadow
        @shadow_win = Ncurses::WINDOW.new(box_height, box_width,
            ypos + 1, xpos + 1)
      end

      # Create the key bindings
      bindings.each do |from, to|
        self.bind(:SWINDOW, from, :getc, to)
      end

      # Register this baby.
      cdkscreen.register(:SWINDOW, self)
    end

    # This sets the lines and the box attribute of the scrolling window.
    def set(list, lines, box)
      self.setContents(list, lines)
      self.setBox(box)
    end

    def setupLine(list, x)
      list_len = []
      list_pos = []
      @list[x] = CDK.char2Chtype(list, list_len, list_pos)
      @list_len[x] = list_len[0]
      @list_pos[x] = CDK.justifyString(@box_width, list_len[0], list_pos[0])
      @widest_line = [@widest_line, @list_len[x]].max
    end

    # This sets all the lines inside the scrolling window.
    def setContents(list, list_size)
      # First let's clean all the lines in the window.
      self.clean
      self.createList(list_size)

      # Now let's set all the lines inside the window.
      (0...list_size).each do |x|
        self.setupLine(list[x], x)
      end

      # Set some more important members of the scrolling window.
      @list_size = list_size
      @max_top_line = @list_size - @view_size
      @max_top_line = [@max_top_line, 0].max
      @max_left_char = @widest_line - (@box_width - 2)
      @current_top = 0
      @left_char = 0
    end

    def getContents(size)
      size << @list_size
      return @list
    end

    def freeLine(x)
    #  if x < @list_size
    #    @list[x] = 0
    #  end
    end

    # This adds a line to the scrolling window.
    def add(list, insert_pos)
      # If we are at the maximum number of save lines erase the first
      # position and bump everything up one spot
      if @list_size == @save_lines and @list_size > 0
        @list = @list[1..-1]
        @list_pos = @list_pos[1..-1]
        @list_len = @list_len[1..-1]
        @list_size -= 1
      end

      # Determine where the line is being added.
      if insert_pos == CDK::TOP
        # We need to 'bump' everything down one line...
        @list = [@list[0]] + @list
        @list_pos = [@list_pos[0]] + @list_pos
        @list_len = [@list_len[0]] + @list_len

        # Add it into the scrolling window.
        self.setupLine(list, 0)

        # set some variables.
        @current_top = 0
        if @list_size < @save_lines
          @list_size += 1
        end

        # Set the maximum top line.
        @max_top_line = @list_size - @view_size
        @max_top_line = [@max_top_line, 0].max

        @max_left_char = @widest_line - (@box_width - 2)
      else
        # Add to the bottom.
        @list += ['']
        @list_pos += [0]
        @list_len += [0]
        self.setupLine(list, @list_size)
        
        @max_left_char = @widest_line - (@box_width - 2)

        # Increment the item count and zero out the next row.
        if @list_size < @save_lines
          @list_size += 1
          self.freeLine(@list_size)
        end

        # Set the maximum top line.
        if @list_size <= @view_size
          @max_top_line = 0
          @current_top = 0
        else
          @max_top_line = @list_size - @view_size
          @current_top = @max_top_line
        end
      end

      # Draw in the list.
      self.drawList(@box)
    end

    # This jumps to a given line.
    def jumpToLine(line)
      # Make sure the line is in bounds.
      if line == CDK::BOTTOM || line >= @list_size
        # We are moving to the last page.
        @current_top = @list_size - @view_size
      elsif line == TOP || line <= 0
        # We are moving to the top of the page.
        @current_top = 0
      else
        # We are moving in the middle somewhere.
        if @view_size + line < @list_size
          @current_top = line
        else
          @current_top = @list_size - @view_size
        end
      end

      # A little sanity check to make sure we don't do something silly
      if @current_top < 0
        @current_top = 0
      end

      # Redraw the window.
      self.draw(@box)
    end

    # This removes all the lines inside the scrolling window.
    def clean
      # Clean up the memory used...
      (0...@list_size).each do |x|
        self.freeLine(x)
      end

      # Reset some variables.
      @list_size = 0
      @max_left_char = 0
      @widest_line = 0
      @current_top = 0
      @max_top_line = 0

      # Redraw the window.
      self.draw(@box)
    end

    # This trims lines from the scrolling window.
    def trim(begin_line, end_line)
      # Check the value of begin_line
      if begin_line < 0
        start = 0
      elsif begin_line >= @list_size
        start = @list_size - 1
      else
        start = begin_line
      end

      # Check the value of end_line
      if end_line < 0
        finish = 0
      elsif end_line >= @list_size
        finish = @list_size - 1
      else
        finish = end_line
      end

      # Make sure the start is lower than the end.
      if start > finish
        return
      end

      # Start nuking elements from the window
      (start..finish).each do |x|
        self.freeLine(x)

        if x < list_size - 1
          @list[x] = @list[x + 1]
          @list_pos[x] = @list_pos[x + 1]
          @list_len[x] = @list_len[x + 1]
        end
      end

      # Adjust the item count correctly.
      @list_size = @list_size - (end_line - begin_line) - 1

      # Redraw the window.
      self.draw(@box)
    end

    # This allows the user to play inside the scrolling window.
    def activate(actions)
      # Draw the scrolling list.
      self.draw(@box)

      if actions.nil? || actions.size == 0
        while true
          input = self.getch([])

          # inject the character into the widget.
          self.inject(input)
          if @exit_type != :EARLY_EXIT
            return
          end
        end
      else
        #Inject each character one at a time
        actions.each do |action|
          self.inject(action)
          if @exit_type != :EARLY_EXIT
            return
          end
        end
      end

      # Set the exit type and return.
      self.setExitType(0)
    end

    # This injects a single character into the widget.
    def inject(input)
      pp_return = 1
      ret = -1
      complete = false

      # Set the exit type.
      self.setExitType(0)

      # Draw the window....
      self.draw(@box)

      # Check if there is a pre-process function to be called.
      unless @pre_process_func.nil?
        # Call the pre-process function.
        pp_return = @pre_process_func.call(:SWINDOW, self,
            @pre_process_data, input)
      end

      # Should we continue?
      if pp_return != 0
        # Check for a key binding.
        if self.checkBind(:SWINDOW, input)
          complete = true
        else
          case input
          when Ncurses::KEY_UP
            if @current_top > 0
              @current_top -= 1
            else
              CDK.Beep
            end
          when Ncurses::KEY_DOWN
            if @current_top >= 0 && @current_top < @max_top_line
              @current_top += 1
            else
              CDK.Beep
            end
          when Ncurses::KEY_RIGHT
            if @left_char < @max_left_char
              @left_char += 1
            else
              CDK.Beep
            end
          when Ncurses::KEY_LEFT
            if @left_char > 0
              @left_char -= 1
            else
              CDK.Beep
            end
          when Ncurses::KEY_PPAGE
            if @current_top != 0
              if @current_top >= @view_size
                @current_top = @current_top - (@view_size - 1)
              else
                @current_top = 0
              end
            else
              CDK.Beep
            end
          when Ncurses::KEY_NPAGE
            if @current_top != @max_top_line
              if @current_top + @view_size < @max_top_line
                @current_top = @current_top + (@view_size - 1)
              else
                @current_top = @max_top_line
              end
            else
              CDK.Beep
            end
          when Ncurses::KEY_HOME
            @left_char = 0
          when Ncurses::KEY_END
            @left_char = @max_left_char + 1
          when 'g'.ord, '1'.ord, '<'.ord
            @current_top = 0
          when 'G'.ord, '>'.ord
            @current_top = @max_top_line
          when 'l'.ord, 'L'.ord
            self.loadInformation
          when 's'.ord, 'S'.ord
            self.saveInformation
          when CDK::KEY_TAB, CDK::KEY_RETURN, Ncurses::KEY_ENTER
            self.setExitType(input)
            ret = 1
            complete = true
          when CDK::KEY_ESC
            self.setExitType(input)
            complete = true
          when Ncurses::ERR
            self.setExitType(input)
            complete = true
          when CDK::REFRESH
            @screen.erase
            @screen.refresh
          end
        end

        # Should we call a post-process?
        if !complete && !(@post_process_func.nil?)
          @post_process_func.call(:SWINDOW, self, @post_process_data, input)
        end
      end

      if !complete
        self.drawList(@box)
        self.setExitType(0)
      end

      @return_data = ret
      return ret
    end

    # This moves the window field to the given location.
    def move(xplace, yplace, relative, refresh_flag)
      current_x = @win.getbegx
      current_y = @win.getbegy
      xpos = xplace
      ypos = yplace

      # If this is a relative move, then we will adjust where we want
      # to move to.
      if relative
        xpos = @win.getbegx + xplace
        ypos = @win.getbegy + yplace
      end

      # Adjust the window if we need to.
      xtmp = [xpos]
      ytmp = [ypos]
      CDK.alignxy(@screen.window, xtmp, ytmp, @box_width, @box_height)
      xpos = xtmp[0]
      ypos = ytmp[0]

      # Get the difference
      xdiff = current_x - xpos
      ydiff = current_y - ypos

      # Move the window to the new location.
      CDK.moveCursesWindow(@win, -xdiff, -ydiff)
      CDK.moveCursesWindow(@shadow_win, -xdiff, -ydiff)

      # Touch the windows so they 'move'.
      CDK::SCREEN.refreshCDKWindow(@screen.window)

      # Redraw the window, if they asked for it.
      if refresh_flag
        self.draw(@box)
      end
    end

    # This function draws the swindow window widget.
    def draw(box)
      # Do we need to draw in the shadow.
      unless @shadow_win.nil?
        Draw.drawShadow(@shadow_win)
      end

      # Box the widget if needed
      if box
        Draw.drawObjBox(@win, self)
      end

      self.drawTitle(@win)

      @win.wrefresh

      # Draw in the list.
      self.drawList(box)
    end

    # This draws in the contents of the scrolling window
    def drawList(box)
      # Determine the last line to draw.
      if @list_size < @view_size
        last_line = @list_size
      else
        last_line = @view_size
      end

      # Erase the scrolling window.
      @field_win.werase

      # Start drawing in each line.
      (0...last_line).each do |x|
        screen_pos = @list_pos[x + @current_top] - @left_char

        # Write in the correct line.
        if screen_pos >= 0
          Draw.writeChtype(@field_win, screen_pos, x,
              @list[x + @current_top], CDK::HORIZONTAL, 0,
              @list_len[x + @current_top])
        else
          Draw.writeChtype(@field_win, 0, x, @list[x + @current_top],
              CDK::HORIZONTAL, @left_char - @list_pos[x + @current_top],
              @list_len[x + @current_top])
        end
      end

      @field_win.wrefresh
    end

    # This sets the background attribute of the widget.
    def setBKattr(attrib)
      @win.wbkgd(attrib)
      @field_win.wbkgd(attrib)
    end

    # Free any storage associated with the info-list.
    def destroyInfo
      @list = []
      @list_pos = []
      @list_len = []
    end

    # This function destroys the scrolling window widget.
    def destroy
      self.destroyInfo

      self.cleanTitle

      # Delete the windows.
      CDK.deleteCursesWindow(@shadow_win)
      CDK.deleteCursesWindow(@field_win)
      CDK.deleteCursesWindow(@win)

      # Clean the key bindings.
      self.cleanBindings(:SWINDOW)

      # Unregister this object.
      CDK::SCREEN.unregister(:SWINDOW, self)
    end

    # This function erases the scrolling window widget.
    def erase
      if self.validCDKObject
        CDK.eraseCursesWindow(@win)
        CDK.eraseCursesWindow(@shadow_win)
      end
    end

    # This execs a command and redirects the output to the scrolling window.
    def exec(command, insert_pos)
      count = -1
      Ncurses.endwin

      # Try to open the command.
      # XXX This especially needs exception handling given how Ruby
      # implements popen
      unless (ps = IO.popen(command.split, 'r')).nil?
        # Start reading.
        until (temp = ps.gets).nil?
          if temp.size != 0 && temp[-1] == '\n'
            temp = temp[0...-1]
          end
          # Add the line to the scrolling window.
          self.add(temp, insert_pos)
          count += 1
        end

        # Close the pipe
        ps.close
      end
      return count
    end

    def showMessage2(msg, msg2, filename)
      mesg = [
          msg,
          msg2,
          "<C>(%s)" % [filename],
          ' ',
          '<C> Press any key to continue.',
      ]
      @screen.popupLabel(mesg, mesg.size)
    end

    # This function allows the user to dump the information from the
    # scrolling window to a file.
    def saveInformation
      # Create the entry field to get the filename.
      entry = CDK::ENTRY.new(@screen, CDK::CENTER, CDK::CENTER,
          '<C></B/5>Enter the filename of the save file.',
          'Filename: ', Ncurses::A_NORMAL, '_'.ord, :MIXED,
          20, 1, 256, true, false)

      # Get the filename.
      filename = entry.activate([])

      # Did they hit escape?
      if entry.exit_type == :ESCAPE_HIT
        # Popup a message.
        mesg = [
            '<C></B/5>Save Canceled.',
            '<C>Escape hit. Scrolling window information not saved.',
            ' ',
            '<C>Press any key to continue.'
        ]
        @screen.popupLabel(mesg, 4)

        # Clean up and exit.
        entry.destroy
      end

      # Write the contents of the scrolling window to the file.
      lines_saved = self.dump(filename)

      # Was the save successful?
      if lines_saved == -1
        # Nope, tell 'em
        self.showMessage2('<C></B/16>Error', '<C>Could not save to the file.',
            filename)
      else
        # Yep, let them know how many lines were saved.
        self.showMessage2('<C></B/5>Save Successful',
            '<C>There were %d lines saved to the file' % [lines_saved],
            filename)
      end

      # Clean up and exit.
      entry.destroy
      @screen.erase
      @screen.draw
    end

    # This function allows the user to load new information into the scrolling
    # window.
    def loadInformation
      # Create the file selector to choose the file.
      fselect = CDK::FSELECT.new(@screen, CDK::CENTER, CDK::CENTER, 20, 55,
          '<C>Load Which File', 'FIlename', Ncurses::A_NORMAL, '.',
          Ncurses::A_REVERSE, '</5>', '</48>', '</N>', '</N>', true, false)

      # Get the filename to load.
      filename = fselect.activate([])

      # Make sure they selected a file.
      if fselect.exit_type == :ESCAPE_HIT
        # Popup a message.
        mesg = [
            '<C></B/5>Load Canceled.',
            ' ',
            '<C>Press any key to continue.',
        ]
        @screen.popupLabel(mesg, 3)

        # Clean up and exit
        fselect.destroy
        return
      end

      # Copy the filename and destroy the file selector.
      filename = fselect.pathname
      fselect.destroy

      # Maybe we should check before nuking all the information in the
      # scrolling window...
      if @list_size > 0
        # Create the dialog message.
        mesg = [
            '<C></B/5>Save Information First',
            '<C>There is information in the scrolling window.',
            '<C>Do you want to save it to a file first?',
        ]
        button = ['(Yes)', '(No)']

        # Create the dialog widget.
        dialog = CDK::DIALOG.new(@screen, CDK::CENTER, CDK::CENTER,
            mesg, 3, button, 2, Ncurses.COLOR_PAIR(2) | Ncurses::A_REVERSE,
            true, true, false)

        # Activate the widet.
        answer = dialog.activate([])
        dialog.destroy

        # Check the answer.
        if (answer == -1 || answer == 0)
          # Save the information.
          self.saveInformation
        end
      end

      # Open the file and read it in.
      f = File.open(filename)
      file_info = f.readlines.map do |line|
        if line.size > 0 && line[-1] == "\n"
          line[0...-1]
        else
          line
        end
      end.compact

      # TODO error handling
      # if (lines == -1)
      # {
      #   /* The file read didn't work. */
      #   showMessage2 (swindow,
      #                 "<C></B/16>Error",
      #                 "<C>Could not read the file",
      #                 filename);
      #   freeChar (filename);
      #   return;
      # }

      # Clean out the scrolling window.
      self.clean

      # Set the new information in the scrolling window.
      self.set(file_info, file_info.size, @box)
    end

    # This actually dumps the information from the scrolling window to a file.
    def dump(filename)
      # Try to open the file.
      #if ((outputFile = fopen (filename, "w")) == 0)
      #{
      #  return -1;
      #}
      output_file = File.new(filename, 'w')

      # Start writing out the file.
      @list.each do |item|
        raw_line = CDK.chtype2Char(item)
        output_file << "%s\n" % raw_line
      end

      # Close the file and return the number of lines written.
      output_file.close
      return @list_size
    end

    def focus
      self.draw(@box)
    end

    def unfocus
      self.draw(@box)
    end

    def createList(list_size)
      status = false

      if list_size >= 0
        new_list = []
        new_pos = []
        new_len = []

        status = true
        self.destroyInfo

        @list = new_list
        @list_pos = new_pos
        @list_len = new_len
      else
        self.destroyInfo
        status = false
      end
      return status
    end

    def position
      super(@win)
    end

    def object_type
      :SWINDOW
    end
  end
end
