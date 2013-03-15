require_relative 'cdk_objs'

module CDK
  class MARQUEE < CDK::CDKOBJS
    def initialize(cdkscreen, xpos, ypos, width, box, shadow)
      super()

      @screen = cdkscreen
      @parent = cdkscreen.window
      @win = Ncurses::WINDOW.new(1, 1, ypos, xpos)
      @active = true
      @width = width
      @shadow = shadow

      self.setBox(box)
      if @win.nil?
        self.destroy
        # return (0);
      end

      cdkscreen.register(:MARQUEE, self)
    end

    # This activates the widget.
    def activate(mesg, delay, repeat, box)
      mesg_length = []
      start_pos = 0
      first_char = 0
      last_char = 1
      repeat_count = 0
      view_size = 0
      message = []
      first_time = true

      if mesg.nil? or mesg == ''
        return -1
      end

      # Keep the box info, setting BorderOf()
      self.setBox(box)
      
      padding = if mesg[-1] == ' ' then 0 else 1 end

      # Translate the string to a chtype array
      message = CDK.char2Chtype(mesg, mesg_length, [])

      # Draw in the widget.
      self.draw(@box)
      view_limit = @width - (2 * @border_size)

      # Start doing the marquee thing...
      oldcurs = Ncurses.curs_set(0)
      while @active
        if first_time
          first_char = 0
          last_char = 1
          view_size = last_char - first_char
          start_pos = @width - view_size - @border_size

          first_time = false
        end

        # Draw in the characters.
        y = first_char
        (start_pos...(start_pos + view_size)).each do |x|
          ch = if y < mesg_length[0] then message[y].ord else ' '.ord end
          @win.mvwaddch(@border_size, x, ch)
          y += 1
        end
        @win.wrefresh

        # Set my variables
        if mesg_length[0] < view_limit
          if last_char < (mesg_length[0] + padding)
            last_char += 1
            view_size += 1
            start_pos = @width - view_size - @border_size
          elsif start_pos > @border_size
            # This means the whole string is visible.
            start_pos -= 1
            view_size = mesg_length[0] + padding
          else
            # We have to start chopping the view_size
            start_pos = @border_size
            first_char += 1
            view_size -= 1
          end
        else
          if start_pos > @border_size
            last_char += 1
            view_size += 1
            start_pos -= 1
          elsif last_char < mesg_length[0] + padding
            first_char += 1
            last_char += 1
            start_pos = @border_size
            view_size = view_limit
          else
            start_pos = @border_size
            first_char += 1
            view_size -= 1
          end
        end

        # OK, let's check if we have to start over.
        if view_size <= 0 && first_char == (mesg_length[0] + padding)
          # Check if we repeat a specified number or loop indefinitely
          repeat_count += 1
          if repeat > 0 && repeat_count >= repeat
            break
          end

          # Time to start over.
          @win.mvwaddch(@border_size, @border_size, ' '.ord)
          @win.wrefresh
          first_time = true
        end

        # Now sleep
        Ncurses.napms(delay * 10)
      end
      if oldcurs < 0
        oldcurs = 1
      end
      Ncurses.curs_set(oldcurs)
      return 0
    end

    # This de-activates a marquee widget.
    def deactivate
      @active = false
    end

    # This moves the marquee field to the given location.
    def move(xplace, yplace, relative, refresh_flag)
      current_x = @win.getbegx
      current_y = @win.getbegy
      xpos = xplace
      ypos = yplace
      xdiff = 0
      ydiff = 0

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

      # Move the window to the new location
      CDK.moveCursesWindow(@win, -xdiff, -ydiff)
      CDK.moveCursesWindow(@shadow_win, -xdiff, -ydiff)

      # Touch the windows so they 'move'.
      CDK::SCREEN.refreshCDKWindow(@screen.window)

      # Redraw the window, if they asked for it
      if refresh_flag
        self.draw(@box)
      end
    end

    # This draws the marquee widget on the screen.
    def draw(box)
      # Keep the box information.
      @box = box

      # Do we need to draw a shadow???
      unless @shadow_win.nil?
        Draw.drawShadow(@shadow_win)
      end

      # Box it if needed.
      if box
        Draw.drawObjBox(@win, self)
      end

      # Refresh the window.
      @win.wrefresh
    end

    # This destroys the widget.
    def destroy
      # Clean up the windows.
      CDK.deleteCursesWindow(@shadow_win)
      CDK.deleteCursesWindow(@win)

      # Clean the key bindings.
      self.cleanBindings(:MARQUEE)

      # Unregister this object.
      CDK::SCREEN.unregister(:MARQUEE, self)
    end

    # This erases the widget.
    def erase
      if self.validCDKObject
        CDK.eraseCursesWindow(@win)
        CDK.eraseCursesWindow(@shadow_win)
      end
    end

    # This sets the widgets box attribute.
    def setBox(box)
      xpos = if @win.nil? then 0 else @win.getbegx end
      ypos = if @win.nil? then 0 else @win.getbegy end

      super

      self.layoutWidget(xpos, ypos)
    end

    def object_type
      :MARQUEE
    end

    def position
      super(@win)
    end

    # This sets the background attribute of the widget.
    def setBKattr(attrib)
      Ncurses.wbkgd(@win, attrib)
    end

    def layoutWidget(xpos, ypos)
      cdkscreen = @screen
      parent_width = @screen.window.getmaxx

      CDK::MARQUEE.discardWin(@win)
      CDK::MARQUEE.discardWin(@shadow_win)

      box_width = CDK.setWidgetDimension(parent_width, @width, 0)
      box_height = (@border_size * 2) + 1

      # Rejustify the x and y positions if we need to.
      xtmp = [xpos]
      ytmp = [ypos]
      CDK.alignxy(@screen.window, xtmp, ytmp, box_width, box_height)
      window = Ncurses::WINDOW.new(box_height, box_width, ytmp[0], xtmp[0])

      unless window.nil?
        @win = window
        @box_height = box_height
        @box_width = box_width

        @win.keypad(true)

        # Do we want a shadow?
        if @shadow
          @shadow_win = @screen.window.subwin(box_height, box_width,
              ytmp[0] + 1, xtmp[0] + 1)
        end
      end
    end

    def self.discardWin(winp)
      unless winp.nil?
        winp.werase
        winp.wrefresh
        winp.delwin
      end
    end
  end
end
