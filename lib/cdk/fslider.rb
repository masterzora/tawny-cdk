require_relative 'slider'

module CDK
  class FSLIDER < CDK::SLIDER
    def initialize(cdkscreen, xplace, yplace, title, label, filler,
        field_width, start, low, high, inc, fast_inc, digits, box, shadow)
      @digits = digits
      super(cdkscreen, xplace, yplace, title, label, filler, field_width,
          start, low, high, inc, fast_inc, box, shadow)
    end

    # This draws the widget.
    def drawField
      step = 1.0 * @field_width / (@high - @low)

      # Determine how many filler characters need to be drawn.
      filler_characters = (@current - @low) * step

      @field_win.werase

      # Add the character to the window.
      (0...filler_characters).each do |x|
        @field_win.mvwaddch(0, x, @filler)
      end

      # Draw the value in the field.
      digits = [@digits, 30].min
      format = '%%.%if' % [digits]
      temp = format % [@current]

      Draw.writeCharAttrib(@field_win, @field_width, 0, temp,
          Ncurses::A_NORMAL, CDK::HORIZONTAL, 0, temp.size)

      self.moveToEditPosition(@field_edit)
      @field_win.wrefresh
    end

    def formattedSize(value)
      digits = [@digits, 30].min
      format = '%%.%if' % [digits]
      temp = format % [value]
      return temp.size
    end

    def setDigits(digits)
      @digits = [0, digits].max
    end

    def getDigits
      return @digits
    end

    def SCAN_FMT
      '%g%c'
    end

    def object_type
      :FSLIDER
    end
  end
end
