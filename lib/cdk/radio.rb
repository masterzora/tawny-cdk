require_relative 'scroller'

module CDK
  class RADIO < CDK::SCROLLER
    def initialize(cdkscreen, xplace, yplace, splace, height, width, title,
        list, list_size, choice_char, def_item, highlight, box, shadow)
      super()
      parent_width = cdkscreen.window.getmaxx
      parent_height = cdkscreen.window.getmaxy
      box_width = width
      box_height = height
      widest_item = 0

      bindings = {
        CDK::BACKCHAR => Ncurses::KEY_PPAGE,
        CDK::FORCHAR  => Ncurses::KEY_NPAGE,
        'g'           => Ncurses::KEY_HOME,
        '1'           => Ncurses::KEY_HOME,
        'G'           => Ncurses::KEY_END,
        '<'           => Ncurses::KEY_HOME,
        '>'           => Ncurses::KEY_END,
      }
      
      self.setBox(box)

      # If the height is a negative value, height will be ROWS-height,
      # otherwise the height will be the given height.
      box_height = CDK.setWidgetDimension(parent_height, height, 0)

      # If the width is a negative value, the width will be COLS-width,
      # otherwise the width will be the given width.
      box_width = CDK.setWidgetDimension(parent_width, width, 5)

      box_width = self.setTitle(title, box_width)

      # Set the box height.
      if @title_lines > box_height
        box_height = @title_lines + [list_size, 8].min + 2 * @border_size
      end

      # Adjust the box width if there is a scroll bar.
      if splace == CDK::LEFT || splace == CDK::RIGHT
        box_width += 1
        @scrollbar = true
      else
        scrollbar = false
      end

      # Make sure we didn't extend beyond the dimensions of the window
      @box_width = [box_width, parent_width].min
      @box_height = [box_height, parent_height].min

      self.setViewSize(list_size)

      # Each item in the needs to be converted to chtype array
      widest_item = self.createList(list, list_size, @box_width)
      if widest_item > 0
        self.updateViewWidth(widest_item)
      elsif list_size > 0
        self.destroy
        return nil
      end

      # Rejustify the x and y positions if we need to.
      xtmp = [xplace]
      ytmp = [yplace]
      CDK.alignxy(cdkscreen.window, xtmp, ytmp, @box_width, @box_height)
      xpos = xtmp[0]
      ypos = ytmp[0]

      # Make the radio window
      @win = Ncurses::WINDOW.new(@box_height, @box_width, ypos, xpos)

      # Is the window nil?
      if @win.nil?
        self.destroy
        return nil
      end

      # Turn on the keypad.
      @win.keypad(true)

      # Create the scrollbar window.
      if splace == CDK::RIGHT
        @scrollbar_win = @win.subwin(self.maxViewSize, 1,
            self.SCREEN_YPOS(ypos), xpos + @box_width - @border_size - 1)
      elsif splace == CDK::LEFT
        @scrollbar_win = @win.subwin(self.maxViewSize, 1,
            self.SCREEN_YPOS(ypos), self.SCREEN_XPOS(xpos))
      else
        @scrollbar_win = nil
      end

      # Set the rest of the variables
      @screen = cdkscreen
      @parent = cdkscreen.window
      @scrollbar_placement = splace
      @widest_item = widest_item
      @left_char = 0
      @selected_item = 0
      @highlight = highlight
      @choice_char = choice_char.ord
      @left_box_char = '['.ord
      @right_box_char = ']'.ord
      @def_item = def_item
      @input_window = @win
      @accepts_focus = true
      @shadow = shadow

      self.setCurrentItem(0)

      # Do we need to create the shadow?
      if shadow
        @shadow_win = Ncurses::WINDOW.new(box_height, box_width + 1,
            ypos + 1, xpos + 1)
      end

      # Setup the key bindings
      bindings.each do |from, to|
        self.bind(:RADIO, from, :getc, to)
      end

      cdkscreen.register(:RADIO, self)
    end

    # Put the cursor on the currently-selected item.
    def fixCursorPosition
      scrollbar_adj = if @scrollbar_placement == CDK::LEFT then 1 else 0 end
      ypos = self.SCREEN_YPOS(@current_item - @current_top)
      xpos = self.SCREEN_XPOS(0) + scrollbar_adj

      @input_window.wmove(ypos, xpos)
      @input_window.wrefresh
    end

    # This actually manages the radio widget.
    def activate(actions)
      # Draw the radio list.
      self.draw(@box)

      if actions.nil? || actions.size == 0
        while true
          self.fixCursorPosition
          input = self.getch([])

          # Inject the character into the widget.
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

      # Set the exit type and return
      self.setExitType(0)
      return -1
    end

    # This injects a single character into the widget.
    def inject(input)
      pp_return = 1
      ret = -1
      complete = false

      # Set the exit type
      self.setExitType(0)

      # Draw the widget list
      self.drawList(@box)

      # Check if there is a pre-process function to be called
      unless @pre_process_func.nil?
        # Call the pre-process function.
        pp_return = @pre_process_func.call(:RADIO, self,
            @pre_process_data, input)
      end

      # Should we continue?
      if pp_return != 0
        # Check for a predefined key binding.
        if self.checkBind(:RADIO, input)
          complete = true
        else
          case input
          when Ncurses::KEY_UP
            self.KEY_UP
          when Ncurses::KEY_DOWN
            self.KEY_DOWN
          when Ncurses::KEY_RIGHT
            self.KEY_RIGHT
          when Ncurses::KEY_LEFT
            self.KEY_LEFT
          when Ncurses::KEY_PPAGE
            self.KEY_PPAGE
          when Ncurses::KEY_NPAGE
            self.KEY_NPAGE
          when Ncurses::KEY_HOME
            self.KEY_HOME
          when Ncurses::KEY_END
            self.KEY_END
          when '$'.ord
            @left_char = @max_left_char
          when '|'.ord
            @left_char = 0
          when ' '.ord
            @selected_item = @current_item
          when CDK::KEY_ESC
            self.setExitType(input)
            ret = -1
            complete = true
          when Ncurses::ERR
            self.setExitType(input)
            complete = true
          when CDK::KEY_TAB, CDK::KEY_RETURN, Ncurses::KEY_ENTER
            self.setExitType(input)
            ret = @selected_item
            complete = true
          when CDK::REFRESH
            @screen.erase
            @screen.refresh
          end
        end

        # Should we call a post-process?
        if !complete && !(@post_process_func.nil?)
          @post_process_func.call(:RADIO, self, @post_process_data, input)
        end
      end

      if !complete
        self.drawList(@box)
        self.setExitType(0)
      end

      self.fixCursorPosition
      @return_data = ret
      return ret
    end

    # This moves the radio field to the given location.
    def move(xplace, yplace, relative, refresh_flag)
      windows = [@win, @scrollbar_win, @shadow_win]
      self.move_specific(xplace, yplace, relative, refresh_flag,
          windows, subwidgets)
    end

    # This function draws the radio widget.
    def draw(box)
      # Do we need to draw in the shadow?
      if !(@shadow_win.nil?)
        Draw.drawShadow(@shadow_win)
      end

      self.drawTitle(@win)

      # Draw in the radio list.
      self.drawList(@box)
    end

    # This redraws the radio list.
    def drawList(box)
      scrollbar_adj = if @scrollbar_placement == CDK::LEFT then 1 else 0 end
      screen_pos = 0

      # Draw the list
      (0...@view_size).each do |j|
        k = j + @current_top
        if k < @list_size
          xpos = self.SCREEN_XPOS(0)
          ypos = self.SCREEN_YPOS(j)

          screen_pos = self.SCREENPOS(k, scrollbar_adj)

          # Draw the empty string.
          Draw.writeBlanks(@win, xpos, ypos, CDK::HORIZONTAL, 0,
              @box_width - @border_size)

          # Draw the line.
          Draw.writeChtype(@win,
              if screen_pos >= 0 then screen_pos else 1 end,
              ypos, @item[k], CDK::HORIZONTAL,
              if screen_pos >= 0 then 0 else 1 - screen_pos end,
              @item_len[k])

          # Draw the selected choice
          xpos += scrollbar_adj
          @win.mvwaddch(ypos, xpos, @left_box_char)
          @win.mvwaddch(ypos, xpos + 1,
              if k == @selected_item then @choice_char else ' '.ord end)
          @win.mvwaddch(ypos, xpos + 2, @right_box_char)
        end
      end

      # Highlight the current item
      if @has_focus
        k = @current_item
        if k < @list_size
          screen_pos = self.SCREENPOS(k, scrollbar_adj)
          ypos = self.SCREEN_YPOS(@current_high)

          Draw.writeChtypeAttrib(@win,
              if screen_pos >= 0 then screen_pos else 1 + scrollbar_adj end,
              ypos, @item[k], @highlight, CDK::HORIZONTAL,
              if screen_pos >= 0 then 0 else 1 - screen_pos end,
              @item_len[k])
        end
      end

      if @scrollbar
        @toggle_pos = (@current_item * @step).floor
        @toggle_pos = [@toggle_pos, @scrollbar_win.getmaxy - 1].min

        @scrollbar_win.mvwvline(0, 0, Ncurses::ACS_CKBOARD,
            @scrollbar_win.getmaxy)
        @scrollbar_win.mvwvline(@toggle_pos, 0, ' '.ord | Ncurses::A_REVERSE,
            @toggle_size)
      end

      # Box it if needed.
      if box
        Draw.drawObjBox(@win, self)
      end

      self.fixCursorPosition
    end

    # This sets the background attribute of the widget.
    def setBKattr(attrib)
      @win.wbkgd(attrib)
      unless @scrollbar_win.nil?
        @scrollbar_win.wbkgd(attrib)
      end
    end

    def destroyInfo
      @item = ''
    end

    # This function destroys the radio widget.
    def destroy
      self.cleanTitle
      self.destroyInfo

      # Clean up the windows.
      CDK.deleteCursesWindow(@scrollbar_win)
      CDK.deleteCursesWindow(@shadow_win)
      CDK.deleteCursesWindow(@win)

      # Clean up the key bindings.
      self.cleanBindings(:RADIO)

      # Unregister this object.
      CDK::SCREEN.unregister(:RADIO, self)
    end

    # This function erases the radio widget
    def erase
      if self.validCDKObject
        CDK.eraseCursesWindow(@win)
        CDK.eraseCursesWindow(@shadow_win)
      end
    end

    # This sets various attributes of the radio list.
    def set(highlight, choice_char, box)
      self.setHighlight(highlight)
      self.setChoiceCHaracter(choice_char)
      self.setBox(box)
    end

    # This sets the radio list items.
    def setItems(list, list_size)
      widest_item = self.createList(list, list_size, @box_width)
      if widest_item <= 0
        return
      end

      # Clean up the display.
      (0...@view_size).each do |j|
        Draw.writeBlanks(@win, self.SCREEN_XPOS(0), self.SCREEN_YPOS(j),
            CDK::HORIZONTAL, 0, @box_width - @border_size)
      end

      self.setViewSize(list_size)

      self.setCurrentItem(0)
      @left_char = 0
      @selected_item = 0

      self.updateViewWidth(widest_item)
    end

    def getItems(list)
      (0...@list_size).each do |j|
        list << CDK.chtype2Char(@item[j])
      end
      return @list_size
    end

    # This sets the highlight bar of the radio list.
    def setHighlight(highlight)
      @highlight = highlight
    end

    def getHighlight
      return @highlight
    end

    # This sets the character to use when selecting na item in the list.
    def setChoiceCharacter(character)
      @choice_char = character
    end

    def getChoiceCharacter
      return @choice_char
    end

    # This sets the character to use to drw the left side of the choice box
    # on the list
    def setLeftBrace(character)
      @left_box_char = character
    end

    def getLeftBrace
      return @left_box_char
    end

    # This sets the character to use to draw the right side of the choice box
    # on the list
    def setRightBrace(character)
      @right_box_char = character
    end

    def getRightBrace
      return @right_box_char
    end

    # This sets the current highlighted item of the widget
    def setCurrentItem(item)
      self.setPosition(item)
      @selected_item = item
    end

    def getCurrentItem
      return @current_item
    end

    # This sets the selected item of the widget
    def setSelectedItem(item)
      @selected_item = item
    end

    def getSelectedItem
      return @selected_item
    end

    def focus
      self.drawList(@box)
    end

    def unfocus
      self.drawList(@box)
    end

    def createList(list, list_size, box_width)
      status = false
      widest_item = 0

      if list_size >= 0
        new_list = []
        new_len = []
        new_pos = []

        # Each item in the needs to be converted to chtype array
        status = true
        box_width -= 2 + @border_size
        (0...list_size).each do |j|
          lentmp = []
          postmp = []
          new_list << CDK.char2Chtype(list[j], lentmp, postmp)
          new_len << lentmp[0]
          new_pos << postmp[0]
          if new_list[j].nil? || new_list[j].size == 0
            status = false
            break
          end
          new_pos[j] = CDK.justifyString(box_width, new_len[j], new_pos[j]) + 3
          widest_item = [widest_item, new_len[j]].max
        end
        if status
          self.destroyInfo
          @item = new_list
          @item_len = new_len
          @item_pos = new_pos
        end
      end

      return (if status then widest_item else 0 end)
    end

    # Determine how many characters we can shift to the right
    # before all the items have been scrolled off the screen.
    def AvailableWidth
      @box_width - 2 * @border_size - 3
    end

    def updateViewWidth(widest)
      @max_left_char = if @box_width > widest
                       then 0
                       else widest - self.AvailableWidth
                       end
    end

    def WidestItem
      @max_left_char + self.AvailableWidth
    end

    def SCREENPOS(n, scrollbar_adj)
      @item_pos[n] - @left_char + scrollbar_adj + @border_size
    end

    def object_type
      :RADIO
    end
  end
end
