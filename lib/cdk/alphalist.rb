require_relative 'cdk_objs'

module CDK
  class ALPHALIST < CDK::CDKOBJS
    attr_reader :scroll_field, :entry_field, :list

    def initialize(cdkscreen, xplace, yplace, height, width, title, label,
        list, list_size, filler_char, highlight, box, shadow)
      super()
      parent_width = cdkscreen.window.getmaxx
      parent_height = cdkscreen.window.getmaxy
      box_width = width
      box_height = height
      label_len = 0
      bindings = {
        CDK::BACKCHAR => Ncurses::KEY_PPAGE,
        CDK::FORCHAR  => Ncurses::KEY_NPAGE,
      }

      if !self.createList(list, list_size)
        self.destroy
        return nil
      end

      self.setBox(box)

      # If the height is a negative value, the height will be ROWS-height,
      # otherwise the height will be the given height.
      box_height = CDK.setWidgetDimension(parent_height, height, 0)

      # If the width is a negative value, the width will be COLS-width,
      # otherwise the width will be the given width.
      box_width = CDK.setWidgetDimension(parent_width, width, 0)

      # Translate the label string to a chtype array
      if label.size > 0
        lentmp = []
        chtype_label = CDK.char2Chtype(label, lentmp, [])
        label_len = lentmp[0]
      end

      # Rejustify the x and y positions if we need to.
      xtmp = [xplace]
      ytmp = [yplace]
      CDK.alignxy(cdkscreen.window, xtmp, ytmp, box_width, box_height)
      xpos = xtmp[0]
      ypos = ytmp[0]

      # Make the file selector window.
      @win = Ncurses::WINDOW.new(box_height, box_width, ypos, xpos)

      if @win.nil?
        self.destroy
        return nil
      end
      @win.keypad(true)

      # Set some variables.
      @screen = cdkscreen
      @parent = cdkscreen.window
      @highlight = highlight
      @filler_char = filler_char
      @box_height = box_height
      @box_width = box_width
      @shadow = shadow
      @shadow_win = nil

      # Do we want a shadow?
      if shadow
        @shadow_win = Ncurses::WINDOW.new(box_height, box_width,
            ypos + 1, xpos + 1)
      end

      # Create the entry field.
      temp_width =  if CDK::ALPHALIST.isFullWidth(width)
                    then CDK::FULL
                    else box_width - 2 - label_len
                    end
      @entry_field = CDK::ENTRY.new(cdkscreen, @win.getbegx, @win.getbegy,
          title, label, Ncurses::A_NORMAL, filler_char, :MIXED, temp_width,
          0, 512, box, false)
      if @entry_field.nil?
        self.destroy
        return nil
      end
      @entry_field.setLLchar(Ncurses::ACS_LTEE)
      @entry_field.setLRchar(Ncurses::ACS_RTEE)

      # Callback functions
      adjust_alphalist_cb = lambda do |object_type, object, alphalist, key|
        scrollp = alphalist.scroll_field
        entry = alphalist.entry_field

        if scrollp.list_size > 0
          # Adjust the scrolling list.
          alphalist.injectMyScroller(key)

          # Set the value in the entry field.
          current = CDK.chtype2Char(scrollp.item[scrollp.current_item])
          entry.setValue(current)
          entry.draw(entry.box)
          return true
        end
        CDK.Beep
        return false
      end

      complete_word_cb = lambda do |object_type, object, alphalist, key|
        entry = alphalist.entry_field
        scrollp = nil
        selected = -1
        ret = 0
        alt_words = []

        if entry.info.size == 0
          CDK.Beep
          return true
        end
        
        # Look for a unique word match.
        index = CDK.searchList(alphalist.list, alphalist.list.size, entry.info)

        # if the index is less than zero, return we didn't find a match
        if index < 0
          CDK.Beep
          return true
        end

        # Did we find the last word in the list?
        if index == alphalist.list.size - 1
          entry.setValue(alphalist.list[index])
          entry.draw(entry.box)
          return true
        end


        # Ok, we found a match, is the next item similar?
        len = [entry.info.size, alphalist.list[index + 1].size].min
        ret = alphalist.list[index + 1][0...len] <=> entry.info
        if ret == 0
          current_index = index
          match = 0
          selected = -1

          # Start looking for alternate words
          # FIXME(original): bsearch would be more suitable.
          while current_index < alphalist.list.size &&
              (alphalist.list[current_index][0...len] <=> entry.info) == 0
            alt_words << alphalist.list[current_index]
            current_index += 1
          end

          # Determine the height of the scrolling list.
          height = if alt_words.size < 8 then alt_words.size + 3 else 11 end

          # Create a scrolling list of close matches.
          scrollp = CDK::SCROLL.new(entry.screen,
              CDK::CENTER, CDK::CENTER, CDK::RIGHT, height, -30,
              "<C></B/5>Possible Matches.", alt_words, alt_words.size,
              true, Ncurses::A_REVERSE, true, false)

          # Allow them to select a close match.
          match = scrollp.activate([])
          selected = scrollp.current_item

          # Check how they exited the list.
          if scrollp.exit_type == :ESCAPE_HIT
            # Destroy the scrolling list.
            scrollp.destroy

            # Beep at the user.
            CDK.Beep

            # Redraw the alphalist and return.
            alphalist.draw(alphalist.box)
            return true
          end

          # Destroy the scrolling list.
          scrollp.destroy

          # Set the entry field to the selected value.
          entry.set(alt_words[match], entry.min, entry.max, entry.box)

          # Move the highlight bar down to the selected value.
          (0...selected).each do |x|
            alphalist.injectMyScroller(Ncurses::KEY_DOWN)
          end

          # Redraw the alphalist.
          alphalist.draw(alphalist.box)
        else
          # Set the entry field with the found item.
          entry.set(alphalist.list[index], entry.min, entry.max, entry.box)
          entry.draw(entry.box)
        end
        return true
      end

      pre_process_entry_field = lambda do |cdktype, object, alphalist, input|
        scrollp = alphalist.scroll_field
        entry = alphalist.entry_field
        info_len = entry.info.size
        result = 1
        empty = false

        if alphalist.isBind(:ALPHALIST, input)
          result = 1  # Don't try to use this key in editing
        elsif (CDK.isChar(input) &&
            input.chr.match(/^[[:alnum:][:punct:]]$/)) ||
            [Ncurses::KEY_BACKSPACE, Ncurses::KEY_DC].include?(input)
          index = 0
          curr_pos = entry.screen_col + entry.left_char
          pattern = entry.info.clone
          if [Ncurses::KEY_BACKSPACE, Ncurses::KEY_DC].include?(input)
            if input == Ncurses::KEY_BACKSPACE
              curr_pos -= 1
            end
            if curr_pos >= 0
              pattern.slice!(curr_pos)
            end
          else
            front = (pattern[0...curr_pos] or '')
            back = (pattern[curr_pos..-1] or '')
            pattern = front + input.chr + back
          end

          if pattern.size == 0
            empty = true
          elsif (index = CDK.searchList(alphalist.list,
              alphalist.list.size, pattern)) >= 0
            # XXX: original uses n scroll downs/ups for <10 positions change
              scrollp.setPosition(index)
            alphalist.drawMyScroller
          else
            CDK.Beep
            result = 0
          end
        end

        if empty
          scrollp.setPosition(0)
          alphalist.drawMyScroller
        end

        return result
      end

      # Set the key bindings for the entry field.
      @entry_field.bind(:ENTRY, Ncurses::KEY_UP, adjust_alphalist_cb, self)
      @entry_field.bind(:ENTRY, Ncurses::KEY_DOWN, adjust_alphalist_cb, self)
      @entry_field.bind(:ENTRY, Ncurses::KEY_NPAGE, adjust_alphalist_cb, self)
      @entry_field.bind(:ENTRY, Ncurses::KEY_PPAGE, adjust_alphalist_cb, self)
      @entry_field.bind(:ENTRY, CDK::KEY_TAB, complete_word_cb, self)

      # Set up the post-process function for the entry field.
      @entry_field.setPreProcess(pre_process_entry_field, self)

      # Create the scrolling list.  It overlaps the entry field by one line if
      # we are using box-borders.
      temp_height = @entry_field.win.getmaxy - @border_size
      temp_width = if CDK::ALPHALIST.isFullWidth(width)
                   then CDK::FULL
                   else box_width - 1
                   end
      @scroll_field = CDK::SCROLL.new(cdkscreen, @win.getbegx,
          @entry_field.win.getbegy + temp_height, CDK::RIGHT,
          box_height - temp_height, temp_width, '', list, list_size,
          false, Ncurses::A_REVERSE, box, false)
      @scroll_field.setULchar(Ncurses::ACS_LTEE)
      @scroll_field.setURchar(Ncurses::ACS_RTEE)

      # Setup the key bindings.
      bindings.each do |from, to|
        self.bind(:ALPHALIST, from, :getc, to)
      end

      cdkscreen.register(:ALPHALIST, self)
    end

    # This erases the alphalist from the screen.
    def erase
      if self.validCDKObject
        @scroll_field.erase
        @entry_field.erase

        CDK.eraseCursesWindow(@shadow_win)
        CDK.eraseCursesWindow(@win)
      end
    end

    # This moves the alphalist field to the given location.
    def move(xplace, yplace, relative, refresh_flag)
      windows = [@win, @shadow_win]
      subwidgets = [@entry_field, @scroll_field]
      self.move_specific(xplace, yplace, relative, refresh_flag,
          windows, subwidgets)
    end

    # The alphalist's focus resides in the entry widget. But the scroll widget
    # will not draw items highlighted unless it has focus. Temporarily adjust
    # the focus of the scroll widget when drawing on it to get the right
    # highlighting.
    def saveFocus
      @save = @scroll_field.has_focus
      @scroll_field.has_focus = @entry_field.has_focus
    end

    def restoreFocus
      @scroll_field.has_focus = @save
    end

    def drawMyScroller
      self.saveFocus
      @scroll_field.draw(@scroll_field.box)
      self.restoreFocus
    end

    def injectMyScroller(key)
      self.saveFocus
      @scroll_field.inject(key)
      self.restoreFocus
    end

    # This draws the alphalist widget.
    def draw(box)
      # Does this widget have a shadow?
      unless @shadow_win.nil?
        Draw.drawShadow(@shadow_win)
      end

      # Draw in the entry field.
      @entry_field.draw(@entry_field.box)

      # Draw in the scroll field.
      self.drawMyScroller
    end

    # This activates the alphalist
    def activate(actions)
      ret = 0

      # Draw the widget.
      self.draw(@box)

      # Activate the widget.
      ret = @entry_field.activate(actions)

      # Copy the exit type from the entry field.
      @exit_type = @entry_field.exit_type

      # Determine the exit status.
      if @exit_type != :EARLY_EXIT
        return ret
      end
      return 0
    end

    # This injects a single character into the alphalist.
    def inject(input)
      ret = -1

      # Draw the widget.
      self.draw(@box)

      # Inject a character into the widget.
      ret = @entry_field.inject(input)

      # Copy the eixt type from the entry field.
      @exit_type = @entry_field.exit_type

      # Determine the exit status.
      if @exit_type == :EARLY_EXIT
        ret = -1
      end

      @result_data = ret
      return ret
    end

    # This sets multiple attributes of the widget.
    def set(list, list_size, filler_char, highlight, box)
      self.setContents(list, list_size)
      self.setFillerChar(filler_char)
      self.setHighlight(highlight)
      self.setBox(box)
    end

    # This function sets the information inside the alphalist.
    def setContents(list, list_size)
      if !self.createList(list, list_size)
        return
      end

      # Set the information in the scrolling list.
      @scroll_field.set(@list, @list_size, false,
          @scroll_field.highlight, @scroll_field.box)

      # Clean out the entry field.
      self.setCurrentItem(0)
      @entry_field.clean

      # Redraw the widget.
      self.erase
      self.draw(@box)
    end

    # This returns the contents of the widget.
    def getContents(size)
      size << @list_size
      return @list
    end

    # Get/set the current position in the scroll widget.
    def getCurrentItem
      return @scroll_field.getCurrentItem
    end

    def setCurrentItem(item)
      if @list_size != 0
        @scroll_field.setCurrentItem(item)
        @entry_field.setValue(@list[@scroll_field.getCurrentItem])
      end
    end

    # This sets the filler character of the entry field of the alphalist.
    def setFillerChar(filler_character)
      @filler_char = filler_character
      @entry_field.setFillerChar(filler_character)
    end

    def getFillerChar
      return @filler_char
    end

    # This sets the highlgith bar attributes
    def setHighlight(highlight)
      @highlight = highlight
    end

    def getHighlight
      @highlight
    end

    # These functions set the drawing characters of the widget.
    def setMyULchar(character)
      @entry_field.setULchar(character)
    end

    def setMyURchar(character)
      @entry_field.setURchar(character)
    end

    def setMyLLchar(character)
      @scroll_field.setLLchar(character)
    end

    def setMyLRchar(character)
      @scroll_field.setLRchar(character)
    end

    def setMyVTchar(character)
      @entry_field.setVTchar(character)
      @scroll_field.setVTchar(character)
    end

    def setMyHZchar(character)
      @entry_field.setHZchar(character)
      @scroll_field.setHZchar(character)
    end

    def setMyBXattr(character)
      @entry_field.setBXattr(character)
      @scroll_field.setBXattr(character)
    end

    # This sets the background attribute of the widget.
    def setBKattr(attrib)
      @entry_field.setBKattr(attrib)
      @scroll_field.setBKattr(attrib)
    end

    def destroyInfo
      @list = ''
      @list_size = 0
    end

    # This destroys the alpha list
    def destroy
      self.destroyInfo

      # Clean the key bindings.
      self.cleanBindings(:ALPHALIST)

      @entry_field.destroy
      @scroll_field.destroy

      # Free up the window pointers.
      CDK.deleteCursesWindow(@shadow_win)
      CDK.deleteCursesWindow(@win)

      # Unregister the object.
      CDK::SCREEN.unregister(:ALPHALIST, self)
    end

    # This function sets the pre-process function.
    def setPreProcess(callback, data)
      @entry_field.setPreProcess(callback, data)
    end

    # This function sets the post-process function.
    def setPostProcess(callback, data)
      @entry_field.setPostProcess(callback, data)
    end

    def createList(list, list_size)
      if list_size >= 0
        newlist = []

        # Copy in the new information.
        status = true
        (0...list_size).each do |x|
          newlist << list[x]
          if newlist[x] == 0
            status = false
            break
          end
        end
        if status
          self.destroyInfo
          @list_size = list_size
          @list = newlist
          @list.sort!
        end
      else
        self.destroyInfo
        status = true
      end
      return status
    end

    def focus
      self.entry_field.focus
    end

    def unfocus
      self.entry_field.unfocus
    end

    def self.isFullWidth(width)
      width == CDK::FULL || (Ncurses.COLS != 0 && width >= Ncurses.COLS)
    end

    def position
      super(@win)
    end

    def object_type
      :ALPHALIST
    end
  end
end
