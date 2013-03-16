require_relative 'cdk_objs'

module CDK
  class BUTTONBOX < CDK::CDKOBJS
    attr_reader :current_button

    def initialize(cdkscreen, x_pos, y_pos, height, width, title, rows, cols,
        buttons, button_count, highlight, box, shadow)
      super()
      parent_width = cdkscreen.window.getmaxx
      parent_height = cdkscreen.window.getmaxy
      col_width = 0
      current_button = 0
      @button = []
      @button_len = []
      @button_pos = []
      @column_widths = []

      if button_count <= 0
        self.destroy
        return nil
      end

      self.setBox(box)

      # Set some default values for the widget.
      @row_adjust = 0
      @col_adjust = 0

      # If the height is a negative value, the height will be
      # ROWS-height, otherwise the height will be the given height.
      box_height = CDK.setWidgetDimension(parent_height, height, rows + 1)

      # If the width is a negative value, the width will be
      # COLS-width, otherwise the width will be the given width.
      box_width = CDK.setWidgetDimension(parent_width, width, 0)

      box_width = self.setTitle(title, box_width)

      # Translate the buttons string to a chtype array
      (0...button_count).each do |x|
        button_len = []
        @button << CDK.char2Chtype(buttons[x], button_len ,[]) 
        @button_len << button_len[0]
      end

      # Set the button positions.
      (0...cols).each do |x|
        max_col_width = -2**31

        # Look for the widest item in this column.
        (0...rows).each do |y|
          if current_button < button_count
            max_col_width = [@button_len[current_button], max_col_width].max
            current_button += 1
          end
        end

        # Keep the maximum column width for this column.
        @column_widths << max_col_width
        col_width += max_col_width
      end
      box_width += 1

      # Make sure we didn't extend beyond the dimensions of the window.
      box_width = [box_width, parent_width].min
      box_height = [box_height, parent_height].min

      # Now we have to readjust the x and y positions
      xtmp = [x_pos]
      ytmp = [y_pos]
      CDK.alignxy(cdkscreen.window, xtmp, ytmp, box_width, box_height)
      xpos = xtmp[0]
      ypos = ytmp[0]

      # Set up the buttonbox box attributes.
      @screen = cdkscreen
      @parent = cdkscreen.window
      @win = Ncurses::WINDOW.new(box_height, box_width, ypos, xpos)
      @shadow_win = nil
      @button_count = button_count
      @current_button = 0
      @rows = rows
      @cols = [button_count, cols].min
      @box_height = box_height
      @box_width = box_width
      @highlight = highlight
      @accepts_focus = true
      @input_window = @win
      @shadow = shadow
      @button_attrib = Ncurses::A_NORMAL

      # Set up the row adjustment.
      if box_height - rows - @title_lines > 0
        @row_adjust = (box_height - rows - @title_lines) / @rows
      end

      # Set the col adjustment
      if box_width - col_width > 0
        @col_adjust = ((box_width - col_width) / @cols) - 1
      end

      # If we couldn't create the window, we should return a null value.
      if @win.nil?
        self.destroy
        return nil
      end
      @win.keypad(true)

      # Was there a shadow?
      if shadow
        @shadow_win = Ncurses::WINDOW.new(box_height, box_width,
            ypos + 1, xpos + 1)
      end

      # Register this baby.
      cdkscreen.register(:BUTTONBOX, self)
    end

    # This activates the widget.
    def activate(actions)
      # Draw the buttonbox box.
      self.draw(@box)

      if actions.nil? || actions.size == 0
        while true
          input = self.getch([])

          # Inject the characer into the widget.
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

    # This injects a single character into the widget.
    def inject(input)
      first_button = 0
      last_button = @button_count - 1
      pp_return = 1
      ret = -1
      complete = false

      # Set the exit type
      self.setExitType(0)

      unless @pre_process_func.nil?
        pp_return = @pre_process_func.call(:BUTTONBOX, self,
            @pre_process_data, input)
      end

      # Should we continue?
      if pp_return != 0
        # Check for a key binding.
        if self.checkBind(:BUTTONBOX, input)
          complete = true
        else
          case input
          when Ncurses::KEY_LEFT, Ncurses::KEY_BTAB, Ncurses::KEY_BACKSPACE
            if @current_button - @rows < first_button
              @current_button = last_button
            else
              @current_button -= @rows
            end
          when Ncurses::KEY_RIGHT, CDK::KEY_TAB, ' '.ord
            if @current_button + @rows > last_button
              @current_button = first_button
            else
              @current_button += @rows
            end
          when Ncurses::KEY_UP
            if @current_button -1 < first_button
              @current_button = last_button
            else
              @current_button -= 1
            end
          when Ncurses::KEY_DOWN
            if @current_button + 1 > last_button
              @current_button = first_button
            else
              @current_button += 1
            end
          when CDK::REFRESH
            @screen.erase
            @screen.refresh
          when CDK::KEY_ESC
            self.setExitType(input)
            complete = true
          when Ncurses::ERR
            self.setExitType(input)
            complete = true
          when CDK::KEY_RETURN, Ncurses::KEY_ENTER
            self.setExitType(input)
            ret = @current_button
            complete = true
          end
        end

        if !complete && !(@post_process_func.nil?)
          @post_process_func.call(:BUTTONBOX, self, @post_process_data,
              input)
        end

      end
        
      unless complete
        self.drawButtons
        self.setExitType(0)
      end

      @result_data = ret
      return ret
    end

    # This sets multiple attributes of the widget.
    def set(highlight, box)
      self.setHighlight(highlight)
      self.setBox(box)
    end

    # This sets the highlight attribute for the buttonboxes
    def setHighlight(highlight)
      @highlight = highlight
    end

    def getHighlight
      return @highlight
    end

    # This sets th background attribute of the widget.
    def setBKattr(attrib)
      @win.wbkgd(attrib)
    end

    # This draws the buttonbox box widget.
    def draw(box)
      # Is there a shadow?
      unless @shadow_win.nil?
        Draw.drawShadow(@shadow_win)
      end

      # Box the widget if they asked.
      if box
        Draw.drawObjBox(@win, self)
      end

      # Draw in the title if there is one.
      self.drawTitle(@win)

      # Draw in the buttons.
      self.drawButtons
    end

    # This draws the buttons on the button box widget.
    def drawButtons
      row = @title_lines + 1
      col = @col_adjust / 2
      current_button = 0
      cur_row = -1
      cur_col = -1

      # Draw the buttons.
      while current_button < @button_count
        (0...@cols).each do |x|
          row = @title_lines + @border_size

          (0...@rows).each do |y|
            attr = @button_attrib
            if current_button == @current_button
              attr = @highlight
              cur_row = row
              cur_col = col
            end
            Draw.writeChtypeAttrib(@win, col, row,
                @button[current_button], attr, CDK::HORIZONTAL, 0,
                @button_len[current_button])
            row += (1 + @row_adjust)
            current_button += 1
          end
          col += @column_widths[x] + @col_adjust + @border_size
        end
      end

      if cur_row >= 0 && cur_col >= 0
        @win.wmove(cur_row, cur_col)
      end
      @win.wrefresh
    end

    # This erases the buttonbox box from the screen.
    def erase
      if self.validCDKObject
        CDK.eraseCursesWindow(@win)
        CDK.eraseCursesWindow(@shadow_win)
      end
    end

    # This destroys the widget
    def destroy
      self.cleanTitle

      CDK.deleteCursesWindow(@shadow_win)
      CDK.deleteCursesWindow(@win)

      self.cleanBindings(:BUTTONBOX)

      CDK::SCREEN.unregister(:BUTTONBOX, self)
    end

    def setCurrentButton(button)
      if button >= 0 && button < @button_count
        @current_button = button
      end
    end

    def getCurrentButton
      @current_button
    end

    def getButtonCount
      @button_count
    end

    def focus
      self.draw(@box)
    end

    def unfocus
      self.draw(@box)
    end

    def object_type
      :BUTTONBOX
    end

    def position
      super(@win)
    end
  end
end
