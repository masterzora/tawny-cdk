require_relative 'scale'

module CDK
  class FSCALE < CDK::SCALE
    def initialize(cdkscreen, xplace, yplace, title, label, field_attr,
        field_width, start, low, high, inc, fast_inc, digits, box, shadow)
      @digits = digits
      super(cdkscreen, xplace, yplace, title, label, field_attr, field_width,
          start, low, high, inc, fast_inc, box, shadow)
    end

    def drawField
      @field_win.werase

      # Draw the value in the field.
      digits = [@digits, 30].min
      format = '%%.%if' % [digits]
      temp = format % [@current]
      
      Draw.writeCharAttrib(@field_win,
          @field_width - temp.size - 1, 0, temp, @field_attr,
          CDK::HORIZONTAL, 0, temp.size)

      self.moveToEditPosition(@field_edit)
      @field_win.wrefresh
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
      :FSCALE
    end
  end
end
