require_relative 'cdk_objs'

module CDK
  class TEMPLATE < CDK::CDKOBJS
    def initialize(cdkscreen, xplace, yplace, title, label, plate,
        overlay, box, shadow)
      super()
      parent_width = cdkscreen.window.getmaxx
      parent_height = cdkscreen.window.getmaxy
      box_width = 0
      box_height = if box then 3 else 1 end
      plate_len = 0

      if plate.nil? || plate.size == 0
        return nil
      end

      self.setBox(box)

      field_width = plate.size + 2 * @border_size

      # Set some basic values of the template field.
      @label = []
      @label_len = 0
      @label_win = nil

      # Translate the label string to achtype array
      if !(label.nil?) && label.size > 0
        label_len = []
        @label = CDK.char2Chtype(label, label_len, [])
        @label_len = label_len[0]
      end

      # Translate the char * overlay to a chtype array
      if !(overlay.nil?) && overlay.size > 0
        overlay_len = []
        @overlay = CDK.char2Chtype(overlay, overlay_len, [])
        @overlay_len = overlay_len[0]
        @field_attr = @overlay[0] & Ncurses::A_ATTRIBUTES
      else
        @overlay = []
        @overlay_len = 0
        @field_attr = Ncurses::A_NORMAL
      end

      # Set the box width.
      box_width = field_width + @label_len + 2 * @border_size

      old_width = box_width
      box_width = self.setTitle(title, box_width)
      horizontal_adjust = (box_width - old_width) / 2

      box_height += @title_lines

      # Make sure we didn't extend beyond the dimensions of the window.
      box_width = [box_width, parent_width].min
      box_height = [box_height, parent_height].min
      field_width = [field_width,
          box_width - @label_len - 2 * @border_size].min

      # Rejustify the x and y positions if we need to.
      xtmp = [xplace]
      ytmp = [yplace]
      CDK.alignxy(cdkscreen.window, xtmp, ytmp, box_width, box_height)
      xpos = xtmp[0]
      ypos = ytmp[0]

      # Make the template window
      @win = Ncurses::WINDOW.new(box_height, box_width, ypos, xpos)

      # Is the template window nil?
      if @win.nil?
        self.destroy
        return nil
      end
      @win.keypad(true)

      # Make the label window.
      if label.size > 0
        @label_win = @win.subwin(1, @label_len,
            ypos + @title_lines + @border_size,
            xpos + horizontal_adjust + @border_size)
      end

      # Make the field window
      @field_win = @win.subwin(1, field_width,
            ypos + @title_lines + @border_size,
            xpos + @label_len + horizontal_adjust + @border_size)
      @field_win.keypad(true)

      # Set up the info field.
      @plate_len = plate.size
      @info = ''
      # Copy the plate to the template
      @plate = plate.clone

      # Set up the rest of the structure.
      @screen = cdkscreen
      @parent = cdkscreen.window
      @shadow_win = nil
      @field_width = field_width
      @box_height = box_height
      @box_width = box_width
      @plate_pos = 0
      @screen_pos = 0
      @info_pos = 0
      @min = 0
      @input_window = @win
      @accepts_focus = true
      @shadow = shadow
      @callbackfn = lambda do |template, input|
        failed = false
        change = false
        moveby = false
        amount = 0
        mark = @info_pos
        have = @info.size

        if input == Ncurses::KEY_LEFT
          if mark != 0
            moveby = true
            amount = -1
          else
            failed = true
          end
        elsif input == Ncurses::KEY_RIGHT
          if mark < @info.size
            moveby = true
            amount = 1
          else
            failed = true
          end
        else
          test = @info.clone
          if input == Ncurses::KEY_BACKSPACE
            if mark != 0
              front = @info[0...mark-1] || ''
              back = @info[mark..-1] || ''
              test = front + back
              change = true
              amount = -1
            else
              failed = true
            end
          elsif input == Ncurses::KEY_DC
            if mark < @info.size
              front = @info[0...mark] || ''
              back = @info[mark+1..-1] || ''
              test = front + back
              change = true
              amount = 0
            else
              failed = true
            end
          elsif CDK.isChar(input) && @plate_pos < @plate.size
            test[mark] = input.chr
            change = true
            amount = 1
          else
            failed = true
          end

          if change
            if self.validTemplate(test)
              @info = test
              self.drawField
            else
              failed = true
            end
          end
        end

        if failed
          CDK.Beep
        elsif change || moveby
          @info_pos += amount
          @plate_pos += amount
          @screen_pos += amount

          self.adjustCursor(amount)
        end
      end

      # Do we need to create a shadow?
      if shadow
        @shadow_win = Ncurses::WINDOW.new(box_height, box_width,
            ypos + 1, xpos + 1)
      end

      cdkscreen.register(:TEMPLATE, self)
    end

    # This actually manages the tempalte widget
    def activate(actions)
      self.draw(@box)

      if actions.nil? || actions.size == 0
        while true
          input = self.getch([])

          # Inject each character into the widget.
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

      # Set the exit type and return.
      self.setExitType(0)
      return ret
    end

    # This injects a character into the widget.
    def inject(input)
      pp_return = 1
      complete = false
      ret = -1

      self.setExitType(0)

      # Move the cursor.
      self.drawField

      # Check if there is a pre-process function to be called.
      unless @pre_process_func.nil?
        pp_return = @pre_process_func.call(:TEMPLATE, self,
            @pre_process_data, input)
      end

      # Should we continue?
      if pp_return != 0
        # Check a predefined binding
        if self.checkBind(:TEMPLATE, input)
          complete = true
        else
          case input
          when CDK::ERASE
            if @info.size > 0
              self.clean
              self.drawField
            end
          when CDK::CUT
            if @info.size > 0
              @@g_paste_buffer = @info.clone
              self.clean
              self.drawField
            else
              CDK.Beep
            end
          when CDK::COPY
            if @info.size > 0
              @@g_paste_buffer = @info.clone
            else
              CDK.Beep
            end
          when CDK::PASTE
            if @@g_paste_buffer.size > 0
              self.clean

              # Start inserting each character one at a time.
              (0...@@g_paste_buffer.size).each do |x|
                @callbackfn.call(self, @@g_paste_buffer[x])
              end
              self.drawField
            else
              CDK.Beep
            end
          when CDK::KEY_TAB, CDK::KEY_RETURN, Ncurses::KEY_ENTER
            if @info.size < @min
              CDK.Beep
            else
              self.setExitType(input)
              ret = @info
              complete = true
            end
          when CDK::KEY_ESC
            self.setExitType(input)
            complete = true
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

        # Should we call a post-process?
        if !complete && !(@post_process_func.nil?)
          @post_process_func.call(:TEMPLATE, self, @post_process_data, input)
        end
      end

      if !complete
        self.setExitType(0)
      end

      @return_data = ret
      return ret
    end

    def validTemplate(input)
      pp = 0
      ip = 0
      while ip < input.size && pp < @plate.size
        newchar = input[ip]
        while pp < @plate.size && !CDK::TEMPLATE.isPlateChar(@plate[pp])
          pp += 1
        end
        if pp == @plate.size
          return false
        end

        # Check if the input matches the plate
        if CDK.digit?(newchar) && 'ACc'.include?(@plate[pp])
          return false
        end
        if !CDK.digit?(newchar) && @plate[pp] == '#'
          return false
        end

        # Do we need to convert the case?
        if @plate[pp] == 'C' || @plate[pp] == 'X'
          newchar = newchar.upcase
        elsif @plate[pp] == 'c' || @plate[pp] == 'x'
          newchar = newchar.downcase
        end
        input[ip] = newchar
        ip += 1
        pp += 1
      end
      return true
    end

    # Return a mixture of the plate-overlay and field-info
    def mix
      mixed_string = ''
      plate_pos = 0
      info_pos = 0

      if @info.size > 0
        mixed_string = ''
        while plate_pos < @plate_len && info_pos < @info.size
          mixed_string << if CDK::TEMPLATE.isPlateChar(@plate[plate_pos])
                          then info_pos += 1; @info[info_pos - 1]
                          else @plate[plate_pos]
                          end
          plate_pos += 1
        end
      end

      return mixed_string
    end

    # Return the field_info from the mixed string.
    def unmix(info)
      pos = 0
      unmixed_string = ''

      while pos < @info.size
        if CDK::TEMPLATE.isPlateChar(@plate[pos])
          unmixed_string << info[pos]
        end
        pos += 1
      end

      return unmixed_string
    end

    # Move the template field to the given location.
    def move(xplace, yplace, relative, refresh_flag)
      windows = [@win, @label_win, @field_win, @shadow_win]
      self.move_specific(xplace, yplace, relative, refresh_flag,
          windows, [])
    end

    # Draw the template widget.
    def draw(box)
      # Do we need to draw the shadow.
      unless @shadow_win.nil?
        Draw.drawShadow(@shadow_win)
      end

      # Box it if needed
      if box
        Draw.drawObjBox(@win, self)
      end

      self.drawTitle(@win)

      @win.wrefresh

      self.drawField
    end

    # Draw the template field
    def drawField
      field_color = 0
      
      # Draw in the label and the template object.
      unless @label_win.nil?
        Draw.writeChtype(@label_win, 0, 0, @label, CDK::HORIZONTAL,
            0, @label_len)
        @label_win.wrefresh
      end

      # Draw in the template
      if @overlay.size > 0
        Draw.writeChtype(@field_win, 0, 0, @overlay, CDK::HORIZONTAL,
            0, @overlay_len)
      end

      # Adjust the cursor.
      if @info.size > 0
        pos = 0
        (0...[@field_width, @plate.size].min).each do |x|
          if CDK::TEMPLATE.isPlateChar(@plate[x]) && pos < @info.size
            field_color = @overlay[x] & Ncurses::A_ATTRIBUTES
            @field_win.mvwaddch(0, x, @info[pos].ord | field_color)
            pos += 1
          end
        end
        @field_win.wmove(0, @screen_pos)
      else
        self.adjustCursor(1)
      end
      @field_win.wrefresh
    end

    # Adjust the cursor for the template
    def adjustCursor(direction)
      while @plate_pos < [@field_width, @plate.size].min &&
          !CDK::TEMPLATE.isPlateChar(@plate[@plate_pos])
        @plate_pos += direction
        @screen_pos += direction
      end
      @field_win.wmove(0, @screen_pos)
      @field_win.wrefresh
    end

    # Set the background attribute of the widget.
    def setBKattr(attrib)
      @win.wbkgd(attrib)
      @field_win.wbkgd(attrib)
      unless @label_win.nil?
        @label_win.wbkgd(attrib)
      end
    end

    # Destroy this widget.
    def destroy
      self.cleanTitle

      # Delete the windows
      CDK.deleteCursesWindow(@field_win)
      CDK.deleteCursesWindow(@label_win)
      CDK.deleteCursesWindow(@shadow_win)
      CDK.deleteCursesWindow(@win)

      # Clean the key bindings.
      self.cleanBindings(:TEMPLATE)

      CDK::SCREEN.unregister(:TEMPLATE, self)
    end

    # Erase the widget.
    def erase
      if self.validCDKObject
        CDK.eraseCursesWindow(@field_win)
        CDK.eraseCursesWindow(@label_win)
        CDK.eraseCursesWindow(@shadow_win)
        CDK.eraseCursesWindow(@win)
      end
    end

    # Set the value given to the template
    def set(new_value, box)
      self.setValue(new_value)
      self.setBox(box)
    end

    # Set the value given to the template.
    def setValue(new_value)
      len = 0

      # Just to be sure, let's make sure the new value isn't nil
      if new_value.nil?
        self.clean
        return
      end

      # Determine how many characters we need to copy.
      copychars = [@new_value.size, @field_width, @plate.size].min

      @info = new_value[0...copychars]

      # Use the function which handles the input of the characters.
      (0...new_value.size).each do |x|
        @callbackfn.call(self, new_value[x].ord)
      end
    end

    def getValue
      return @info
    end

    # Set the minimum number of characters to enter into the widget.
    def setMin(min)
      if min >= 0
        @min = min
      end
    end

    def getMin
      return @min
    end

    # Erase the information in the template widget.
    def clean
      @info = ''
      @screen_pos = 0
      @info_pos = 0
      @plaste_pos = 0
    end

    # Set the callback function for the widget.
    def setCB(callback)
      @callbackfn = callback
    end

    def focus
      self.draw(@box)
    end

    def unfocus
      self.draw(@box)
    end

    def self.isPlateChar(c)
      '#ACcMXz'.include?(c.chr)
    end

    def position
      super(@win)
    end

    def object_type
      :TEMPLATE
    end
  end
end
