require_relative 'cdk_objs'

module CDK
  class VIEWER < CDK::CDKOBJS
    DOWN = 0
    UP = 1

    def initialize(cdkscreen, xplace, yplace, height, width,
        buttons, button_count, button_highlight, box, shadow)
      super()
      parent_width = cdkscreen.window.getmaxx
      parent_height = cdkscreen.window.getmaxy
      box_width = width
      box_height = height
      button_width = 0
      button_adj = 0
      button_pos = 1
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

      box_height = CDK.setWidgetDimension(parent_height, height, 0)
      box_width = CDK.setWidgetDimension(parent_width, width, 0)

      # Rejustify the x and y positions if we need to.
      xtmp = [xplace]
      ytmp = [yplace]
      CDK.alignxy(cdkscreen.window, xtmp, ytmp, box_width, box_height)
      xpos = xtmp[0]
      ypos = ytmp[0]

      # Make the viewer window.
      @win= Ncurses::WINDOW.new(box_height, box_width, ypos, xpos)
      if @win.nil?
        self.destroy
        return nil
      end

      # Turn the keypad on for the viewer.
      @win.keypad(true)

      # Create the buttons.
      @button_count = button_count
      @button = []
      @button_len = []
      @button_pos = []
      if button_count > 0
        (0...button_count).each do |x|
          button_len = []
          @button << CDK.char2Chtype(buttons[x], button_len, [])
          @button_len << button_len[0]
          button_width += @button_len[x] + 1
        end
        button_adj = (box_width - button_width) / (button_count + 1)
        button_pos = 1 + button_adj
        (0...button_count).each do |x|
          @button_pos << button_pos
          button_pos += button_adj + @button_len[x]
        end
      end

      # Set the rest of the variables.
      @screen = cdkscreen
      @parent = cdkscreen.window
      @shadow_win = nil
      @button_highlight = button_highlight
      @box_height = box_height
      @box_width = box_width - 2
      @view_size = height - 2
      @input_window = @win
      @shadow = shadow
      @current_button = 0
      @current_top = 0
      @length = 0
      @left_char = 0
      @max_left_char = 0
      @max_top_line = 0
      @characters = 0
      @list_size = -1
      @show_line_info = 1
      @exit_type = :EARLY_EXIT

      # Do we need to create a shadow?
      if shadow
        @shadow_win = Ncurses::WINDOW.new(box_height, box_width + 1,
            ypos + 1, xpos + 1)
        if @shadow_win.nil?
          self.destroy
          return nil
        end
      end

      # Setup the key bindings.
      bindings.each do |from, to|
        self.bind(:VIEWER, from, :getc, to)
      end

      cdkscreen.register(:VIEWER, self)
    end

    # This function sets various attributes of the widget.
    def set(title, list, list_size, button_highlight,
        attr_interp, show_line_info, box)
      self.setTitle(title)
      self.setHighlight(button_highlight)
      self.setInfoLine(show_line_info)
      self.setBox(box)
      return self.setInfo(list, list_size, attr_interp)
    end

    # This sets the title of the viewer. (A nil title is allowed.
    # It just means that the viewer will not have a title when drawn.)
    def setTitle(title)
      super(title, -(@box_width + 1))
      @title_adj = @title_lines

      # Need to set @view_size
      @view_size = @box_height - (@title_lines + 1) - 2
    end

    def getTitle
      return @title
    end

    def setupLine(interpret, list, x)
      # Did they ask for attribute interpretation?
      if interpret
        list_len = []
        list_pos = []
        @list[x] = CDK.char2Chtype(list, list_len, list_pos)
        @list_len[x] = list_len[0]
        @list_pos[x] = CDK.justifyString(@box_width, @list_len[x], list_pos[0])
      else
        # We must convert tabs and other nonprinting characters. The curses
        # library normally does this, but we are bypassing it by writing
        # chtypes directly.
        t = ''
        len = 0
        (0...list.size).each do |y|
          if list[y] == "\t".ord
            begin
              t  << ' '
              len += 1
            end while (len & 7) != 0
          elsif CDK.CharOf(list[y].ord).match(/^[[:print:]]$/)
            t << CDK.CharOf(list[y].ord)
            len += 1
          else
            t << Ncurses.unctrl(list[y].ord)
            len += 1
          end
        end
        @list[x] = t
        @list_len[x] = t.size
        @list_pos[x] = 0
      end
      @widest_line = [@widest_line, @list_len[x]].max
    end

    def freeLine(x)
      if x < @list_size
        @list[x] = ''
      end
    end

    # This function sets the contents of the viewer.
    def setInfo(list, list_size, interpret)
      current_line = 0
      viewer_size = list_size

      if list_size < 0
        list_size = list.size
      end

      # Compute the size of the resulting display
      viewer_size = list_size
      if list.size > 0 && interpret
        (0...list_size).each do |x|
          filename = ''
          if CDK.checkForLink(list[x], filename) == 1
            file_contents = []
            file_len = CDK.readFile(filename, file_contents)

            if file_len >= 0
              viewer_size += (file_len - 1)
            end
          end
        end
      end

      # Clean out the old viewer info. (if there is any)
      @in_progress = true
      self.clean
      self.createList(viewer_size)

      # Keep some semi-permanent info
      @interpret = interpret

      # Copy the information given.
      current_line = 0
      x = 0
      while x < list_size && current_line < viewer_size
        if list[x].size == 0
          @list[current_line] = ''
          @list_len[current_line] = 0
          @list_pos[current_line] = 0
          current_line += 1
        else
          # Check if we have a file link in this line.
          filename = []
          if CDK.checkForLink(list[x], filename) == 1
            # We have a link, open the file.
            file_contents = []
            file_len = 0

            # Open the file and put it into the viewer
            file_len = CDK.readFile(filename, file_contents)
            if file_len == -1
              fopen_fmt = if Ncurses.has_colors?
                          then '<C></16>Link Failed: Could not open the file %s'
                          else '<C></K>Link Failed: Could not open the file %s'
                          end
              temp = fopen_fmt % filename
              self.setupLine(true, temp, current_line)
              current_line += 1
            else
              # For each line read, copy it into the viewer.
              file_len = [file_len, viewer_size - current_line].min
              (0...file_len).each do |file_line|
                if current_line >= viewer_size
                  break
                end
                self.setupLine(false, file_contents[file_line], current_line)
                @characters += @list_len[current_line]
                current_line += 1
              end
            end
          elsif current_line < viewer_size
            self.setupLine(@interpret, list[x], current_line)
            @characters += @list_len[current_line]
            current_line += 1
          end
        end
        x+= 1
      end

      # Determine how many characters we can shift to the right before
      # all the items have been viewer off the screen.
      if @widest_line > @box_width
        @max_left_char = (@widest_line - @box_width) + 1
      else
        @max_left_char = 0
      end

      # Set up the needed vars for the viewer list.
      @in_progress = false
      @list_size = viewer_size
      if @list_size <= @view_size
        @max_top_line = 0
      else
        @max_top_line = @list_size - 1
      end
      return @list_size
    end

    def getInfo(size)
      size << @list_size
      return @list
    end

    # This function sets the highlight type of the buttons.
    def setHighlight(button_highlight)
      @button_highlight = button_highlight
    end

    def getHighlight
      return @button_highlight
    end

    # This sets whether or not you wnat to set the viewer info line.
    def setInfoLine(show_line_info)
      @show_line_info = show_line_info
    end

    def getInfoLine
      return @show_line_info
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

    def PatternNotFound(pattern)
      temp_info = [
          "</U/5>Pattern '%s' not found.<!U!5>" % pattern,
      ]
      self.popUpLabel(temp_info)
    end

    # This function actually controls the viewer...
    def activate(actions)
      refresh = false
      # Create the information about the file stats.
      file_info = [
          '</5>      </U>File Statistics<!U>     <!5>',
          '</5>                          <!5>',
          '</5/R>Character Count:<!R> %-4d     <!5>' % @characters,
          '</5/R>Line Count     :<!R> %-4d     <!5>' % @list_size,
          '</5>                          <!5>',
          '<C></5>Press Any Key To Continue.<!5>'
      ]

      temp_info = ['<C></5>Press Any Key To Continue.<!5>']

      # Set the current button.
      @current_button = 0

      # Draw the widget list.
      self.draw(@box)

      # Do this until KEY_ENTER is hit.
      while true
        # Reset the refresh flag.
        refresh = false

        input = self.getch([])
        if !self.checkBind(:VIEWER, input)
          case input
          when CDK::KEY_TAB
            if @button_count > 1
              if @current_button == @button_count - 1
                @current_button = 0
              else
                @current_button += 1
              end

              # Redraw the buttons.
              self.drawButtons
            end
          when CDK::PREV
            if @button_count > 1
              if @current_button == 0
                @current_button = @button_count - 1
              else
                @current_button -= 1
              end

              # Redraw the buttons.
              self.drawButtons
            end
          when Ncurses::KEY_UP
            if @current_top > 0
              @current_top -= 1
              refresh = true
            else
              CDK.Beep
            end
          when Ncurses::KEY_DOWN
            if @current_top < @max_top_line
              @current_top += 1
              refresh = true
            else
              CDK.Beep
            end
          when Ncurses::KEY_RIGHT
            if @left_char < @max_left_char
              @left_char += 1
              refresh = true
            else
              CDK.Beep
            end
          when Ncurses::KEY_LEFT
            if @left_char > 0
              @left_char -= 1
              refresh = true
            else
              CDK.Beep
            end
          when Ncurses::KEY_PPAGE
            if @current_top > 0
              if @current_top - (@view_size - 1) > 0
                @current_top = @current_top - (@view_size - 1)
              else
                @current_top = 0
              end
              refresh = true
            else
              CDK.Beep
            end
          when Ncurses::KEY_NPAGE
            if @current_top < @max_top_line
              if @current_top + @view_size < @max_top_line
                @current_top = @current_top + (@view_size - 1)
              else
                @current_top = @max_top_line
              end
              refresh = true
            else
              CDK.Beep
            end
          when Ncurses::KEY_HOME
            @left_char = 0
            refresh = true
          when Ncurses::KEY_END
            @left_char = @max_left_char
            refresh = true
          when 'g'.ord, '1'.ord, '<'.ord
            @current_top = 0
            refresh = true
          when 'G'.ord, '>'.ord
            @current_top = @max_top_line
            refresh = true
          when 'L'.ord
            x = (@list_size + @current_top) / 2
            if x < @max_top_line
              @current_top = x
              refresh = true
            else
              CDK.Beep
            end
          when 'l'.ord
            x = @current_top / 2
            if x >= 0
              @current_top = x
              refresh = true
            else
              CDK.Beep
            end
          when '?'.ord
            @search_direction = CDK::VIEWER::UP
            self.getAndStorePattern(@screen)
            if !self.searchForWord(@search_pattern, @search_direction)
              self.PatternNotFound(@search_pattern)
            end
            refresh = true
          when '/'.ord
            @search_direction = CDK::VIEWER:DOWN
            self.getAndStorePattern(@screen)
            if !self.searchForWord(@search_pattern, @search_direction)
              self.PatternNotFound(@search_pattern)
            end
            refresh = true
          when 'N'.ord, 'n'.ord
            if @search_pattern == ''
              temp_info[0] = '</5>There is no pattern in the buffer.<!5>'
              self.popUpLabel(temp_info)
            elsif !self.searchForWord(@search_pattern,
                if input == 'n'.ord
                then @search_direction
                else 1 - @search_direction
                end)
              self.PatternNotFound(@search_pattern)
            end
            refresh = true
          when ':'.ord
            @current_top = self.jumpToLine
            refresh = true
          when 'i'.ord, 's'.ord, 'S'.ord
            self.popUpLabel(file_info)
            refresh = true
          when CDK::KEY_ESC
            self.setExitType(input)
            return -1
          when Ncurses::ERR
            self.setExitType(input)
            return -1
          when Ncurses::KEY_ENTER, CDK::KEY_RETURN
            self.setExitType(input)
            return @current_button
          when CDK::REFRESH
            @screen.erase
            @screen.refresh
          else
            CDK.Beep
          end
        end

        # Do we need to redraw the screen?
        if refresh
          self.drawInfo
        end
      end
    end

    # This searches the document looking for the given word.
    def getAndStorePattern(screen)
      temp = ''

      # Check the direction.
      if @search_direction == CDK::VIEWER::UP
        temp = '</5>Search Up  : <!5>'
      else
        temp = '</5>Search Down: <!5>'
      end

      # Pop up the entry field.
      get_pattern = CDK::ENTRY.new(screen, CDK::CENTER, CDK::CENTER,
          '', label, Ncurses.COLOR_PAIR(5) | Ncurses::A_BOLD,
          '.' | Ncurses.COLOR_PAIR(5) | Ncurses::A_BOLD,
          :MIXED, 10, 0, 256, true, false)

      # Is there an old search pattern?
      if @search_pattern.size != 0
        get_pattern.set(@search_pattern, get_pattern.min, get_pattern.max,
            get_pattern.box)
      end

      # Activate this baby.
      list = get_pattern.activate([])

      # Save teh list.
      if list.size != 0
        @search_pattern = list
      end

      # Clean up.
      get_pattern.destroy
    end

    # This searches for a line containing the word and realigns the value on
    # the screen.
    def searchForWord(pattern, direction)
      found = false

      # If the pattern is empty then return.
      if pattern.size != 0
        if direction == CDK::VIEWER::DOWN
          # Start looking from 'here' down.
          x = @current_top + 1
          while !found && x < @list_size
            pos = 0
            y = 0
            while y < @list[x].size
              plain_char = CDK.CharOf(@list[x][y])

              pos += 1
              if @CDK.CharOf(pattern[pos-1]) != plain_char
                y -= (pos - 1)
                pos = 0
              elsif pos == pattern.size
                @current_top = [x, @max_top_line].min
                @left_char = if y < @box_width then 0 else @max_left_char end
                found = true
                break
              end
              y += 1
            end
            x += 1
          end
        else
          # Start looking from 'here' up.
          x = @current_top - 1
          while ! found && x >= 0
            y = 0
            pos = 0
            while y < @list[x].size
              plain_char = CDK.CharOf(@list[x][y])

              pos += 1
              if CDK.CharOf(pattern[pos-1]) != plain_char
                y -= (pos - 1)
                pos = 0
              elsif pos == pattern.size
                @current_top = x
                @left_char = if y < @box_width then 0 else @max_left_char end
                found = true
                break
              end
            end
          end
        end
      end
      return found
    end
    
    # This allows us to 'jump' to a given line in the file.
    def jumpToLine
      newline = CDK::SCALE.new(@screen, CDK::CENTER, CDK::CENTER,
          '<C>Jump To Line', '</5>Line :', Ncurses::A_BOLD,
          @list_size.size + 1, @current_top + 1, 0, @max_top_line + 1,
          1, 10, true, true)
      line = newline.activate([])
      newline.destroy
      return line - 1
    end

    # This pops a little message up on the screen.
    def popUpLabel(mesg)
      # Set up variables.
      label = CDK::LABEL.new(@screen, CDK::CENTER, CDK::CENTER,
          mesg, mesg.size, true, false)

      # Draw the label and wait.
      label.draw(true)
      label.getch([])

      # Clean up.
      label.destroy
    end

    # This moves the viewer field to the given location.
    def move(xplace, yplace, relative, refresh_flag)
      current_x = @win.getbegx
      current_y = @win.getbegy
      xpos = xplace
      ypos = yplace

      # If this is a relative move, then we will adjust where want to move to
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
      CDK.moveCursesWindow(@shadow_win, -xdiff, -ydiff)

      # Touch the windows so they 'move'.
      CDK::SCREEN.refreshCDKWindow(@screen.window)

      # Redraw the window, if they asked for it.
      if refresh_flag
        self.draw(@box)
      end
    end

    # This function draws the viewer widget.
    def draw(box)
      # Do we need to draw in the shadow?
      unless @shadow_win.nil?
        Draw.drawShadow(@shadow_win)
      end

      # Box it if it was asked for.
      if box
        Draw.drawObjBox(@win, self)
        @win.wrefresh
      end

      # Draw the info in the viewer.
      self.drawInfo
    end

    # This redraws the viewer buttons.
    def drawButtons
      # No buttons, no drawing
      if @button_count == 0
        return
      end

      # Redraw the buttons.
      (0...@button_count).each do |x|
        Draw.writeChtype(@win, @button_pos[x], @box_height - 2,
            @button[x], CDK::HORIZONTAL, 0, @button_len[x])
      end

      # Highlight the current button.
      (0...@button_len[@current_button]).each do |x|
        # Strip the character of any extra attributes.
        character = CDK.CharOf(@button[@current_button][x])

        # Add the character into the window.
        @win.mvwaddch(@box_height - 2, @button_pos[@current_button] + x,
            character.ord | @button_highlight)
      end

      # Refresh the window.
      @win.wrefresh
    end

    # This sets the background attribute of the widget.
    def setBKattr(attrib)
      @win.wbkgd(attrib)
    end

    def destroyInfo
      @list = []
      @list_pos = []
      @list_len = []
    end

    # This function destroys the viewer widget.
    def destroy
      self.destroyInfo

      self.cleanTitle

      # Clean up the windows.
      CDK.deleteCursesWindow(@shadow_win)
      CDK.deleteCursesWindow(@win)

      # Clean the key bindings.
      self.cleanBindings(:VIEWER)

      # Unregister this object.
      CDK::SCREEN.unregister(:VIEWER, self)
    end

    # This function erases the viewer widget from the screen.
    def erase
      if self.validCDKObject
        CDK.eraseCursesWindow(@win)
        CDK.eraseCursesWindow(@shadow_win)
      end
    end

    # This draws the viewer info lines.
    def drawInfo
      temp = ''
      line_adjust = false

      # Clear the window.
      @win.werase

      self.drawTitle(@win)

      # Draw in the current line at the top.
      if @show_line_info == true
        # Set up the info line and draw it.
        if @in_progress
          temp = 'processing...'
        elsif @list_size != 0
          temp = '%d/%d %2.0f%%' % [@current_top + 1, @list_size,
              ((1.0 * @current_top + 1) / (@list_size)) * 100]
        else
          temp = '%d/%d %2.0f%%' % [0, 0, 0.0]
        end

        # The list_adjust variable tells us if we have to shift down one line
        # because the person asked for the line X of Y line at the top of the
        # screen. We only want to set this to true if they asked for the info
        # line and there is no title or if the two items overlap.
        if @title_lines == '' || @title_pos[0] < temp.size + 2
          list_adjust = true
        end
        Draw.writeChar(@win, 1,
            if list_adjust then @title_lines else 0 end + 1,
            temp, CDK::HORIZONTAL, 0, temp.size)
      end

      # Determine the last line to draw.
      last_line = [@list_size, @view_size].min
      last_line -= if list_adjust then 1 else 0 end

      # Redraw the list.
      (0...last_line).each do |x|
        if @current_top + x < @list_size
          screen_pos = @list_pos[@current_top + x] + 1 - @left_char

          Draw.writeChtype(@win,
              if screen_pos >= 0 then screen_pos else 1 end,
              x + @title_lines + if list_adjust then 1 else 0 end + 1,
              @list[x + @current_top], CDK::HORIZONTAL,
              if screen_pos >= 0
              then 0
              else @left_char - @list_pos[@current_top + x]
              end,
              @list_len[x + @current_top])
        end
      end

      # Box it if we have to.
      if @box
        Draw.drawObjBox(@win, self)
        @win.wrefresh
      end

      # Draw the separation line.
      if @button_count > 0
        boxattr = @BXAttr

        (1..@box_width).each do |x|
          @win.mvwaddch(@box_height - 3, x, @HZChar | boxattr)
        end

        @win.mvwaddch(@box_height - 3, 0, Ncurses::ACS_LTEE | boxattr)
        @win.mvwaddch(@box_height - 3, @win.getmaxx - 1,
            Ncurses::ACS_RTEE | boxattr)
      end

      # Draw the buttons. This will call refresh on the viewer win.
      self.drawButtons
    end

    # The list_size may be negative, to assign no definite limit.
    def createList(list_size)
      status = false

      self.destroyInfo

      if list_size >= 0
        status = true

        @list = []
        @list_pos = []
        @list_len = []
      end
      return status
    end

    def position
      super(@win)
    end

    def object_type
      :VIEWER
    end
  end
end
