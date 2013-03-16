require_relative 'cdk_objs'

module CDK
  class ITEMLIST < CDK::CDKOBJS
    def initialize(cdkscreen, xplace, yplace, title, label, item, count,
        default_item, box, shadow)
      super()
      parent_width = cdkscreen.window.getmaxx
      parent_height = cdkscreen.window.getmaxy
      field_width = 0

      if !self.createList(item, count)
        self.destroy
        return nil
      end

      self.setBox(box)
      box_height = (@border_size * 2) + 1

      # Set some basic values of the item list
      @label = ''
      @label_len = 0
      @label_win = nil

      # Translate the label string to a chtype array
      if !(label.nil?) && label.size > 0
        label_len = []
        @label = CDK.char2Chtype(label, label_len, [])
        @label_len = label_len[0]
      end

      # Set the box width. Allow an extra char in field width for cursor
      field_width = self.maximumFieldWidth + 1
      box_width = field_width + @label_len + 2 * @border_size
      box_width = self.setTitle(title, box_width)
      box_height += @title_lines

      # Make sure we didn't extend beyond the dimensions of the window
      @box_width = [box_width, parent_width].min
      @box_height = [box_height, parent_height].min
      self.updateFieldWidth

      # Rejustify the x and y positions if we need to.
      xtmp = [xplace]
      ytmp = [yplace]
      CDK.alignxy(cdkscreen.window, xtmp, ytmp, box_width, box_height)
      xpos = xtmp[0]
      ypos = ytmp[0]

      # Make the window.
      @win = Ncurses::WINDOW.new(box_height, box_width, ypos, xpos)
      if @win.nil?
        self.destroy
        return nil
      end

      # Make the label window if there was a label.
      if @label.size > 0
        @label_win = @win.subwin(1, @label_len,
            ypos + @border_size + @title_lines,
            xpos + @border_size)

        if @label_win.nil?
          self.destroy
          return nil
        end
      end

      @win.keypad(true)

      # Make the field window.
      if !self.createFieldWin(
          ypos + @border_size + @title_lines,
          xpos + @label_len + @border_size)
        self.destroy
        return nil
      end

      # Set up the rest of the structure
      @screen = cdkscreen
      @parent = cdkscreen.window
      @shadow_win = nil
      @accepts_focus = true
      @shadow = shadow

      # Set the default item.
      if default_item >= 0 && default_item < @list_size
        @current_item = default_item
        @default_item = default_item
      else
        @current_item = 0
        @default_item = 0
      end

      # Do we want a shadow?
      if shadow
        @shadow_win = Ncurses::WINDOW.new(box_height, box_width,
            ypos + 1, xpos + 1)
        if @shadow_win.nil?
          self.destroy
          return nil
        end
      end

      # Register this baby.
      cdkscreen.register(:ITEMLIST, self)
    end

    # This allows the user to play with the widget.
    def activate(actions)
      ret = -1

      # Draw the widget.
      self.draw(@box)
      self.drawField(true)

      if actions.nil? || actions.size == 0
        input = 0
        
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

      # Set the exit type and exit.
      self.setExitType(0)
      return ret
    end

    # This injects a single character into the widget.
    def inject(input)
      pp_return = 1
      ret = -1
      complete = false

      # Set the exit type.
      self.setExitType(0)

      # Draw the widget field
      self.drawField(true)

      # Check if there is a pre-process function to be called.
      unless @pre_process_func.nil?
        pp_return = @pre_process_func.call(:ITEMLIST, self,
            @pre_process_data, input)
      end

      # Should we continue?
      if pp_return != 0
        # Check a predefined binding.
        if self.checkBind(:ITEMLIST, input)
          complete = true
        else
          case input
          when Ncurses::KEY_UP, Ncurses::KEY_RIGHT, ' '.ord, '+'.ord, 'n'.ord
            if @current_item < @list_size - 1
              @current_item += 1
            else
              @current_item = 0
            end
          when Ncurses::KEY_DOWN, Ncurses::KEY_LEFT, '-'.ord, 'p'.ord
            if @current_item > 0
              @current_item -= 1
            else
              @current_item = @list_size - 1
            end
          when 'd'.ord, 'D'.ord
            @current_item = @default_item
          when '0'.ord
            @current_item = 0
          when '$'.ord
            @current_item = @list_size - 1
          when CDK::KEY_ESC
            self.setExitType(input)
            complete = true
          when Ncurses::ERR
            self.setExitType(input)
            complete = true
          when CDK::KEY_TAB, CDK::KEY_RETURN, Ncurses::KEY_ENTER
            self.setExitType(input)
            ret = @current_item
            complete = true
          when CDK::REFRESH
            @screen.erase
            @screen.refresh
          else
            CDK.Beep
          end
        end

        # Should we call a post-process?
        if !complete && !(@post_process_func.nil?)
          @post_process_func.call(:ITEMLIST, self, @post_process_data, input)
        end
      end

      if !complete
        self.drawField(true)
        self.setExitType(0)
      end

      @result_data = ret
      return ret
    end

    # This moves the itemlist field to the given location.
    def move(xplace, yplace, relative, refresh_flag)
      windows = [@win, @field_win, @label_win, @shadow_win]
      self.move_specific(xplace, yplace, relative, refresh_flag,
          windows, [])
    end

    # This draws the widget on the screen.
    def draw(box)
      # Did we ask for a shadow?
      unless @shadow_win.nil?
        Draw.drawShadow(@shadow_win)
      end

      self.drawTitle(@win)

      # Draw in the label to the widget.
      unless @label_win.nil?
        Draw.writeChtype(@label_win, 0, 0, @label, CDK::HORIZONTAL,
            0, @label.size)
      end

      # Box the widget if asked.
      if box
        Draw.drawObjBox(@win, self)
      end

      @win.wrefresh

      # Draw in the field.
      self.drawField(false)
    end

    # This sets the background attribute of the widget
    def setBKattr(attrib)
      @win.wbkgd(attrib)
      @field_win.wbkgd(attrib)
      unless @label_win.nil?
        @label_win.wbkgd(attrib)
      end
    end

    # This function draws the contents of the field.
    def drawField(highlight)
      # Declare local vars.
      current_item = @current_item

      # Determine how much we have to draw.
      len = [@item_len[current_item], @field_width].min

      # Erase the field window.
      @field_win.werase

      # Draw in the current item in the field.
      (0...len).each do |x|
        c = @item[current_item][x]

        if highlight
          c = c.ord | Ncurses::A_REVERSE
        end

        @field_win.mvwaddch(0, x + @item_pos[current_item], c)
      end

      # Redraw the field window.
      @field_win.wrefresh
    end

    # This function removes the widget from the screen.
    def erase
      if self.validCDKObject
        CDK.eraseCursesWindow(@field_win)
        CDK.eraseCursesWindow(@label_win)
        CDK.eraseCursesWindow(@win)
        CDK.eraseCursesWindow(@shadow_win)
      end
    end

    def destroyInfo
      @list_size = 0
      @item = ''
    end

    # This function destroys the widget and all the memory it used.
    def destroy
      self.cleanTitle
      self.destroyInfo

      # Delete the windows
      CDK.deleteCursesWindow(@field_win)
      CDK.deleteCursesWindow(@label_win)
      CDK.deleteCursesWindow(@shadow_win)
      CDK.deleteCursesWindow(@win)

      # Clean the key bindings.
      self.cleanBindings(:ITEMLIST)

      CDK::SCREEN.unregister(:ITEMLIST, self)
    end

    # This sets multiple attributes of the widget.
    def set(list, count, current, box)
      self.setValues(list, count, current)
      self.setBox(box)
    end

    # This function sets the contents of the list
    def setValues(item, count, default_item)
      if self.createList(item, count)
        old_width = @field_width

        # Set the default item.
        if default_item >= 0 && default_item < @list_size
          @current_item = default_item
          @default_item = default_item
        end

        # This will not resize the outer windows but can still make a usable
        # field width if the title made the outer window wide enough
        self.updateFieldWidth
        if @field_width > old_width
          self.createFieldWin(@field_win.getbegy, @field_win.getbegx)
        end

        # Draw the field.
        self.erase
        self.draw(@box)
      end
    end

    def getValues(size)
      size << @list_size
      return @item
    end

    # This sets the default/current item of the itemlist
    def setCurrentItem(current_item)
      # Set the default item.
      if current_item >= 0 && current_item < @list_size
        @current_item = current_item
      end
    end

    def getCurrentItem
      return @current_item
    end

    # This sets the default item in the list.
    def setDefaultItem(default_item)
      # Make sure the item is in the correct range.
      if default_item < 0
        @default_item = 0
      elsif default_item >= @list_size
        @default_item = @list_size - 1
      else
        @default_item = default_item
      end
    end
    
    def getDefaultItem
      return @default_item
    end

    def focus
      self.drawField(true)
    end

    def unfocus
      self.drawField(false)
    end

    def createList(item, count)
      status = false
      new_items = []
      new_pos = []
      new_len = []
      if count >= 0
        field_width = 0

        # Go through the list and determine the widest item.
        status = true
        (0...count).each do |x|
          # Copy the item to the list.
          lentmp = []
          postmp = []
          new_items << CDK.char2Chtype(item[x], lentmp, postmp)
          new_len << lentmp[0]
          new_pos << postmp[0]
          if new_items[0] == 0
            status = false
            break
          end
          field_width = [field_width, new_len[x]].max
        end

        # Now we need to justify the strings.
        (0...count).each do |x|
          new_pos[x] = CDK.justifyString(field_width + 1,
              new_len[x], new_pos[x])
        end

        if status
          self.destroyInfo

          # Copy in the new information
          @list_size = count
          @item = new_items
          @item_pos = new_pos
          @item_len = new_len
        end
      else
        self.destroyInfo
        status = true
      end

      return status
    end

    # Go through the list and determine the widest item.
    def maximumFieldWidth
      max_width = -2**30

      (0...@list_size).each do |x|
        max_width = [max_width, @item_len[x]].max
      end
      max_width = [max_width, 0].max

      return max_width
    end

    def updateFieldWidth
      want = self.maximumFieldWidth + 1
      have = @box_width - @label_len - 2 * @border_size
      @field_width = [want, have].min
    end

    # Make the field window.
    def createFieldWin(ypos, xpos)
      @field_win = @win.subwin(1, @field_width, ypos, xpos)
      unless @field_win.nil?
        @field_win.keypad(true)
        @input_window = @field_win
        return true
      end
      return false
    end

    def position
      super(@win)
    end

    def object_type
      :ITEMLIST
    end
  end
end
