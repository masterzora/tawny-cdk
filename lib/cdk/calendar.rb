require_relative 'cdk_objs'

module CDK
  class CALENDAR < CDK::CDKOBJS
    attr_accessor :week_base
    attr_reader :day, :month, :year

    MONTHS_OF_THE_YEAR = [
        'NULL',
        'January',
        'February',
        'March',
        'April',
        'May',
        'June',
        'July',
        'August',
        'September',
        'October',
        'November',
        'December',
    ]

    DAYS_OF_THE_MONTH = [
        -1,
        31,
        28,
        31,
        30,
        31,
        30,
        31,
        31,
        30,
        31,
        30,
        31,
    ]

    MAX_DAYS = 32
    MAX_MONTHS = 13
    MAX_YEARS = 140

    CALENDAR_LIMIT = MAX_DAYS * MAX_MONTHS * MAX_YEARS

    def self.CALENDAR_INDEX(d, m, y)
      (y * CDK::CALENDAR::MAX_MONTHS + m) * CDK::CALENDAR::MAX_DAYS + d
    end

    def setCalendarCell(d, m, y, value)
      @marker[CDK::CALENDAR.CALENDAR_INDEX(d, m, y)] = value
    end

    def getCalendarCell(d, m, y)
      @marker[CDK::CALENDAR.CALENDAR_INDEX(d, m, y)]
    end

    def initialize(cdkscreen, xplace, yplace, title, day, month, year,
        day_attrib, month_attrib, year_attrib, highlight, box, shadow)
      super()
      parent_width = cdkscreen.window.getmaxx
      parent_height = cdkscreen.window.getmaxy
      box_width = 24
      box_height = 11
      dayname = 'Su Mo Tu We Th Fr Sa '
      bindings = {
          'T'           => Ncurses::KEY_HOME,
          't'           => Ncurses::KEY_HOME,
          'n'           => Ncurses::KEY_NPAGE,
          CDK::FORCHAR  => Ncurses::KEY_NPAGE,
          'p'           => Ncurses::KEY_PPAGE,
          CDK::BACKCHAR => Ncurses::KEY_PPAGE,
      }

      self.setBox(box)

      box_width = self.setTitle(title, box_width)
      box_height += @title_lines

      # Make sure we didn't extend beyond the dimensions of the window.
      box_width = [box_width, parent_width].min
      box_height = [box_height, parent_height].min

      # Rejustify the x and y positions if we need to.
      xtmp = [xplace]
      ytmp = [yplace]
      CDK.alignxy(cdkscreen.window, xtmp, ytmp, box_width, box_height)
      xpos = xtmp[0]
      ypos = ytmp[0]

      # Create the calendar window.
      @win = Ncurses::WINDOW.new(box_height, box_width, ypos, xpos)

      # Is the window nil?
      if @win.nil?
        self.destroy
        return nil
      end
      @win.keypad(true)

      # Set some variables.
      @x_offset = (box_width - 20) / 2
      @field_width = box_width - 2 * (1 + @border_size)

      # Set months and day names
      @month_name = CDK::CALENDAR::MONTHS_OF_THE_YEAR.clone
      @day_name = dayname

      # Set the rest of the widget values.
      @screen = cdkscreen
      @parent = cdkscreen.window
      @shadow_win = nil
      @xpos = xpos
      @ypos = ypos
      @box_width = box_width
      @box_height = box_height
      @day = day
      @month = month
      @year = year
      @day_attrib = day_attrib
      @month_attrib = month_attrib
      @year_attrib = year_attrib
      @highlight = highlight
      @width = box_width
      @accepts_focus = true
      @input_window = @win
      @week_base = 0
      @shadow = shadow
      @label_win = @win.subwin(1, @field_width,
          ypos + @title_lines + 1, xpos + 1 + @border_size)
      if @label_win.nil?
        self.destroy
        return nil
      end

      @field_win = @win.subwin(7, 20,
          ypos + @title_lines + 3, xpos + @x_offset)
      if @field_win.nil?
        self.destroy
        return nil
      end
      self.setBox(box)

      @marker = [0] * CDK::CALENDAR::CALENDAR_LIMIT

      # If the day/month/year values were 0, then use today's date.
      if @day == 0 && @month == 0 && @year == 0
        date_info = Time.new.gmtime
        @day = date_info.day
        @month = date_info.month
        @year = date_info
      end

      # Verify the dates provided.
      self.verifyCalendarDate

      # Determine which day the month starts on.
      @week_day = CDK::CALENDAR.getMonthStartWeekday(@year, @month)

      # If a shadow was requested, then create the shadow window.
      if shadow
        @shadow_win = Ncurses::WINDOW.new(box_height, box_width,
            ypos + 1, xpos + 1)
      end

      # Setup the key bindings.
      bindings.each do |from, to|
        self.bind(:CALENDAR, from, :getc, to)
      end

      cdkscreen.register(:CALENDAR, self)
    end

    # This function lets the user play with this widget.
    def activate(actions)
      ret = -1
      self.draw(@box)

      if actions.nil? || actions.size == 0
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
      return ret
    end

    # This injects a single character into the widget.
    def inject(input)
      # Declare local variables
      pp_return = 1
      ret = -1
      complete = false

      # Set the exit type
      self.setExitType(0)

      # Refresh the widget field.
      self.drawField

      # Check if there is a pre-process function to be called.
      unless @pre_process_func.nil?
        pp_return = @pre_process_func.call(:CALENDAR, self,
            @pre_process_data, input)
      end

      # Should we continue?
      if pp_return != 0
        # Check a predefined binding
        if self.checkBind(:CALENDAR, input)
          self.checkEarlyExit
          complete = true
        else
          case input
          when Ncurses::KEY_UP
            self.decrementCalendarDay(7)
          when Ncurses::KEY_DOWN
            self.incrementCalendarDay(7)
          when Ncurses::KEY_LEFT
            self.decrementCalendarDay(1)
          when Ncurses::KEY_RIGHT
            self.incrementCalendarDay(1)
          when Ncurses::KEY_NPAGE
            self.incrementCalendarMonth(1)
          when Ncurses::KEY_PPAGE
            self.decrementCalendarMonth(1)
          when 'N'.ord
            self.incrementCalendarMonth(6)
          when 'P'.ord
            self.decrementCalendarMonth(6)
          when '-'.ord
            self.decrementCalendarYear(1)
          when '+'.ord
            self.incrementCalendarYear(1)
          when Ncurses::KEY_HOME
            self.setDate(-1, -1, -1)
          when CDK::KEY_ESC
            self.setExitType(input)
            complete = true
          when Ncurses::ERR
            self.setExitType(input)
            complete = true
          when CDK::KEY_TAB, CDK::KEY_RETURN, Ncurses::KEY_ENTER
            self.setExitType(input)
            ret = self.getCurrentTime
            complete = true
          when CDK::REFRESH
            @screen.erase
            @screen.refresh
          end
        end

        # Should we do a post-process?
        if !complete && !(@post_process_func.nil?)
          @post_process_func.call(:CALENDAR, self, @post_process_data, input)
        end
      end

      if !complete
        self.setExitType(0)
      end

      @result_data = ret
      return ret
    end

    # This moves the calendar field to the given location.
    def move(xplace, yplace, relative, refresh_flag)
      current_x = @win.getbegx
      current_y = @win.getbegy
      xpos = xplace
      ypos = yplace

      # If this is a relative move, then we will adjust where we want
      # to move to.
      if relative
        xpos = @win.getbegx + xplace
        ypos = @win.getbegx + yplace
      end

      # Adjust the window if we need to.
      xtmp = [xpos]
      ytmp = [ypos]
      CDK.alignxy(@screen.window, xtmp, ytmp, @box_width, @box_height)
      xpos = xtmp[0]
      ypos = ytmp[0]

      # Get the difference
      xdiff = current_x - xpos
      ydiff = current_y - ypos

      # Move the window to the new location.
      CDK.moveCursesWindow(@win, -xdiff, -ydiff)
      CDK.moveCursesWindow(@field_win, -xdiff, -ydiff)
      CDK.moveCursesWindow(@label_win, -xdiff, -ydiff)
      CDK.moveCursesWindow(@shadow_win, -xdiff, -ydiff)

      # Touch the windows so they 'move'.
      CDK.refreshCDKWindow(@screen.window)

      # Redraw the window, if they asked for it.
      if refresh_flag
        self.draw(@box)
      end
    end

    # This draws the calendar widget.
    def draw(box)
      header_len = @day_name.size
      col_len = (6 + header_len) / 7

      # Is there a shadow?
      unless @shadow_win.nil?
        Draw.drawShadow(@shadow_win)
      end

      # Box the widget if asked.
      if box
        Draw.drawObjBox(@win, self)
      end

      self.drawTitle(@win)

      # Draw in the day-of-the-week header.
      (0...7).each do |col|
        src = col_len * ((col + (@week_base % 7)) % 7)
        dst = col_len * col
        Draw.writeChar(@win, @x_offset + dst, @title_lines + 2,
            @day_name[src..-1], CDK::HORIZONTAL, 0, col_len)
      end

      @win.wrefresh
      self.drawField
    end

    # This draws the month field.
    def drawField
      month_name = @month_name[@month]
      month_length = CDK::CALENDAR.getMonthLength(@year, @month)
      year_index = CDK::CALENDAR.YEAR2INDEX(@year)
      year_len = 0
      save_y = -1
      save_x = -1

      day = (1 - @week_day + (@week_base % 7))
      if day > 0
        day -= 7
      end

      (1..6).each do |row|
        (0...7).each do |col|
          if day >= 1 && day <= month_length
            xpos = col * 3
            ypos = row

            marker = @day_attrib
            temp = '%02d' % day

            if @day == day
              marker = @highlight
              save_y = ypos + @field_win.getbegy - @input_window.getbegy
              save_x = 1
            else
              marker |= self.getMarker(day, @month, year_index)
            end
            Draw.writeCharAttrib(@field_win, xpos, ypos, temp, marker,
                CDK::HORIZONTAL, 0, 2)
          end
          day += 1
        end
      end
      @field_win.wrefresh

      # Draw the month in.
      if !(@label_win.nil?)
        temp = '%s %d,' % [month_name, @day]
        Draw.writeChar(@label_win, 0, 0, temp, CDK::HORIZONTAL, 0, temp.size)
        @label_win.wclrtoeol

        # Draw the year in.
        temp = '%d' % [@year]
        year_len = temp.size
        Draw.writeChar(@label_win, @field_width - year_len, 0, temp,
            CDK::HORIZONTAL, 0, year_len)

        @label_win.wmove(0, 0)
        @label_win.wrefresh
      elsif save_y >= 0
        @input_window.wmove(save_y, save_x)
        @input_window.wrefresh
      end
    end

    # This sets multiple attributes of the widget
    def set(day, month, year, day_attrib, month_attrib, year_attrib,
        highlight, box)
      self.setDate(day, month, yar)
      self.setDayAttribute(day_attrib)
      self.setMonthAttribute(month_attrib)
      self.setYearAttribute(year_attrib)
      self.setHighlight(highlight)
      self.setBox(box)
    end

    # This sets the date and some attributes.
    def setDate(day, month, year)
      # Get the current dates and set the default values for the
      # day/month/year values for the calendar
      date_info = Time.new.gmtime

      # Set the date elements if we need to.
      @day = if day == -1 then date_info.day else day end
      @month = if month == -1 then date_info.month else month end
      @year = if year == -1 then date_info.year else year end

      # Verify the date information.
      self.verifyCalendarDate

      # Get the start of the current month.
      @week_day = CDK::CALENDAR.getMonthStartWeekday(@year, @month)
    end

    # This returns the current date on the calendar.
    def getDate(day, month, year)
      day << @day
      month << @month
      year << @year
    end
    
    # This sets the attribute of the days in the calendar.
    def setDayAttribute(attribute)
      @day_attrib = attribute
    end

    def getDayAttribute
      return @day_attrib
    end

    # This sets the attribute of the month names in the calendar.
    def setMonthAttribute(attribute)
      @month_attrib = attribute
    end

    def getMonthAttribute
      return @month_attrib
    end

    # This sets the attribute of the year in the calendar.
    def setYearAttribute(attribute)
      @year_attrib = attribute
    end

    def getYearAttribute
      return @year_attrib
    end

    # This sets the attribute of the highlight box.
    def setHighlight(highlight)
      @highlight = highlight
    end

    def getHighlight
      return @highlight
    end

    # This sets the background attribute of the widget.
    def setBKattr(attrib)
      @win.wbkgd(attrib)
      @field_win.wbkgd(attrib)
      unless @label_win.nil?
        @label_win.wbkgd(attrib)
      end
    end

    # This erases the calendar widget.
    def erase
      if self.validCDKObject
        CDK.eraseCursesWindow(@label_win)
        CDK.eraseCursesWindow(@field_win)
        CDK.eraseCursesWindow(@win)
        CDK.eraseCursesWindow(@shadow_win)
      end
    end

    # This destroys the calendar
    def destroy
      self.cleanTitle

      CDK.deleteCursesWindow(@label_win)
      CDK.deleteCursesWindow(@field_win)
      CDK.deleteCursesWindow(@shadow_win)
      CDK.deleteCursesWindow(@win)

      # Clean the key bindings.
      self.cleanBindings(:CALENDAR)

      # Unregister the object.
      CDK::SCREEN.unregister(:CALENDAR, self)
    end

    # This sets a marker on the calendar.
    def setMarker(day, month, year, marker)
      year_index = CDK::CALENDAR.YEAR2INDEX(year)
      oldmarker = self.getMarker(day, month, year)

      # Check to see if a marker has not already been set
      if oldmarker != 0
        self.setCalendarCell(day, month, year_index,
            oldmarker | Ncurses::A_BLINK)
      else
        self.setCalendarCell(day, month, year_index, marker)
      end
    end

    def getMarker(day, month, year)
      result = 0
      year = CDK::CALENDAR.YEAR2INDEX(year)
      if @marker != 0
        result = self.getCalendarCell(day, month, year)
      end
      return result
    end

    # This sets a marker on the calendar.
    def removeMarker(day, month, year)
      year_index = CDK::CALENDAR.YEAR2INDEX(year)
      self.setCalendarCell(day, month, year_index, 0)
    end

    # THis function sets the month name.
    def setMonthNames(months)
      (1...[months.size, @month_name.size].min).each do |x|
        @month_name[x] = months[x]
      end
    end

    # This function sets the day's name
    def setDaysNames(days)
      @day_name = days.clone
    end

    # This makes sure that the dates provided exist.
    def verifyCalendarDate
      # Make sure the given year is not less than 1900.
      if @year < 1900
        @year = 1900
      end

      # Make sure the month is within range.
      if @month > 12
        @month = 12
      end
      if @month < 1
        @month = 1
      end

      # Make sure the day given is within range of the month.
      month_length = CDK::CALENDAR.getMonthLength(@year, @month)
      if @day < 1
        @day = 1
      end
      if @day > month_length
        @day = month_length
      end
    end

    # This returns what day of the week the month starts on.
    def self.getMonthStartWeekday(year, month)
      return Time.mktime(year, month, 1, 10, 0, 0).wday
    end

    # This function returns a 1 if it's a leap year and 0 if not.
    def self.isLeapYear(year)
      result = false
      if year % 4 == 0
        if year % 100 == 0
          if year % 400 == 0
            result = true
          end
        else
          result = true
        end
      end
      return result
    end

    # This increments the current day by the given value.
    def incrementCalendarDay(adjust)
      month_length = CDK::CALENDAR.getMonthLength(@year, @month)

      # Make sure we adjust the day correctly.
      if adjust + @day > month_length
        # Have to increment the month by one.
        @day = @day + adjust - month_length
        self.incrementCalendarMonth(1)
      else
        @day += adjust
        self.drawField
      end
    end

    # This decrements the current day by the given value.
    def decrementCalendarDay(adjust)
      # Make sure we adjust the day correctly.
      if @day - adjust < 1
        # Set the day according to the length of the month.
        if @month == 1
          # make sure we aren't going past the year limit.
          if @year == 1900
            mesg = [
                '<C></U>Error',
                'Can not go past the year 1900'
            ]
            CDK.Beep
            @screen.popupLabel(mesg, 2)
            return
          end
          month_length = CDK::CALENDAR.getMonthLength(@year - 1, 12)
        else
          month_length = CDK::CALENDAR.getMonthLength(@year, @month - 1)
        end

        @day = month_length - (adjust - @day)

        # Have to decrement the month by one.
        self.decrementCalendarMonth(1)
      else
        @day -= adjust
        self.drawField
      end
    end

    # This increments the current month by the given value.
    def incrementCalendarMonth(adjust)
      # Are we at the end of the year.
      if @month + adjust > 12
        @month = @month + adjust - 12
        @year += 1
      else
        @month += adjust
      end

      # Get the length of the current month.
      month_length = CDK::CALENDAR.getMonthLength(@year, @month)
      if @day > month_length
        @day = month_length
      end

      # Get the start of the current month.
      @week_day = CDK::CALENDAR.getMonthStartWeekday(@year, @month)

      # Redraw the calendar.
      self.erase
      self.draw(@box)
    end

    # This decrements the current month by the given value.
    def decrementCalendarMonth(adjust)
      # Are we at the end of the year.
      if @month <= adjust
        if @year == 1900
          mesg = [
              '<C></U>Error',
              'Can not go past the year 1900',
          ]
          CDK.Beep
          @screen.popupLabel(mesg, 2)
          return
        else
          @month = 13 - adjust
          @year -= 1
        end
      else
        @month -= adjust
      end

      # Get the length of the current month.
      month_length = CDK::CALENDAR.getMonthLength(@year, @month)
      if @day > month_length
        @day = month_length
      end

      # Get the start o the current month.
      @week_day = CDK::CALENDAR.getMonthStartWeekday(@year, @month)

      # Redraw the calendar.
      self.erase
      self.draw(@box)
    end

    # This increments the current year by the given value.
    def incrementCalendarYear(adjust)
      # Increment the year.
      @year += adjust

      # If we are in Feb make sure we don't trip into voidness.
      if @month == 2
        month_length = CDK::CALENDAR.getMonthLength(@year, @month)
        if @day > month_length
          @day = month_length
        end
      end

      # Get the start of the current month.
      @week_day = CDK::CALENDAR.getMonthStartWeekday(@year, @month)

      # Redraw the calendar.
      self.erase
      self.draw(@box)
    end

    # This decrements the current year by the given value.
    def decrementCalendarYear(adjust)
      # Make sure we don't go out o bounds.
      if @year - adjust < 1900
        mesg = [
            '<C></U>Error',
            'Can not go past the year 1900',
        ]
        CDK.Beep
        @screen.popupLabel(mesg, 2)
        return
      end

      # Decrement the year.
      @year -= adjust

      # If we are in Feb make sure we don't trip into voidness.
      if @month == 2
        month_length = CDK::CALENDAR.getMonthLength(@year, @month)
        if @day > month_length
          @day = month_length
        end
      end

      # Get the start of the current month.
      @week_day = CDK::CALENDAR.getMonthStartWeekday(@year, @month)

      # Redraw the calendar.
      self.erase
      self.draw(@box)
    end

    # This returns the length of the current month.
    def self.getMonthLength(year, month)
      month_length = DAYS_OF_THE_MONTH[month]

      if month == 2
        month_length += if CDK::CALENDAR.isLeapYear(year)
                        then 1
                        else 0
                        end
      end

      return month_length
    end

    # This returns what day of the week the month starts on.
    def getCurrentTime
      # Determine the current time and determine if we are in DST.
      return Time.mktime(@year, @month, @day, 0, 0, 0).gmtime
    end

    def focus
      # Original: drawCDKFscale(widget, ObjOf (widget)->box);
      self.draw(@box)
    end

    def unfocus
      # Original: drawCDKFscale(widget, ObjOf (widget)->box);
      self.draw(@box)
    end

    def self.YEAR2INDEX(year)
      if year >= 1900
        year - 1900
      else
        year
      end
    end

    def position
      super(@win)
    end

    def object_type
      :CALENDAR
    end
  end
end
