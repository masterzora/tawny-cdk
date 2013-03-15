require_relative 'cdk_objs'

module CDK
  class ENTRY < CDK::CDKOBJS
    attr_accessor :info, :left_char, :screen_col
    attr_reader :win, :box_height, :box_width, :max, :field_width
    attr_reader :min, :max

    def initialize(cdkscreen, xplace, yplace, title, label, field_attr, filler,
        disp_type, f_width, min, max, box, shadow)
      super()
      parent_width = cdkscreen.window.getmaxx
      parent_height = cdkscreen.window.getmaxy
      field_width = f_width
      box_width = 0
      xpos = xplace
      ypos = yplace
      
      self.setBox(box)
      box_height = @border_size * 2 + 1

      # If the field_width is a negative value, the field_width will be
      # COLS-field_width, otherwise the field_width will be the given width.
      field_width = CDK.setWidgetDimension(parent_width, field_width, 0)
      box_width = field_width + 2 * @border_size

      # Set some basic values of the entry field.
      @label = 0
      @label_len = 0
      @label_win = nil

      # Translate the label string to a chtype array
      if !(label.nil?) && label.size > 0
        label_len = [@label_len]
        @label = CDK.char2Chtype(label, label_len, [])
        @label_len = label_len[0]
        box_width += @label_len
      end

      old_width = box_width
      box_width = self.setTitle(title, box_width)
      horizontal_adjust = (box_width - old_width) / 2

      box_height += @title_lines

      # Make sure we didn't extend beyond the dimensinos of the window.
      box_width = [box_width, parent_width].min
      box_height = [box_height, parent_height].min
      field_width = [field_width,
          box_width - @label_len - 2 * @border_size].min

      # Rejustify the x and y positions if we need to.
      xtmp = [xpos]
      ytmp = [ypos]
      CDK.alignxy(cdkscreen.window, xtmp, ytmp, box_width, box_height)
      xpos = xtmp[0]
      ypos = ytmp[0]

      # Make the label window.
      @win = cdkscreen.window.subwin(box_height, box_width, ypos, xpos)
      if @win.nil?
        self.destroy
        return nil
      end
      @win.keypad(true)

      # Make the field window.
      @field_win = @win.subwin(1, field_width,
          ypos + @title_lines + @border_size,
          xpos + @label_len + horizontal_adjust + @border_size)

      if @field_win.nil?
        self.destroy
        return nil
      end
      @field_win.keypad(true)

      # make the label win, if we need to
      if !(label.nil?) && label.size > 0
        @label_win = @win.subwin(1, @label_len,
            ypos + @title_lines + @border_size,
            xpos + horizontal_adjust + @border_size)
      end

      # cleanChar (entry->info, max + 3, '\0');
      @info = ''
      @info_width = max + 3

      # Set up the rest of the structure.
      @screen = cdkscreen
      @parent = cdkscreen.window
      @shadow_win = nil
      @field_attr = field_attr
      @field_width = field_width
      @filler = filler
      @hidden = filler
      @input_window = @field_win
      @accepts_focus = true
      @data_ptr = nil
      @shadow = shadow
      @screen_col = 0
      @left_char = 0
      @min = min
      @max = max
      @box_width = box_width
      @box_height = box_height
      @disp_type = disp_type
      @callbackfn = lambda do |entry, character|
        plainchar = Display.filterByDisplayType(entry, character)

        if plainchar == Ncurses::ERR || entry.info.size >= entry.max
          CDK.Beep
        else
          # Update the screen and pointer
          if entry.screen_col != entry.field_width - 1
            front = (entry.info[0...(entry.screen_col + entry.left_char)] or '')
            back = (entry.info[(entry.screen_col + entry.left_char)..-1] or '')
            entry.info = front + plainchar.chr + back
            entry.screen_col += 1
          else
            # Update the character pointer.
            entry.info << plainchar
            # Do not update the pointer if it's the last character
            if entry.info.size < entry.max
              entry.left_char += 1
            end
          end

          # Update the entry field.
          entry.drawField
        end
      end

      # Do we want a shadow?
      if shadow
        @shadow_win = cdkscreen.window.subwin(box_height, box_width,
            ypos + 1, xpos + 1)
      end

      cdkscreen.register(:ENTRY, self)
    end

    # This means you want to use the given entry field. It takes input
    # from the keyboard, and when it's done, it fills the entry info
    # element of the structure with what was typed.
    def activate(actions)
      input = 0
      ret = 0

      # Draw the widget.
      self.draw(@box)

      if actions.nil? or actions.size == 0
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

      # Make sure we return the correct info.
      if @exit_type == :NORMAL
        return @info
      else
        return 0
      end
    end

    def setPositionToEnd
      if @info.size >= @field_width
        if @info.size < @max
          char_count = @field_width - 1
          @left_char = @info.size - char_count
          @screen_col = char_count
        else
          @left_char = @info.size - @field_width
          @screen_col = @info.size - 1
        end
      else
        @left_char = 0
        @screen_col = @info.size
      end
    end

    # This injects a single character into the widget.
    def inject(input)
      pp_return = 1
      ret = 1
      complete = false

      # Set the exit type
      self.setExitType(0)
      
      # Refresh the widget field.
      self.drawField

      unless @pre_process_func.nil?
        pp_return = @pre_process_func.call(:ENTRY, self,
            @pre_process_data, input)
      end

      # Should we continue?
      if pp_return != 0
        # Check a predefined binding
        if self.checkBind(:ENTRY, input)
          complete = true
        else
          curr_pos = @screen_col + @left_char

          case input
          when Ncurses::KEY_UP, Ncurses::KEY_DOWN
            CDK.Beep
          when Ncurses::KEY_HOME
            @left_char = 0
            @screen_col = 0
            self.drawField
          when CDK::TRANSPOSE
            if curr_pos >= @info.size - 1
              CDK.Beep
            else
              holder = @info[curr_pos]
              @info[curr_pos] = @info[curr_pos + 1]
              @info[curr_pos + 1] = holder
              self.drawField
            end
          when Ncurses::KEY_END
            self.setPositionToEnd
            self.drawField
          when Ncurses::KEY_LEFT
            if curr_pos <= 0
              CDK.Beep
            elsif @screen_col == 0
              # Scroll left.
              @left_char -= 1
              self.drawField
            else
              @screen_col -= 1
              @field_win.wmove(0, @screen_col)
            end
          when Ncurses::KEY_RIGHT
            if curr_pos >= @info.size
              CDK.Beep
            elsif @screen_col == @field_width - 1
              # Scroll to the right.
              @left_char += 1
              self.drawField
            else
              # Move right.
              @screen_col += 1
              @field_win.wmove(0, @screen_col)
            end
          when Ncurses::KEY_BACKSPACE, Ncurses::KEY_DC
            if @disp_type == :VIEWONLY
              CDK.Beep
            else
              success = false
              if input == Ncurses::KEY_BACKSPACE
                curr_pos -= 1
              end

              if curr_pos >= 0 && @info.size > 0
                if curr_pos < @info.size
                  @info = @info[0...curr_pos] + @info[curr_pos+1..-1]
                  success = true
                elsif input == Ncurses::KEY_BACKSPACE
                  @info = @info[0...-1]
                  success = true
                end
              end
              
              if success
                if input == Ncurses::KEY_BACKSPACE
                  if @screen_col > 0
                    @screen_col -= 1
                  else
                    @left_char -= 1
                  end
                end
                self.drawField
              else
                CDK.Beep
              end
            end
          when CDK::KEY_ESC
            self.setExitType(input)
            complete = true
          when CDK::ERASE
            if @info.size != 0
              self.clean
              self.drawField
            end
          when CDK::CUT
            if @info.size != 0
              @@g_paste_buffer = @info.clone
              self.clean
              self.drawField
            else
              CDK.Beep
            end
          when CDK::COPY
            if @info.size != 0
              @@g_paste_buffer = @info.clone
            else
              CDK.Beep
            end
          when CDK::PASTE
            if @@g_paste_buffer != 0
              self.setValue(@@g_paste_buffer)
              self.drawField
            else
              CDK.Beep
            end
          when CDK::KEY_TAB, CDK::KEY_RETURN, Ncurses::KEY_ENTER
            if @info.size >= @min
              self.setExitType(input)
              ret = @info
              complete = true
            else
              CDK.Beep
            end
          when Ncurses::ERR
            self.setExitType(input)
            complete = true
          when CDK::REFRESH
            @screen.erase
            @screen.refresh
          else
            @callbackfn.call(self, input)
          end
        end

        if !complete && !(@post_process_func.nil?)
          @post_process_func.call(:ENTRY, self, @post_process_data, input)
        end
      end

      unless complete
        self.setExitType(0)
      end

      @result_data = ret
      return ret
    end

    # This moves the entry field to the given location.
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

      # Adjust the window if we need to
      xtmp = [xpos]
      ytmp = [ypos]
      CDK.alignxy(@screen.window, xtmp, ytmp, @box_width, @box_height)
      xpos = xtmp[0]
      ypos = ytmp[0]

      # Get the difference.
      xdiff = current_x - xpos
      ydiff = current_y - ypos

      # Move the window to the new location.
      CDK.moveCursesWindow(@win, -xdiff, -ydiff)
      CDK.moveCursesWindow(@field_win, -xdiff, -ydiff)
      CDK.moveCursesWindow(@label_win, -xdiff, -ydiff)
      CDK.moveCursesWindow(@shadow_win, -xdiff, -ydiff)

      # Touch the windows so they 'move'
      CDK::SCREEN.refreshCDKWindow(@screen.window)

      # Redraw the window, if they asked for it
      if refresh_flag
        self.draw(@box)
      end
    end
    
    # This erases the information in the entry field and redraws
    # a clean and empty entry field.
    def clean
      width = @field_width

      @info = ''

      # Clean the entry screen field.
      @field_win.mvwhline(0, 0, @filler.ord, width)

      # Reset some variables
      @screen_col = 0
      @left_char = 0

      # Refresh the entry field.
      @field_win.wrefresh
    end

    # This draws the entry field.
    def draw(box)
      # Did we ask for a shadow?
      unless @shadow_win.nil?
        Draw.drawShadow(@shadow_win)
      end

      # Box the widget if asked.
      if box
        Draw.drawObjBox(@win, self)
      end

      self.drawTitle(@win)

      @win.wrefresh

      # Draw in the label to the widget.
      unless @label_win.nil?
        Draw.writeChtype(@label_win, 0, 0, @label, CDK::HORIZONTAL, 0,
            @label_len)
        @label_win.wrefresh
      end

      self.drawField
    end

    def drawField
      # Draw in the filler characters.
      @field_win.mvwhline(0, 0, @filler.ord, @field_width)

      # If there is information in the field then draw it in.
      if !(@info.nil?) && @info.size > 0
        # Redraw the field.
        if Display.isHiddenDisplayType(@disp_type)
          (@left_char...@info.size).each do |x|
            @field_win.mvwaddch(0, x - @left_char, @hidden)
          end
        else
          (@left_char...@info.size).each do |x|
            @field_win.mvwaddch(0, x - @left_char, @info[x].ord | @field_attr)
          end
        end
        @field_win.wmove(0, @screen_col)
      end

      @field_win.wrefresh
    end

    # This erases an entry widget from the screen.
    def erase
      if self.validCDKObject
        CDK.eraseCursesWindow(@field_win)
        CDK.eraseCursesWindow(@label_win)
        CDK.eraseCursesWindow(@win)
        CDK.eraseCursesWindow(@shadow_win)
      end
    end

    # This destroys an entry widget.
    def destroy
      self.cleanTitle

      CDK.deleteCursesWindow(@field_win)
      CDK.deleteCursesWindow(@label_win)
      CDK.deleteCursesWindow(@shadow_win)
      CDK.deleteCursesWindow(@win)

      self.cleanBindings(:ENTRY)

      CDK::SCREEN.unregister(:ENTRY, self)
    end

    # This sets specific attributes of the entry field.
    def set(value, min, max, box)
      self.setValue(value)
      self.setMin(min)
      self.setMax(max)
    end

    # This removes the old information in the entry field and keeps
    # the new information given.
    def setValue(new_value)
      if new_value.nil?
        @info = ''

        @left_char = 0
        @screen_col = 0
      else
        @info = new_value.clone

        self.setPositionToEnd
      end
    end

    def getValue
      return @info
    end

    # This sets the maximum length of the string that will be accepted
    def setMax(max)
      @max = max
    end

    def getMax
      @max
    end

    # This sets the minimum length of the string that will be accepted.
    def setMin(min)
      @min = min
    end

    def getMin
      @min
    end

    # This sets the filler character to be used in the entry field.
    def setFillerChar(filler_char)
      @filler = filler_char
    end

    def getFillerChar
      @filler
    end

    # This sets the character to use when a hidden type is used.
    def setHiddenChar(hidden_characer)
      @hidden = hidden_character
    end

    def getHiddenChar
      @hidden
    end

    # This sets the background attribute of the widget.
    def setBKattr(attrib)
      @win.wbkgd(attrib)
      @field_win.wbkgd(attrib)
      unless @label_win.nil?
        @label_win.wbkgd(attrib)
      end
    end

    # This sets the attribute of the entry field.
    def setHighlight(highlight, cursor)
      @field_win.wbkgd(highlight)
      @field_attr = highlight
      Ncurses.curs_set(cursor)
      # FIXME(original) - if (cursor) { move the cursor to this widget }
    end

    # This sets the entry field callback function.
    def setCB(callback)
      @callbackfn = callback
    end

    def focus
      @field_win.wmove(0, @screen_col)
      @field_win.wrefresh
    end

    def unfocus
      self.draw(box)
      @field_win.wrefresh
    end

    def position
      super(@win)
    end

    def object_type
      :ENTRY
    end
  end
end
