require_relative 'cdk_objs'

module CDK
  class HISTOGRAM < CDK::CDKOBJS
    def initialize(cdkscreen, xplace, yplace, height, width, orient,
        title, box, shadow)
      super()
      parent_width = cdkscreen.window.getmaxx
      parent_height = cdkscreen.window.getmaxy

      self.setBox(box)

      box_height = CDK.setWidgetDimension(parent_height, height, 2)
      old_height = box_height

      box_width = CDK.setWidgetDimension(parent_width, width, 0)
      old_width = box_width

      box_width = self.setTitle(title, -(box_width + 1))

      # Increment the height by number of lines in in the title
      box_height += @title_lines

      # Make sure we didn't extend beyond the dimensions of the window.
      box_width = if box_width > parent_width
                  then old_width
                  else box_width
                  end
      box_height = if box_height > parent_height
                  then old_height
                  else box_height
                  end

      # Rejustify the x and y positions if we need to.
      xtmp = [xplace]
      ytmp = [yplace]
      CDK.alignxy(cdkscreen.window, xtmp, ytmp, box_width, box_height)
      xpos = xtmp[0]
      ypos = ytmp[0]

      # Set up the histogram data
      @screen = cdkscreen
      @parent = cdkscreen.window
      @win = Ncurses::WINDOW.new(box_height, box_width, ypos, xpos)
      @shadow_win = nil
      @box_width = box_width
      @box_height = box_height
      @field_width = box_width - 2 * @border_size
      @field_height = box_height - @title_lines - 2 * @border_size
      @orient = orient
      @shadow = shadow

      # Is the window nil
      if @win.nil?
        self.destroy
        return nil
      end

      @win.keypad(true)

      # Set up some default values.
      @filler = '#'.ord | Ncurses::A_REVERSE
      @stats_attr = Ncurses::A_NORMAL
      @stats_pos = CDK::TOP
      @view_type = :REAL
      @high = 0
      @low = 0
      @value = 0
      @lowx = 0
      @lowy = 0
      @highx = 0
      @highy = 0
      @curx = 0
      @cury = 0
      @low_string = ''
      @high_string = ''
      @cur_string = ''

      # Do we want a shadow?
      if shadow
        @shadow_win = Ncurses::WINDOW.new(box_height, box_width,
            ypos + 1, xpos + 1)
      end

      cdkscreen.register(:HISTOGRAM, self)
    end

    # This was added for the builder
    def activate(actions)
      self.draw(@box)
    end

    # Set various widget attributes
    def set(view_type, stats_pos, stats_attr, low, high, value, filler, box)
      self.setDisplayType(view_type)
      self.setStatsPos(stats_pos)
      self.setValue(low, high, value)
      self.setFillerChar(filler)
      self.setStatsAttr(stats_attr)
      self.setBox(box)
    end

    # Set the values for the widget.
    def setValue(low, high, value)
      # We should error check the information we have.
      @low = if low <= high then low else 0 end
      @high = if low <= high then high else 0 end
      @value = if low <= value && value <= high then value else 0 end
      # Determine the percentage of the given value.
      @percent = if @high == 0 then 0 else 1.0 * @value / @high end

      # Determine the size of the histogram bar.
      if @orient == CDK::VERTICAL
        @bar_size = @percent * @field_height
      else
        @bar_size = @percent * @field_width
      end

      # We have a number of variables which determine the personality of the
      # histogram.  We have to go through each one methodically, and set them
      # correctly.  This section does this.
      if @view_type != :NONE
        if @orient == CDK::VERTICAL
          if @stats_pos == CDK::LEFT || @stats_pos == CDK::BOTTOM
            # Set the low label attributes.
            @low_string = @low.to_s
            @lowx = 1
            @lowy = @box_height - @low_string.size - 1

            # Set the high label attributes
            @high_string = @high.to_s
            @highx = 1
            @highy = @title_lines + 1

            string = ''
            # Set the current value attributes.
            string = if @view_type == :PERCENT
                     then "%3.1f%%" % [1.0 * @percent * 100]
                     elsif @view_type == :FRACTION
                         string = "%d/%d" % [@value, @high]
                     else string = @value.to_s
                     end
            @cur_string = string
            @curx = 1
            @cury = (@field_height - string.size) / 2 + @title_lines + 1
          elsif @stats_pos == CDK::CENTER
            # Set the lower label attributes
            @low_string = @low.to_s
            @lowx = @field_width / 2 + 1
            @lowy = @box_height - @low_string.size - 1

            # Set the high label attributes
            @high_string = @high.to_s
            @highx = @field_width / 2 + 1
            @highy = @title_lines + 1

            # Set the stats label attributes
            string = if @view_type == :PERCENT
                     then "%3.2f%%" % [1.0 * @percent * 100]
                     elsif @view_type == :FRACTIOn
                         "%d/%d" % [@value, @high]
                     else @value.to_s
                     end

            @cur_string = string
            @curx = @field_width / 2 + 1
            @cury = (@field_height - string.size) / 2 + @title_lines + 1
          elsif @stats_pos == CDK::RIGHT || @stats_pos == CDK::TOP
            # Set the low label attributes.
            @low_string = @low.to_s
            @lowx = @field_width
            @lowy = @box_height - @low_string.size - 1

            # Set the high label attributes.
            @high_string = @high.to_s
            @highx = @field_width
            @highy = @title_lines + 1

            # Set the stats label attributes.
            string = if @view_type == :PERCENT
                     then "%3.2f%%" % [1.0 * @percent * 100]
                     elsif @view_type == :FRACTION
                         "%d/%d" % [@value, @high]
                     else @value.to_s
                     end
            @cur_string = string
            @curx = @field_width
            @cury = (@field_height - string.size) / 2 + @title_lines + 1
          end
        else
          # Alignment is HORIZONTAL
          if @stats_pos == CDK::TOP || @stats_pos == CDK::RIGHT
            # Set the low label attributes.
            @low_string = @low.to_s
            @lowx = 1
            @lowy = @title_lines + 1

            # Set the high label attributes.
            @high_string = @high.to_s
            @highx = @box_width - @high_string.size - 1
            @highy = @title_lines + 1

            # Set the stats label attributes.
            string = if @view_type == :PERCENT
                     then "%3.1f%%" % [1.0 * @percent * 100]
                     elsif @view_type == :FRACTION
                         "%d/%d" % [@value, @high]
                     else @value.to_s
                     end
            @cur_string = string
            @curx = (@field_width - @cur_string.size) / 2 + 1
            @cury = @title_lines + 1
          elsif @stats_pos == CDK::CENTER
            # Set the low label attributes.
            @low_string = @low.to_s
            @lowx = 1
            @lowy = (@field_height / 2) + @title_lines + 1

            # Set the high label attributes.
            @high_string = @high.to_s
            @highx = @box_width - @high_string.size - 1
            @highy = @field_height / 2 + @title_lines + 1

            # Set the stats label attributes.
            string = if @view_type == :PERCENT
                     then "%3.1f%%" % [1.0 * @percent * 100]
                     elsif @view_type == :FRACTION
                         "%d/%d" % [@value, @high]
                     else @value.to_s
                     end
            @cur_string = string
            @curx = (@field_width - @cur_string.size) / 2 + 1
            @cury = @field_height / 2 + @title_lines + 1
          elsif @stats_pos == CDK::BOTTOM || @stats_pos == CDK::LEFT
            # Set the low label attributes.
            @low_string = @low.to_s
            @lowx = 1
            @lowy = @box_height -2 * @border_size

            # Set the high label attributes.
            @high_string = @high.to_s
            @highx = @box_width - @high_string.size - 1
            @highy = @box_height - 2 * @border_size

            # Set the stats label attributes.
            string = if @view_type == :PERCENT
                     then "%3.1f%%" % [1.0 * @percent * 100]
                     elsif @view_type == :FRACTION
                         "%d/%d" % [@value, @high]
                     else @value.to_s
                     end
            @cur_string = string
            @curx = (@field_width - @cur_string.size) / 2 + 1
            @cury = @box_height - 2 * @border_size
          end
        end
      end
    end

    def getValue
      return @value
    end

    def getLowValue
      return @low
    end

    def getHighValue
      return @high
    end

    # Set the histogram display type
    def setDisplayType(view_type)
      @view_type = view_type
    end

    def getViewType
      return @view_type
    end

    # Set the position of the statistics information.
    def setStatsPos(stats_pos)
      @stats_pos = stats_pos
    end

    def getStatsPos
      return @stats_pos
    end

    # Set the attribute of the statistics.
    def setStatsAttr(stats_attr)
      @stats_attr = stats_attr
    end

    def getStatsAttr
      return @stats_attr
    end

    # Set the character to use when drawing the widget.
    def setFillerChar(character)
      @filler = character
    end

    def getFillerChar
      return @filler
    end

    # Set the background attribute of the widget.
    def setBKattr(attrib)
      @win.wbkgd(attrib)
    end

    # Move the histogram field to the given location.
    # Inherited
    # def move(xplace, yplace, relative, refresh_flag)
    # end

    # Draw the widget.
    def draw(box)
      battr = 0
      bchar = 0
      fattr = @filler & Ncurses::A_ATTRIBUTES
      hist_x = @title_lines + 1
      hist_y = @bar_size

      @win.werase

      # Box the widget if asked.
      if box
        Draw.drawObjBox(@win, self)
      end

      # Do we have a shadow to draw?
      if !(@shadow.nil?)
        Draw.drawShadow(@shadow_win)
      end

      self.drawTitle(@win)

      # If the user asked for labels, draw them in.
      if @view_type != :NONE
        # Draw in the low label.
        if @low_string.size > 0
          Draw.writeCharAttrib(@win, @lowx, @lowy, @low_string,
              @stats_attr, @orient, 0, @low_string.size)
        end

        # Draw in the current value label.
        if @cur_string.size > 0
          Draw.writeCharAttrib(@win, @curx, @cury, @cur_string,
              @stats_attr, @orient, 0, @cur_string.size)
        end

        # Draw in the high label.
        if @high_string.size > 0
          Draw.writeCharAttrib(@win, @highx, @highy, @high_string,
              @stats_attr, @orient, 0, @high_string.size)
        end
      end

      if @orient == CDK::VERTICAL
        hist_x = @box_height - @bar_size - 1
        hist_y = @field_width
      end

      # Draw the histogram bar.
      (hist_x...@box_height - 1).to_a.each do |x|
        (1..hist_y).each do |y|
          battr = @win.mvwinch(x, y)
          
          if battr == ' '.ord
            @win.mvwaddch(x, y, @filler)
          else
            @win.mvwaddch(x, y, battr | fattr)
          end
        end
      end

      # Refresh the window
      @win.wrefresh
    end

    # Destroy the widget.
    def destroy
      self.cleanTitle

      # Clean up the windows.
      CDK.deleteCursesWindow(@shadow_win)
      CDK.deleteCursesWindow(@win)

      # Clean the key bindings.
      self.cleanBindings(:HISTOGRAM)

      # Unregister this object.
      CDK::SCREEN.unregister(:HISTOGRAM, self)
    end

    # Erase the widget from the screen.
    def erase
      if self.validCDKObject
        CDK.eraseCursesWindow(@win)
        CDK.eraseCursesWindow(@shadow_win)
      end
    end

    def object_type
      :HISTOGRAM
    end
  end
end
