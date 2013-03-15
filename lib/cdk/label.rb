require_relative 'cdk_objs'

module CDK
  class LABEL < CDK::CDKOBJS
    attr_accessor :win

    def initialize(cdkscreen, xplace, yplace, mesg, rows, box, shadow)
      super()
      parent_width = cdkscreen::window.getmaxx
      parent_height = cdkscreen::window.getmaxy
      box_width = -2**30  # -INFINITY
      box_height = 0
      xpos = [xplace]
      ypos = [yplace]
      x = 0

      if rows <= 0
        return nil
      end

      self.setBox(box)
      box_height = rows + 2 * @border_size

      @info = []
      @info_len = []
      @info_pos = []

      # Determine the box width.
      (0...rows).each do |x|
        #Translate the string to a chtype array
        info_len = []
        info_pos = []
        @info << CDK.char2Chtype(mesg[x], info_len, info_pos)
        @info_len << info_len[0]
        @info_pos << info_pos[0]
        box_width = [box_width, @info_len[x]].max
      end
      box_width += 2 * @border_size

      # Create the string alignments.
      (0...rows).each do |x|
        @info_pos[x] = CDK.justifyString(box_width - 2 * @border_size,
            @info_len[x], @info_pos[x])
      end

      # Make sure we didn't extend beyond the dimensions of the window.
      box_width = if box_width > parent_width
                  then parent_width
                  else box_width
                  end
      box_height = if box_height > parent_height
                   then parent_height
                   else box_height
                   end

      # Rejustify the x and y positions if we need to
      CDK.alignxy(cdkscreen.window, xpos, ypos, box_width, box_height)
      @screen = cdkscreen
      @parent = cdkscreen.window
      @win = Ncurses::WINDOW.new(box_height, box_width, ypos[0], xpos[0])
      @shadow_win = nil
      @xpos = xpos[0]
      @ypos = ypos[0]
      @rows = rows
      @box_width = box_width
      @box_height = box_height
      @input_window = @win
      @has_focus = false
      @shadow = shadow

      if @win.nil?
        self.destroy
        return nil
      end

      @win.keypad(true)

      # If a shadow was requested, then create the shadow window.
      if shadow
        @shadow_win = Ncurses::WINDOW.new(box_height, box_width,
            ypos[0] + 1, xpos[0] + 1)
      end

      # Register this
      cdkscreen.register(:LABEL, self)
    end

    # This was added for the builder.
    def activate(actions)
      self.draw(@box)
    end

    # This sets multiple attributes of the widget
    def set(mesg, lines, box)
      self.setMessage(mesg, lines)
      self.setBox(box)
    end

    # This sets the information within the label.
    def setMessage(info, info_size)
      # Clean out the old message.`
      (0...@rows).each do |x|
        @info[x] = ''
        @info_pos[x] = 0
        @info_len[x] = 0
      end

      @rows = if info_size < @rows
              then info_size
              else @rows
              end

      # Copy in the new message.
      (0...@rows).each do |x|
        info_len = []
        info_pos = []
        @info[x] = CDK.char2Chtype(info[x], info_len, info_pos)
        @info_len[x] = info_len[0]
        @info_pos[x] = CDK.justifyString(@box_width - 2 * @border_size,
            @info_len[x], info_pos[0])
      end

      # Redraw the label widget.
      self.erase
      self.draw(@box)
    end

    def getMessage(size)
      size << @rows
      return @info
    end

    def object_type
      :LABEL
    end

    def position
      super(@win)
    end

    # This sets the background attribute of the widget.
    def setBKattr(attrib)
      @win.wbkgd(attrib)
    end

    # This draws the label widget.
    def draw(box)
      # Is there a shadow?
      unless @shadow_win.nil?
        Draw.drawShadow(@shadow_win)
      end

      # Box the widget if asked.
      if @box
        Draw.drawObjBox(@win, self)
      end

      # Draw in the message.
      (0...@rows).each do |x|
        Draw.writeChtype(@win,
            @info_pos[x] + @border_size, x + @border_size,
            @info[x], CDK::HORIZONTAL, 0, @info_len[x])
      end

      # Refresh the window
      @win.wrefresh
    end

    # This erases the label widget
    def erase
      CDK.eraseCursesWindow(@win)
      CDK.eraseCursesWindow(@shadow_win)
    end

    # This moves the label field to the given location
    def move(xplace, yplace, relative, refresh_flag)
      current_x = @win.getbegx
      current_y = @win.getbegy
      xpos = [xplace]
      ypos = [yplace]
      xdiff = 0
      ydiff = 0

      # If this is a relative move, then we will adjust where we want
      # to move to.
      if relative
        xpos = [@win.getbegx + xplace]
        ypos = [@win.getbegy + yplace]
      end

      # Adjust the window if we need to
      CDK.alignxy(@screen.window, xpos, ypos, @box_width, @box_height)

      # Get the diference.
      xdiff = current_x - xpos[0]
      ydiff = current_y = ypos[0]

      # Move the window to the new location.
      CDK.moveCursesWindow(@win, -xdiff, -ydiff)
      CDK.moveCursesWindow(@shadow_win, -xdiff, -ydiff)

      # Touch the windows so the 'move'
      CDK::SCREEN.refreshCDKWindow(@screen.window)

      # Redraw the window, if they asked for it.
      if refresh_flag
        self.draw(@box)
      end
    end

    # This destroys the label object pointer.
    def destroy
      CDK.deleteCursesWindow(@shadow_win)
      CDK.deleteCursesWindow(@win)

      self.cleanBindings(:LABEL)

      CDK::SCREEN.unregister(:LABEL, self)
    end

    # This pauses until a user hits a key...
    def wait(key)
      function_key = []
      if key.ord == 0
        code = self.getch(function_key)
      else
        # Only exit when a specific key is hit
        while true
          code = self.getch(function_key)
          if code == key.ord
            break
          end
        end
      end
      return code
    end
  end
end
