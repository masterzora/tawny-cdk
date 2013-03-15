require_relative 'cdk_objs'

module CDK
  class MENTRY < CDK::CDKOBJS
    attr_accessor :info, :current_col, :current_row, :top_row
    attr_reader :disp_type, :field_width, :rows, :field_win

    def initialize(cdkscreen, xplace, yplace, title, label, field_attr,
        filler, disp_type, f_width, f_rows, logical_rows, min, box, shadow)
      super()
      parent_width = cdkscreen.window.getmaxx
      parent_height = cdkscreen.window.getmaxy
      field_width = f_width
      field_rows = f_rows

      self.setBox(box)

      # If the field_width is a negative value, the field_width will be
      # COLS-field_width, otherwise the field_width will be the given width.
      field_width = CDK.setWidgetDimension(parent_width, field_width, 0)
 
      # If the field_rows is a negative value, the field_rows will be
      # ROWS-field_rows, otherwise the field_rows will be the given rows.
      field_rows = CDK.setWidgetDimension(parent_width, field_rows, 0)
      box_height = field_rows + 2

      # Set some basic values of the mentry field
      @label = ''
      @label_len = 0
      @label_win = nil
      
      # We need to translate the string label to a chtype array
      if label.size > 0
        label_len = []
        @label = CDK.char2Chtype(label, label_len, [])
        @label_len = label_len[0]
      end
      box_width = @label_len + field_width + 2
      
      old_width = box_width
      box_width = self.setTitle(title, box_width)
      horizontal_adjust = (box_width - old_width) / 2

      box_height += @title_lines

      # Make sure we didn't extend beyond the parent window.
      box_width = [box_width, parent_width].min
      box_height = [box_height, parent_height].min
      field_width = [box_width - @label_len - 2, field_width].min
      field_rows = [box_height - @title_lines - 2, field_rows].min

      # Rejustify the x and y positions if we need to.
      xtmp = [xplace]
      ytmp = [yplace]
      CDK.alignxy(cdkscreen.window, xtmp, ytmp, box_width, box_height)
      xpos = xtmp[0]
      ypos = ytmp[0]

      # Make the label window.
      @win = Ncurses::WINDOW.new(box_height, box_width, ypos, xpos)

      # Is the window nil?
      if @win.nil?
        self.destroy
        return nil
      end

      # Create the label window.
      if @label.size > 0
        @label_win = @win.subwin(field_rows, @label_len + 2,
            ypos + @title_lines + 1, xpos + horizontal_adjust + 1)
      end

      # make the field window.
      @field_win = @win.subwin(field_rows, field_width,
          ypos + @title_lines + 1, xpos + @label_len + horizontal_adjust + 1)

      # Turn on the keypad.
      @field_win.keypad(true)
      @win.keypad(true)

      # Set up the rest of the structure.
      @parent = cdkscreen.window
      @total_width = (field_width * logical_rows) + 1

      # Create the info string
      @info = ''

      # Set up the rest of the widget information.
      @screen = cdkscreen
      @shadow_win = nil
      @field_attr = field_attr
      @field_width = field_width
      @rows = field_rows
      @box_height = box_height
      @box_width = box_width
      @filler = filler.ord
      @hidden = filler.ord
      @input_window = @win
      @accepts_focus = true
      @current_row = 0
      @current_col = 0
      @top_row = 0
      @shadow = shadow
      @disp_type = disp_type
      @min = min
      @logical_rows = logical_rows

      # This is a generic character parser for the mentry field. It is used as
      # a callback function, so any personal modifications can be made by
      # creating a new function and calling that one the mentry activation.
      mentry_callback = lambda do |mentry, character|
        cursor_pos = mentry.getCursorPos
        newchar = Display.filterByDisplayType(mentry.disp_type, character)

        if newchar == Ncurses::ERR
          CDK.Beep
        else
          mentry.info = mentry.info[0...cursor_pos] + newchar.chr +
              mentry.info[cursor_pos..-1]
          mentry.current_col += 1

          mentry.drawField

          # Have we gone out of bounds
          if mentry.current_col >= mentry.field_width
            # Update the row and col values.
            mentry.current_col = 0
            mentry.current_row += 1

            # If we have gone outside of the visual boundaries, we
            # need to scroll the window.
            if mentry.current_row == mentry.rows
              # We have to redraw the screen
              mentry.current_row -= 1
              mentry.top_row += 1
              mentry.drawField
            end
            mentry.field_win.wmove(mentry.current_row, mentry.current_col)
            mentry.field_win.wrefresh
          end
        end
      end
      @callbackfn = mentry_callback

      # Do we need to create a shadow.
      if shadow
        @shadow_win = Ncurses::WINDOW.new(box_height, box_width,
            ypos + 1, xpos + 1)
      end

      # Register
      cdkscreen.register(:MENTRY, self)
    end

    # This actually activates the mentry widget...
    def activate(actions)
      input = 0

      # Draw the mentry widget.
      self.draw(@box)

      if actions.size == 0
        while true
          input = self.getch([])

          # Inject this character into the widget.
          ret = self.inject(input)
          if @exit_type != :EARLY_EXIT
            return ret
          end
        end
      else
        actions.each do |action|
          ret = self.inject(action)
          if @exit_type != :EARLY_EXIT
            return ret
          end
        end
      end

      # Set the exit type and exit.
      self.setExitType(0)
      return 0
    end

    def setTopRow(row)
      if @top_row != row
        @top_row = row
        return true
      end
      return false
    end

    def setCurPos(row, col)
      if @current_row != row || @current_col != col
        @current_row = row
        @current_col = col
        return true
      end
      return false
    end

    def KEY_LEFT(moved, redraw)
      result = true
      if @current_col != 0
        moved[0] = self.setCurPos(@current_row, @current_col - 1)
      elsif @current_row == 0
        if @top_row != 0
          moved[0] = self.setCurPos(@current_row, @field_width - 1)
          redraw[0] = self.setTopRow(@top_row - 1)
        end
      else
        moved[0] = self.setCurPos(@current_row - 1, @field_width - 1)
      end

      if !moved[0] && !redraw[0]
        CDK.Beep
        result = false
      end
      return result
    end

    def getCursorPos
      return (@current_row + @top_row) * @field_width + @current_col
    end

    # This injects a character into the widget.
    def inject(input)
      cursor_pos = self.getCursorPos
      pp_return = 1
      ret = -1
      complete = false

      # Set the exit type.
      self.setExitType(0)

      # Refresh the field.
      self.drawField

      # Check if there is a pre-process function to be called.
      unless @pre_process_func.nil?
        # Call the pre-process function
        pp_return = @pre_process_func.call(:MENTRY, self,
            @pre_process_data, input)
      end

      # Should we continue?
      if pp_return != 0
        # Check for a key binding...
        if self.checkBind(:MENTRY, input)
          complete = true
        else
          moved = false
          redraw = false

          case input
          when Ncurses::KEY_HOME
            moved = self.setCurPos(0, 0)
            redraw = self.setTopRow(0)
          when Ncurses::KEY_END
            field_characters = @rows * @field_width
            if @info.size < field_characters
              redraw = self.setTopRow(0)
              moved = self.setCurPos(
                  @info.size / @field_width, @info.size % @field_width)
            else
              redraw = self.setTopRow(@info.size / @field_width, @rows + 1)
              moved = self.setCurPos(@rows - 1, @info.size % @field_width)
            end
          when Ncurses::KEY_LEFT
            mtmp = [moved]
            rtmp = [redraw]
            self.KEY_LEFT(mtmp, rtmp)
            moved = mtmp[0]
            redraw = rtmp[0]
          when Ncurses::KEY_RIGHT
            if @current_col < @field_width - 1
              if self.getCursorPos + 1 <= @info.size
                moved = self.setCurPos(@current_row, @current_col + 1)
              end
            elsif @current_row == @rows - 1
              if @top_row + @current_row + 1 < @logical_rows
                moved = self.setCurPos(@current_row, 0)
                redraw = self.setTopRow(@top_row + 1)
              end
            else
              moved = self.setCurPos(@current_row + 1, 0)
            end
            if !moved && !redraw
              CDK.Beep
            end
          when Ncurses::KEY_DOWN
            if @current_row != @rows - 1
              if self.getCursorPos + @field_width + 1 <= @info.size
                moved = self.setCurPos(@current_row + 1, @current_col)
              end
            elsif @top_row < @logical_rows - @rows
              if (@top_row + @current_row + 1) * @field_width <= @info.size
                redraw = self.setTopRow(@top_row + 1)
              end
            end
            if !moved && !redraw
              CDK.Beep
            end
          when Ncurses::KEY_UP
            if @current_row != 0
              moved = self.setCurPos(@current_row - 1, @current_col)
            elsif @top_row != 0
              redraw = self.setTopRow(@top_row - 1)
            end
            if !moved && !redraw
              CDK.Beep
            end
          when Ncurses::KEY_BACKSPACE, Ncurses::KEY_DC
            if @disp_type == :VIEWONLY
              CDK.Beep
            elsif @info.length == 0
              CDK.Beep
            elsif input == Ncurses::KEY_DC
              cursor_pos = self.getCursorPos
              if cursor_pos < @info.size
                @info = @info[0...cursor_pos] + @info[cursor_pos + 1..-1]
                self.drawField
              else
                CDK.Beep
              end
            else
              mtmp = [moved]
              rtmp = [redraw]
              hKL = self.KEY_LEFT(mtmp, rtmp)
              moved = mtmp[0]
              rtmp = [redraw]
              if hKL
                cursor_pos = self.getCursorPos
                if cursor_pos < @info.size
                  @info = @info[0...cursor_pos] + @info[cursor_pos + 1..-1]
                  self.drawField
                else
                  CDK.Beep
                end
              end
            end
          when CDK::TRANSPOSE
            if cursor_pos >= @info.size - 1
              CDK.Beep
            else
              holder = @info[cursor_pos]
              @info[cursor_pos] = @info[cursor_pos + 1]
              @info[cursor_pos + 1] = holder
              self.drawField
            end
          when CDK::ERASE
            if @info.size != 0
              self.clean
              self.drawField
            end
          when CDK::CUT
            if @info.size == 0
              CDK.Beep
            else
              @@g_paste_buffer = @info.clone
              self.clean
              self.drawField
            end
          when CDK::COPY
            if @info.size == 0
              CDK.Beep
            else
              @@g_paste_buffer = @info.clone
            end
          when CDK::PASTE
            if @@g_paste_buffer.size == 0
              CDK.Beep
            else
              self.setValue(@@g_paste_buffer)
              self.draw(@box)
            end
          when CDK::KEY_TAB, CDK::KEY_RETURN, Ncurses::KEY_ENTER
            if @info.size < @min + 1
              CDK.Beep
            else
              self.setExitType(input)
              ret = @info
              complete = true
            end
          when Ncurses::ERR
            self.setExitType(input)
            complete = true
          when CDK::KEY_ESC
            self.setExitType(input)
            complete = true
          when CDK::REFRESH
            @screen.erase
            @screen.refresh
          else
            if @disp_type == :VIEWONLY || @info.size >= @total_width
              CDK.Beep
            else
              @callbackfn.call(self, input)
            end
          end

          if redraw
            self.drawField
          elsif moved
            @field_win.wmove(@current_row, @current_col)
            @field_win.wrefresh
          end
        end

        # Should we do a post-process?
        if !complete && !(@post_process_func.nil?)
          @post_process_func.call(:MENTRY, self, @post_process_data, input)
        end
      end

      if !complete
        self.setExitType(0)
      end

      @result_data = ret
      return ret
    end

    # This moves the mentry field to the given location.
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

      # Get the difference.
      xdiff = current_x - xpos
      ydiff = current_y - ypos

      # Move the window to the new location.
      CDK.moveCursesWindow(@win, -xdiff, -ydiff)
      CDK.moveCursesWindow(@field_win, -xdiff, -ydiff)
      CDK.moveCursesWindow(@label_win, -xdiff, -ydiff)
      CDK.moveCursesWindow(@shadow_win, -xdiff, -ydiff)

      # Touch the windows so they 'move'.
      CDK::SCREEN.refreshCDKWindow(@screen.window)

      # Redraw the window, if they asked for it.
      if refresh_flag
        self.draw(@box)
      end
    end

    # This function redraws the multiple line entry field.
    def drawField
      currchar = @field_width * @top_row
  
      self.drawTitle(@win)
      @win.wrefresh
  
      lastpos = @info.size
  
      # Start redrawing the fields.
      (0...@rows).each do |x|
        (0...@field_width).each do |y|
          if currchar < lastpos
            if Display.isHiddenDisplayType(@disp_type)
              @field_win.mvwaddch(x, y, @filler)
            else
              @field_win.mvwaddch(x, y, @info[currchar].ord | @field_attr)
              currchar += 1
            end
          else
            @field_win.mvwaddch(x, y, @filler)
          end
        end
      end
  
      # Refresh the screen.
      @field_win.wmove(@current_row, @current_col)
      @field_win.wrefresh
    end
  
    # This function draws the multiple line entry field.
    def draw(box)
      # Box the widget if asked.
      if box
        Draw.drawObjBox(@win, self)
        @win.wrefresh
      end
  
      # Do we need to draw in the shadow?
      unless @shadow_win.nil?
        Draw.drawShadow(@shadow_win)
      end
  
      # Draw in the label to the widget.
      unless @label_win.nil?
        Draw.writeChtype(@label_win, 0, 0, @label, CDK::HORIZONTAL,
            0, @label_len)
        @label_win.wrefresh
      end
  
      # Draw the mentry field
      self.drawField
    end
  
    # This sets the background attribute of the widget.
    def setBKattr(attrib)
      @win.wbkgd(attrib)
      @field_win.wbkgd(attrib)
      unless @label_win.nil?
        @label_win.wbkgd(attrib)
      end
    end
  
    # This function erases the multiple line entry field from the screen.
    def erase
      if self.validCDKObject
        CDK.eraseCursesWindow(@field_win)
        CDK.eraseCursesWindow(@label_win)
        CDK.eraseCursesWindow(@win)
        CDK.eraseCursesWindow(@shadow_win)
      end
    end
  
    # This function destroys a multiple line entry field widget.
    def destroy
      self.cleanTitle
  
      # Clean up the windows.
      CDK.deleteCursesWindow(@field_win)
      CDK.deleteCursesWindow(@label_win)
      CDK.deleteCursesWindow(@shadow_win)
      CDK.deleteCursesWindow(@win)
  
      # Clean the key bindings.
      self.cleanBindings(:MENTRY)
  
      # Unregister this object.
      CDK::SCREEN.unregister(:MENTRY, self)
    end
  
    # This sets multiple attributes of the widget.
    def set(value, min, box)
      self.setValue(value)
      self.setMin(min)
      self.setBox(box)
    end
  
    # This removes the old information in the entry field and keeps the
    # new information given.
    def setValue(new_value)
      field_characters = @rows * @field_width
  
      @info = new_value
  
      # Set the cursor/row info
      if new_value.size < field_characters
        @top_row = 0
        @current_row = new_value.size / @field_width
        @current_col = new_value.size % @field_width
      else
        row_used = new_value.size / @field_width
        @top_row = row_used - @rows + 1
        @current_row = @rows - 1
        @current_col = new_value.size % @field_width
      end
  
      # Redraw the widget.
      self.drawField
    end
  
    def getValue
      return @info
    end
  
    # This sets the filler character to use when drawing the widget.
    def setFillerChar(filler)
      @filler = filler.ord
    end
  
    def getFillerChar
      return @filler
    end
  
    # This sets the character to use when a hidden character type is used
    def setHiddenChar(character)
      @hidden = character
    end
  
    def getHiddenChar
      return @hidden
    end
  
    # This sets a minimum length of the widget.
    def setMin(min)
      @min = min
    end
  
    def getMin
      return @min
    end
  
    # This erases the information in the multiple line entry widget
    def clean
      @info = ''
      @current_row = 0
      @current_col = 0
      @top_row = 0
    end
  
    # This sets the callback function.
    def setCB(callback)
      @callbackfn = callback
    end
  
    def focus
      @field_win.wmove(0, @current_col)
      @field_win.wrefresh
    end
  
    def unfocus
      @field_win.wrefresh
    end

    def position
      super(@win)
    end

    def object_type
      :MENTRY
    end
  end
end
