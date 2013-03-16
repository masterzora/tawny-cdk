require_relative 'cdk_objs'

module CDK
  class DIALOG < CDK::CDKOBJS
    attr_reader :current_button
    MIN_DIALOG_WIDTH = 10

    def initialize(cdkscreen, xplace, yplace, mesg, rows, button_label,
        button_count, highlight, separator, box, shadow)
      super()
      box_width = DIALOG::MIN_DIALOG_WIDTH
      max_message_width = -1
      button_width = 0
      xpos = xplace
      ypos = yplace
      temp = 0
      buttonadj = 0
      @info = []
      @info_len = []
      @info_pos = []
      @button_label = []
      @button_len = []
      @button_pos = []

      if rows <= 0 || button_count <= 0
        self.destroy
        return nil
      end

      self.setBox(box)
      box_height = if separator then 1 else 0 end
      box_height += rows + 2 * @border_size + 1

      # Translate the string message to a chtype array
      (0...rows).each do |x|
        info_len = []
        info_pos = []
        @info << CDK.char2Chtype(mesg[x], info_len, info_pos)
        @info_len << info_len[0]
        @info_pos << info_pos[0]
        max_message_width = [max_message_width, info_len[0]].max
      end

      # Translate the button label string to a chtype array
      (0...button_count).each do |x|
        button_len = []
        @button_label << CDK.char2Chtype(button_label[x], button_len, [])
        @button_len << button_len[0]
        button_width += button_len[0] + 1
      end

      button_width -= 1

      # Determine the final dimensions of the box.
      box_width = [box_width, max_message_width, button_width].max
      box_width = box_width + 2 + 2 * @border_size

      # Now we have to readjust the x and y positions.
      xtmp = [xpos]
      ytmp = [ypos]
      CDK.alignxy(cdkscreen.window, xtmp, ytmp, box_width, box_height)
      xpos = xtmp[0]
      ypos = ytmp[0]

      # Set up the dialog box attributes.
      @screen = cdkscreen
      @parent = cdkscreen.window
      @win = Ncurses::WINDOW.new(box_height, box_width, ypos, xpos)
      @shadow_win = nil
      @button_count = button_count
      @current_button = 0
      @message_rows = rows
      @box_height = box_height
      @box_width = box_width
      @highlight = highlight
      @separator = separator
      @accepts_focus = true
      @input_window = @win
      @shadow = shadow

      # If we couldn't create the window, we should return a nil value.
      if @win.nil?
        self.destroy
        return nil
      end
      @win.keypad(true)

      # Find the button positions.
      buttonadj = (box_width - button_width) / 2
      (0...button_count).each do |x|
        @button_pos[x] = buttonadj
        buttonadj = buttonadj + @button_len[x] + @border_size
      end

      # Create the string alignments.
      (0...rows).each do |x|
        @info_pos[x] = CDK.justifyString(box_width - 2 * @border_size,
            @info_len[x], @info_pos[x])
      end

      # Was there a shadow?
      if shadow
        @shadow_win = Ncurses::WINDOW.new(box_height, box_width,
            ypos + 1, xpos + 1)
      end

      # Register this baby.
      cdkscreen.register(:DIALOG, self)
    end

    # This lets the user select the button.
    def activate(actions)
      input = 0

      # Draw the dialog box.
      self.draw(@box)

      # Lets move to the first button.
      Draw.writeChtypeAttrib(@win, @button_pos[@current_button],
          @box_height - 1 - @border_size, @button_label[@current_button],
          @highlight, CDK::HORIZONTAL, 0, @button_len[@current_button])
      @win.wrefresh

      if actions.nil? || actions.size == 0
        while true
          input = self.getch([])

          # Inject the character into the widget.
          ret = self.inject(input)
          if @exit_type != :EARLY_EXIT
            return ret
          end
        end
      else
        # Inject each character one at a time.
        actions.each do |action|
          ret = self.inject(action)
          if @exit_type != :EARLY_EXIT
            return ret
          end
        end
      end

      # Set the exit type and exit
      self.setExitType(0)
      return -1
    end

    # This injects a single character into the dialog widget
    def inject(input)
      first_button = 0
      last_button = @button_count - 1
      pp_return = 1
      ret = -1
      complete = false

      # Set the exit type.
      self.setExitType(0)

      # Check if there is a pre-process function to be called.
      unless @pre_process_func.nil?
        pp_return = @pre_process_func.call(:DIALOG, self,
            @pre_process_data, input)
      end

      # Should we continue?
      if pp_return != 0
        # Check for a key binding.
        if self.checkBind(:DIALOG, input)
          complete = true
        else
          case input
          when Ncurses::KEY_LEFT, Ncurses::KEY_BTAB, Ncurses::KEY_BACKSPACE
            if @current_button == first_button
              @current_button = last_button
            else
              @current_button -= 1
            end
          when Ncurses::KEY_RIGHT, CDK::KEY_TAB, ' '.ord
            if @current_button == last_button
              @current_button = first_button
            else
              @current_button += 1
            end
          when Ncurses::KEY_UP, Ncurses::KEY_DOWN
            CDK.Beep
          when CDK::REFRESH
            @screen.erase
            @screen.refresh
          when CDK::KEY_ESC
            self.setExitType(input)
            complete = true
          when Ncurses::ERR
            self.setExitType(input)
          when Ncurses::KEY_ENTER, CDK::KEY_RETURN
            self.setExitType(input)
            ret = @current_button
            complete = true
          end
        end

        # Should we call a post_process?
        if !complete && !(@post_process_func.nil?)
          @post_process_func.call(:DIALOG, self,
              @post_process_data, input)
        end
      end

      unless complete
        self.drawButtons
        @win.wrefresh
        self.setExitType(0)
      end

      @result_data = ret
      return ret
    end

    # This moves the dialog field to the given location.
    # Inherited
    # def move(xplace, yplace, relative, refresh_flag)
    # end

    # This function draws the dialog widget.
    def draw(box)
      # Is there a shadow?
      unless @shadow_win.nil?
        Draw.drawShadow(@shadow_win)
      end

      # Box the widget if they asked.
      if box
        Draw.drawObjBox(@win, self)
      end

      # Draw in the message.
      (0...@message_rows).each do |x|
        Draw.writeChtype(@win,
            @info_pos[x] + @border_size, x + @border_size, @info[x],
            CDK::HORIZONTAL, 0, @info_len[x])
      end

      # Draw in the buttons.
      self.drawButtons

      @win.wrefresh
    end

    # This function destroys the dialog widget.
    def destroy
      # Clean up the windows.
      CDK.deleteCursesWindow(@win)
      CDK.deleteCursesWindow(@shadow_win)

      # Clean the key bindings
      self.cleanBindings(:DIALOG)

      # Unregister this object
      CDK::SCREEN.unregister(:DIALOG, self)
    end

    # This function erases the dialog widget from the screen.
    def erase
      if self.validCDKObject
        CDK.eraseCursesWindow(@win)
        CDK.eraseCursesWindow(@shadow_win)
      end
    end

    # This sets attributes of the dialog box.
    def set(highlight, separator, box)
      self.setHighlight(highlight)
      self.setSeparator(separator)
      self.setBox(box)
    end

    # This sets the highlight attribute for the buttons.
    def setHighlight(highlight)
      @highlight = highlight
    end

    def getHighlight
      return @highlight
    end

    # This sets whether or not the dialog box will have a separator line.
    def setSeparator(separator)
      @separator = separator
    end

    def getSeparator
      return @separator
    end

    # This sets the background attribute of the widget.
    def setBKattr(attrib)
      @win.wbkgd(attrib)
    end

    # This draws the dialog buttons and the separation line.
    def drawButtons
      (0...@button_count).each do |x|
        Draw.writeChtype(@win, @button_pos[x],
            @box_height -1 - @border_size,
            @button_label[x], CDK::HORIZONTAL, 0,
            @button_len[x])
      end

      # Draw the separation line.
      if @separator
        boxattr = @BXAttr

        (1...@box_width).each do |x|
          @win.mvwaddch(@box_height - 2 - @border_size, x,
              Ncurses::ACS_HLINE | boxattr)
        end
        @win.mvwaddch(@box_height - 2 - @border_size, 0,
            Ncurses::ACS_LTEE | boxattr)
        @win.mvwaddch(@box_height - 2 - @border_size, @win.getmaxx - 1,
            Ncurses::ACS_RTEE | boxattr)
      end
      Draw.writeChtypeAttrib(@win, @button_pos[@current_button],
          @box_height - 1 - @border_size, @button_label[@current_button],
          @highlight, CDK::HORIZONTAL, 0, @button_len[@current_button])
    end

    def focus
      self.draw(@box)
    end

    def unfocus
      self.draw(@box)
    end

    def object_type
      :DIALOG
    end

    def position
      super(@win)
    end
  end

  class GRAPH < CDK::CDKOBJS
    def initialize(cdkscreen, xplace, yplace, height, width,
        title, xtitle, ytitle)
      super()
      parent_width = cdkscreen.window.getmaxx
      parent_height = cdkscreen.window.getmaxy

      self.setBox(false)

      box_height = CDK.setWidgetDimension(parent_height, height, 3)
      box_width = CDK.setWidgetDimension(parent_width, width, 0)
      box_width = self.setTitle(title, box_width)
      box_height += @title_lines
      box_width = [parent_width, box_width].min
      box_height = [parent_height, box_height].min

      # Rejustify the x and y positions if we need to
      xtmp = [xplace]
      ytmp = [yplace]
      CDK.alignxy(cdkscreen.window, xtmp, ytmp, box_width, box_height)
      xpos = xtmp[0]
      ypos = ytmp[0]

      # Create the widget pointer
      @screen = cdkscreen
      @parent = cdkscreen.window
      @win = Ncurses::WINDOW.new(box_height, box_width, ypos, xpos)
      @box_height = box_height
      @box_width = box_width
      @minx = 0
      @maxx = 0
      @xscale = 0
      @yscale = 0
      @count = 0
      @display_type = :LINE

      if @win.nil?
        self.destroy
        return nil
      end
      @win.keypad(true)

      # Translate the X axis title string to a chtype array
      if !(xtitle.nil?) && xtitle.size > 0
        xtitle_len = []
        xtitle_pos = []
        @xtitle = CDK.char2Chtype(xtitle, xtitle_len, xtitle_pos)
        @xtitle_len = xtitle_len[0]
        @xtitle_pos = CDK.justifyString(@box_height,
            @xtitle_len, xtitle_pos[0])
      else
        xtitle_len = []
        xtitle_pos = []
        @xtitle = CDK.char2Chtype("<C></5>X Axis", xtitle_len, xtitle_pos)
        @xtitle_len = title_len[0]
        @xtitle_pos = CDK.justifyString(@box_height,
            @xtitle_len, xtitle_pos[0])
      end

      # Translate the Y Axis title string to a chtype array
      if !(ytitle.nil?) && ytitle.size > 0
        ytitle_len = []
        ytitle_pos = []
        @ytitle = CDK.char2Chtype(ytitle, ytitle_len, ytitle_pos)
        @ytitle_len = ytitle_len[0]
        @ytitle_pos = CDK.justifyString(@box_width, @ytitle_len, ytitle_pos[0])
      else
        ytitle_len = []
        ytitle_pos = []
        @ytitle = CDK.char2Chtype("<C></5>Y Axis", ytitle_len, ytitle_pos)
        @ytitle_len = ytitle_len[0]
        @ytitle_pos = CDK.justifyString(@box_width, @ytitle_len, ytitle_pos[0])
      end

      @graph_char = 0
      @values = []

      cdkscreen.register(:GRAPH, self)
    end

    # This was added for the builder.
    def activate(actions)
      self.draw(@box)
    end

    # Set multiple attributes of the widget
    def set(values, count, graph_char, start_at_zero, display_type)
      ret = self.setValues(values, count, start_at_zero)
      self.setCharacters(graph_char)
      self.setDisplayType(display_type)
      return ret
    end

    # Set the scale factors for the graph after wee have loaded new values.
    def setScales
      @xscale = (@maxx - @minx) / [1, @box_height - @title_lines - 5].max
      if @xscale <= 0
        @xscale = 1
      end

      @yscale = (@box_width - 4) / [1, @count].max
      if @yscale <= 0
        @yscale = 1
      end
    end

    # Set the values of the graph.
    def setValues(values, count, start_at_zero)
      min = 2**30
      max = -2**30

      # Make sure everything is happy.
      if count < 0
        return false
      end

      if !(@values.nil?) && @values.size > 0
        @values = []
        @count = 0
      end

      # Copy the X values
      values.each do |value|
        min = [value, @minx].min
        max = [value, @maxx].max

        # Copy the value.
        @values << value
      end

      # Keep the count and min/max values
      @count = count
      @minx = min
      @maxx = max

      # Check the start at zero status.
      if start_at_zero
        @minx = 0
      end

      self.setScales

      return true
    end

    def getValues(size)
      size << @count
      return @values
    end

    # Set the value of the graph at the given index.
    def setValue(index, value, start_at_zero)
      # Make sure the index is within range.
      if index < 0 || index >= @count
        return false
      end

      # Set the min, max, and value for the graph
      @minx = [value, @minx].min
      @maxx = [value, @maxx].max
      @values[index] = value

      # Check the start at zero status
      if start_at_zero
        @minx = 0
      end

      self.setScales

      return true
    end

    def getValue(index)
      if index >= 0 && index < @count then @values[index] else 0 end
    end

    # Set the characters of the graph widget.
    def setCharacters(characters)
      char_count = []
      new_tokens = CDK.char2Chtype(characters, char_count, [])

      if char_count[0] != @count
        return false
      end

      @graph_char = new_tokens
      return true
    end

    def getCharacters
      return @graph_char
    end

    # Set the character of the graph widget of the given index.
    def setCharacter(index, character)
      # Make sure the index is within range
      if index < 0 || index > @count
        return false
      end

      # Convert the string given to us
      char_count = []
      new_tokens = CDK.char2Chtype(character, char_count, [])

      # Check if the number of characters back is the same as the number
      # of elements in the list.
      if char_count[0] != @count
        return false
      end

      # Everything OK so far. Set the value of the array.
      @graph_char[index] = new_tokens[0]
      return true
    end

    def getCharacter(index)
      return graph_char[index]
    end

    # Set the display type of the graph.
    def setDisplayType(type)
      @display_type = type
    end

    def getDisplayType
      @display_type
    end

    # Set the background attribute of the widget.
    def setBKattr(attrib)
      @win.wbkgd(attrib)
    end

    # Move the graph field to the given location.
    def move(xplace, yplace, relative, refresh_flag)
      current_x = @win.getbegx
      current_y = @win.getbegy
      xpos = xplace
      ypos = yplace

      # If this is a relative move, then we will adjust where we want
      # to move to
      if relative
        xpos = @win.getbegx + xplace
        ypos = @win.getbegy + yplace
      end

      # Adjust the window if we need to.
      xtmp = [xpos]
      tymp = [ypos]
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

      # Reraw the windowk if they asked for it
      if refresh_flag
        self.draw(@box)
      end
    end

    # Draw the grpah widget
    def draw(box)
      adj = 2 + (if @xtitle.nil? || @xtitle.size == 0 then 0 else 1 end)
      spacing = 0
      attrib = ' '.ord | Ncurses::A_REVERSE

      if box
        Draw.drawObjBox(@win, self)
      end

      # Draw in the vertical axis
      Draw.drawLine(@win, 2, @title_lines + 1, 2, @box_height - 3,
          Ncurses::ACS_VLINE)

      # Draw in the horizontal axis
      Draw.drawLine(@win, 3, @box_height - 3, @box_width, @box_height - 3,
          Ncurses::ACS_HLINE)

      self.drawTitle(@win)

      # Draw in the X axis title.
      if !(@xtitle.nil?) && @xtitle.size > 0
        Draw.writeChtype(@win, 0, @xtitle_pos, @xtitle, CDK::VERTICAL,
            0, @xtitle_len)
        attrib = @xtitle[0] & Ncurses::A_ATTRIBUTES
      end

      # Draw in the X axis high value
      temp = "%d" % [@maxx]
      Draw.writeCharAttrib(@win, 1, @title_lines + 1, temp, attrib,
          CDK::VERTICAL, 0, temp.size)

      # Draw in the X axis low value.
      temp = "%d" % [@minx]
      Draw.writeCharAttrib(@win, 1, @box_height - 2 - temp.size, temp, attrib,
          CDK::VERTICAL, 0, temp.size)

      # Draw in the Y axis title
      if !(@ytitle.nil?) && @ytitle.size > 0
        Draw.writeChtype(@win, @ytitle_pos, @box_height - 1, @ytitle,
            CDK::HORIZONTAL, 0, @ytitle_len)
      end

      # Draw in the Y axis high value.
      temp = "%d" % [@count]
      Draw.writeCharAttrib(@win, @box_width - temp.size - adj,
          @box_height - 2, temp, attrib, CDK::HORIZONTAL, 0, temp.size)

      # Draw in the Y axis low value.
      Draw.writeCharAttrib(@win, 3, @box_height - 2, "0", attrib,
          CDK::HORIZONTAL, 0, "0".size)

      # If the count is zero then there aren't any points.
      if @count == 0
        @win.wrefresh
        return
      end

      spacing = (@box_width - 3) / @count  # FIXME magic number (TITLE_LM)

      # Draw in the graph line/plot points.
      (0...@count).each do |y|
        colheight = (@values[y] / @xscale) - 1
        # Add the marker on the Y axis.
        @win.mvwaddch(@box_height - 3, (y + 1) * spacing + adj,
            Ncurses::ACS_TTEE)

        # If this is a plot graph, all we do is draw a dot.
        if @display_type == :PLOT
          xpos = @box_height - 4 - colheight
          ypos = (y + 1) * spacing + adj
          @win.mvwaddch(xpos, ypos, @graph_char[y])
        else
          (0..@yscale).each do |x|
            xpos = @box_height - 3
            ypos = (y + 1) * spacing - adj
            Draw.drawLine(@win, ypos, xpos - colheight, ypos, xpos,
                @graph_char[y])
          end
        end
      end

      # Draw in the axis corners.
      @win.mvwaddch(@title_lines, 2, Ncurses::ACS_URCORNER)
      @win.mvwaddch(@box_height - 3, 2, Ncurses::ACS_LLCORNER)
      @win.mvwaddch(@box_height - 3, @box_width, Ncurses::ACS_URCORNER)

      # Refresh and lets see it
      @win.wrefresh
    end

    def destroy
      self.cleanTitle
      self.cleanBindings(:GRAPH)
      CDK::SCREEN.unregister(:GRAPH, self)
      CDK.deleteCursesWindow(@win)
    end

    def erase
      if self.validCDKObject
        CDK.eraseCursesWindow(@win)
      end
    end

    def object_type
      :GRAPH
    end

    def position
      super(@win)
    end
  end
end
