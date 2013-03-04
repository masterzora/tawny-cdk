# cdk.rb

# Copyright (c) 2013, Chris Sauro
# All rights reserved.
# 
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are met:
#     * Redistributions of source code must retain the above copyright
#       notice, this list of conditions and the following disclaimer.
#     * Redistributions in binary form must reproduce the above copyright
#       notice, this list of conditions and the following disclaimer in the
#       documentation and/or other materials provided with the distribution.
#     * Neither the name of Chris Sauro nor the
#       names of its contributors may be used to endorse or promote products
#       derived from this software without specific prior written permission.
# 
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
# ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
# WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
# DISCLAIMED. IN NO EVENT SHALL <COPYRIGHT HOLDER> BE LIABLE FOR ANY
# DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
# (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
# LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
# ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
# (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
# SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

require 'ncurses'

module CDK
  # some useful global values
  
  CDK_PATHMAX = 256
  
  L_MARKER = '<'
  R_MARKER = '>'

  LEFT = 9000
  RIGHT = 9001
  CENTER = 9002
  TOP = 9003
  BOTTOM = 9004
  HORIZONTAL = 9005
  VERTICAL = 9006
  FULL = 9007

  NONE = 0
  ROW = 1
  COL = 2

  MAX_BINDINGS = 300
  MAX_ITEMS = 2000
  MAX_BUTTONS = 200

  ALL_SCREENS = []
  ALL_OBJECTS = []
  
  # This beeps then flushes the stdout stream
  def CDK.Beep
    Ncurses.beep
    $stdout.flush
  end

  # This sets a blank string to be len of the given characer.
  def CDK.cleanChar(s, len, character)
    s << character * len
  end

  def CDK.cleanChtype(s, len, character)
    s.concat(character * len)
  end

  # This takes an x and y position and realigns the values iff they sent in
  # values like CENTER, LEFT, RIGHT
  #
  # window is an Ncurses::WINDOW object
  # xpos, ypos is an array with exactly one value, an integer
  # box_width, box_height is an integer
  def CDK.alignxy (window, xpos, ypos, box_width, box_height)
    first = window.getbegx
    last = window.getmaxx
    if (gap = (last - box_width)) < 0
      gap = 0
    end
    last = first + gap

    case xpos[0]
    when LEFT
      xpos[0] = first
    when RIGHT
      xpos[0] = first + gap
    when CENTER
      xpos[0] = first + (gap / 2)
    else
      if xpos[0] > last
        xpos[0] = last
      elsif xpos[0] < first
        xpos[0] = first
      end
    end

    first = window.getbegy
    last = window.getmaxy
    if (gap = (last - box_height)) < 0
      gap = 0
    end
    last = first + gap

    case ypos[0]
    when TOP
      ypos[0] = first
    when BOTTOM
      ypos[0] = first + gap
    when CENTER
      ypos[0] = first + (gap / 2)
    else
      if ypos[0] > last
        ypos[0] = last
      elsif ypos[0] < first
        ypos[0] = first
      end
    end
  end

  # This takes a string, a field width, and a justification type
  # and returns the adjustment to make, to fill the justification
  # requirement
  def CDK.justifyString (box_width, mesg_length, justify)

    # make sure the message isn't longer than the width
    # if it is, return 0
    if mesg_length >= box_width
      return 0
    end

    # try to justify the message
    case justify
    when LEFT
      0
    when RIGHT
      box_width - mesg_length
    when CENTER
      (box_width - mesg_length) / 2
    else
      justify
    end
  end

  # This reads a file and sticks it into the list provided.
  def CDK.readFile(filename, array)
    fd = File.new(filename, "r")  # TODO add in error handling
    array.concat(fd.readlines)
    fd.close
    array.size
  end

  def CDK.encodeAttribute (string, from, mask)
    mask << 0
    case string[from + 1]
    when 'B'
      mask[0] = Ncurses::A_BOLD
    when 'D'
      mask[0] = Ncurses::A_DIM
    when 'K'
      mask[0] = Ncurses::A_BLINK
    when 'R'
      mask[0] = Ncurses::A_REVERSE
    when 'S'
      mask[0] = Ncurses::A_STANDOUT
    when 'U'
      mask[0] = Ncurses::A_UNDERLINE
    end

    if mask[0] != 0
      from += 1
    elsif CDK.digit?(string[from+1]) and CDK.digit?(string[from + 2])
      if Ncurses.has_colors?
        # XXX: Only checks if terminal has colours not if colours are started
        pair = string[from + 1..from + 2].to_i
        mask[0] = Ncurses.COLOR_PAIR(pair)
      else
        mask[0] = Ncurses.A_BOLD
      end

      from += 2
    elsif CDK.digit?(string[from + 1])
      if Ncurses.has_colors?
        # XXX: Only checks if terminal has colours not if colours are started
        pair = string[from + 1].to_i
        mask[0] = Ncurses.COLOR_PAIR(pair)
      else
        mask[0] = Ncurses.A_BOLD
      end

      from += 1
    end

    return from
  end

  # The reverse of encodeAttribute
  # Well, almost.  If attributes such as bold and underline are combined in the
  # same string, we do not necessarily reconstruct them in the same order.
  # Also, alignment markers and tabs are lost.

  def CDK.decodeAttribute (string, from, oldattr, newattr)
    table = {
      'B' => Ncurses::A_BOLD,
      'D' => Ncurses::A_DIM,
      'K' => Ncurses::A_BLINK,
      'R' => Ncurses::A_REVERSE,
      'S' => Ncurses::A_STANDOUT,
      'U' => Ncurses::A_UNDERLINE
    }

    result = if !(string.nil?) then string else '' end
    base_len = result.size
    tmpattr = oldattr & Ncurses.A_ATTRIBUTES

    newattr &= A_ATTRIBUTES
    if tmpattr != newattr
      while tmpattr != newattr
        found = false
        table.keys.each do |key|
          if (table[key] & tmpattr) != (table[key] & newattr)
            found = true
            result << L_MARKER
            if (table[key] & tmpattr).nonzero?
              result << '!'
              tmpattr &= ~(table[key])
            else
              result << '/'
              tmpattr |= table[key]
            end
            result << key
            break
          end
        end
        # XXX: Only checks if terminal has colours not if colours are started
        if Ncurses.has_colors?
          if (tmpattr & Ncurses.A_COLOR) != (newattr & Ncurses.A_COLOR)
            oldpair = Ncurses.PAIR_NUMBER(tmpattr)
            newpair = Ncurses.PAIR_NUMBER(newattr)
            if !found
              found = true
              result << L_MARKER
            end
            if newpair.zero?
              result << '!'
              result << oldpair.to_s
            else
              result << '/'
              result << newpair.to_s
            end
            tmpattr &= ~(Ncurses.A_COLOR)
            newattr &= ~(Ncurses.A_COLOR)
          end
        end

        if found
          result << R_MARKER
        else
          break
        end
      end
    end

    return from + result.size - base_len
  end

  # This function takes a string, full of format markers and translates
  # them into a chtype array.  This is better suited to curses because
  # curses uses chtype almost exclusively
  def CDK.char2Chtype (string, to, align)
    to << 0
    align << LEFT
    result = []

    if string.size > 0
      used = 0

      # We make two passes because we may have indents and tabs to expand and do
      # not know in advance how large the result will be.
      [0, 1].each do |pass|
        adjust = 0
        attrib = Ncurses::A_NORMAL
        last_char = 0
        start = 0
        used = 0
        x = 3

        # Look for an alignment marker.
        if string[0] == L_MARKER
          if string[1] == 'C' && string[2] == R_MARKER
            align[0] = CENTER
            start = 3
          elsif string[1] == 'R' && string[2] == R_MARKER
            align[0] = RIGHT
            start = 3
          elsif string[1] == 'L' && string[2] == R_MARKER
            start = 3
          elsif string[1] == 'B' && string[2] == '='
            # Set the item index value in the string.
            result = [' '.ord, ' '.ord, ' '.ord]

            # Pull out the bullet marker.
            while x < string.size and string[x] != R_MARKER
              result << string[x].ord | Ncurses::A_BOLD
              x += 1
            end
            adjust = 1

            # Set the alignment variables
            start = x
            used = x
          elsif string[1] == 'I' && string[2] == '='
            from = 3
            x = 0

            while from < string.size && string[from] != Ncurses.R_MARKER
              if CDK.digit?(string[from])
                adjust = adjust * 10 + string[from].to_i
                x += 1
              end
              from += 1
            end

            start = x + 4
          end
        end
        
        while adjust > 0
          adjust -= 1
          result << ' '
          used += 1
        end

        # Set the format marker boolean to false
        inside_marker = false

        # Start parsing the character string.
        from = start
        while from < string.size
          # Are we inside a format marker?
          if !inside_marker
            if string[from] == L_MARKER &&
                ['/', '!', '#'].include?(string[from + 1])
              inside_marker = true
            elsif string[from] == "\\" && string[from + 1] == L_MARKER
              from += 1
              result << (string[from].ord | attrib)
              used += 1
              from += 1
            elsif string[from] == "\t"
              begin
                result << ' '
                used += 1
              end while (used & 7).nonzero?
            else
              result << (string[from].ord | attrib)
              used += 1
            end
          else
            case string[from]
            when R_MARKER
              inside_marker = false
            when '#'
              last_char = 0
              case string[from + 2]
              when 'L'
                case string[from + 1]
                when 'L'
                  last_char = Ncurses.ACS_LLCORNER
                when 'U'
                  last_char = Ncurses.ACS_ULCORNER
                when 'H'
                  last_char = Ncurses.ACS_HLINE
                when 'V'
                  last_char = Ncurses.ACS_VLINE
                when 'P'
                  last_char = Ncurses.ACS_PLUS
                end
              when 'R'
                case string[from + 1]
                when 'L'
                  last_char = Ncurses.ACS_LRCORNER
                when 'U'
                  last_char = Ncurses.ACS_URCORNER
                end
              when 'T'
                case string[from + 1]
                when 'T'
                  last_char = Ncurses.ACS_TTEE
                when 'R'
                  last_char = Ncurses.ACS_RTEE
                when 'L'
                  last_char = Ncurses.ACS_LTEE
                when 'B'
                  last_char = Ncurses.ACS_BTEE
                end
              when 'A'
                case string[from + 1]
                when 'L'
                  last_char = Ncurses.ACS_LARROW
                when 'R'
                  last_char = Ncurses.ACS_RARROW
                when 'U'
                  last_char = Ncurses.ACS_UARROW
                when 'D'
                  last_char = Ncurses.ACS_DARROW
                end
              else
                case [string[from + 1], string[from + 2]]
                when ['D', 'I']
                  last_char = Ncurses.ACS_DIAMOND
                when ['C', 'B']
                  last_char = Ncurses.ACS_CKBOARD
                when ['D', 'G']
                  last_char = Ncurses.ACS_DEGREE
                when ['P', 'M']
                  last_char = Ncurses.ACS_PLMINUS
                when ['B', 'U']
                  last_char = Ncurses.ACS_BULLET
                when ['S', '1']
                  last_char = Ncurses.ACS_S1
                when ['S', '9']
                  last_char = Ncurses.ACS_S9
                end
              end

              if last_char.nonzero?
                adjust = 1
                from += 2

                if string[from + 1] == '('
                  # check for a possible numeric modifier
                  from += 2
                  adjust = 0

                  while from < string.size && string[from] != ')'
                    if CDK.digit?(string[from])
                      adjust = (adjust * 10) + string[from].to_i
                    end
                  end
                end
              end
              (0..adjust).each do |x|
                result << (last_char | attrib)
                used += 1
              end
            when '/'
              mask = []
              from = CDK.encodeAttribute(string, from, mask)
              attrib |= mask[0]
            when '!'
              mask = []
              from = CDK.encodeAttribute(string, from, mask)
              attrib |= ~(mask[0])
            end
          end
          from += 1
        end

        if result.size == 0
          result << attrib
        end
      end
      to[0] = used
    else
      result = ''
    end
    return result
  end

  # Compare a regular string to a chtype string
  def CDK.cmpStrChstr (str, chstr)
    i = 0
    r = 0

    if str.nil? && chstr.nil?
      return 0
    elsif str.nil?
      return 1
    elsif chstr.nil?
      return -1
    end

    while i < str.size && i < chstr.size
      if str[r].ord < chstr[r]
        return -1
      elsif str[r].ord > chstr[r]
        return 1
      end
      i += 1
    end

    if str.size < chstr.size
      return -1
    elsif str.size > chstr.size
      return 1
    else
      return 0
    end
  end

  # This returns a string from a chtype array
  # Formatting codes are omitted.
  def CDK.chtype2Char(string)
    newstring = ''
    
    unless string.nil?
      string.each do |char|
        newstring << char.chr
      end
    end

    return newstring
  end

  # This returns a string from a chtype array
  # Formatting codes are embedded
  def CDK.chtype2String(string)
    newstring = ''
    unless string.nil?
      (0...string.size).each do |x|
        need = CDK.decodeAttribute(newstring, need,
                                   x > 0 ? string[x - 1] : 0, string[x])
        newstring << string[x]
      end
    end

    return newstring
  end



  # This returns the length of the integer.
  #
  # Currently a wrapper maintained for easy of porting.
  def CDK.intlen (value)
    value.to_str.size
  end

  # This opens the current directory and reads the contents.
  def CDK.getDirectoryContents(directory, list)
    counter = 0

    # Open the directory.
    Dir.foreach(directory) do |filename|
      next if filename[0] == '.'
      list << filename
    end

    list.sort!
    return list.size
  end


  # This function checks to see if a link has been requested
  def CDK.checkForLink (line, filename)
    f_pos = 0
    x = 3
    if line.nil?
      return -1
    end

    # Strip out the filename.
    if line[0] == L_MARKER && line[1] == 'F' && line[2] == '='
      while x < line.size
        if line[x] == R_MARKER
          break
        end
        if f_pos < CDK_PATHMAX
          filename << line[x]
          f_pos += 1
        end
        x += 1
      end
    end
    return f_pos != 0
  end

  # Returns the filename portion of the given pathname, i.e. after the last
  # slash
  # For now this function is just a wrapper for File.basename kept for ease of
  # porting and will be completely replaced in the future
  def CDK.baseName (pathname)
    File.basename(pathname)
  end

  # Returns the directory for the given pathname, i.e. the part before the
  # last slash
  # For now this function is just a wrapper for File.dirname kept for ease of
  # porting and will be completely replaced in the future
  def CDK.dirName (pathname)
    File.dirname(pathname)
  end

  # If the dimension is a negative value, the dimension will be the full
  # height/width of the parent window - the value of the dimension. Otherwise,
  # the dimension will be the given value.
  def CDK.setWidgetDimension (parent_dim, proposed_dim, adjustment)
    # If the user passed in FULL, return the parents size
    if proposed_dim == FULL or proposed_dim == 0
      parent_dim
    elsif proposed_dim >= 0
      # if they gave a positive value, return it

      if proposed_dim >= parent_dim
        parent_dim
      else
        proposed_dim + adjustment
      end
    else
      # if they gave a negative value then return the dimension
      # of the parent plus the value given
      #
      if parent_dim + proposed_dim < 0
        parent_dim
      else
        parent_dim + proposed_dim
      end
    end
  end

  # This safely erases a given window
  def CDK.eraseCursesWindow (window)
    return if window.nil?

    window.werase
    window.wrefresh
  end

  # This safely deletes a given window.
  def CDK.deleteCursesWindow (window)
    return if window.nil?

    CDK.eraseCursesWindow(window)
    window.delwin
  end

  # This moves a given window (if we're able to set the window's beginning).
  # We do not use mvwin(), because it does not (usually) move subwindows.
  def CDK.moveCursesWindow (window, xdiff, ydiff)
    return if window.nil?

    xpos = []
    ypos = []
    window.getbegyx(ypos, xpos)
    if window.setbegyx(ypos[0], xpos[0]) != Ncurses::ERR
      xpos += xdiff
      ypos += ydiff
      window.werase
      window.setbegyx(ypos, xpos)
    else
      CDK.Beep
    end
  end

  def CDK.digit?(character)
    !(character.match(/^[[:digit:]]$/).nil?)
  end

  def CDK.alpha?(character)
    !(character.match(/^[[:alpha:]]$/).nil?)
  end

  def CDK.isChar(c)
    c >= 0 && c < Ncurses::KEY_MIN
  end

  class CDKOBJS
    attr_accessor :screen_index, :screen, :has_focus, :is_visible, :box
    attr_accessor :ULChar, :URChar, :LLChar, :LRChar, :HZChar, :VTChar, :BXAttr

    def initialize
      @has_focus = true
      @is_visible = true

      CDK::ALL_OBJECTS << self

      # set default line-drawing characters
      @ULChar = Ncurses::ACS_ULCORNER
      @URChar = Ncurses::ACS_URCORNER
      @LLChar = Ncurses::ACS_LLCORNER
      @LRChar = Ncurses::ACS_LRCORNER
      @HZChar = Ncurses::ACS_HLINE
      @VTChar = Ncurses::ACS_VLINE
      @BXAttr = Ncurses::A_NORMAL

      # set default exit-types
      @exit_type = :NEVER_ACTIVATED
      @early_exit = :NEVER_ACTIVATED
    end

    def object_type
      # no type by default
      :NULL
    end

    def validObjType(type)
      # dummy version for now
      true
    end

    def SCREEN_XPOS(n)
      n + @border_size
    end

    def SCREEN_YPOS(n)
      n + @border_size + @title_lines
    end

    # Set the object's upper-left-corner line-drawing character.
    def setCdkULchar(ch)
      @ULChar = ch
    end

    # Set the object's upper-right-corner line-drawing character.
    def setCdkURchar(ch)
      @URChar = ch
    end

    # Set the object's lower-left-corner line-drawing character.
    def setCdkLLchar(ch)
      @LLChar = ch
    end

    # Set the object's upper-right-corner line-drawing character.
    def setCdkLRchar(ch)
      @LRChar = ch
    end

    # Set the object's horizontal line-drawing character
    def setCdkHZchar(ch)
      @HZChar = ch
    end

    # Set the object's vertical line-drawing character
    def setCdkVTchar(ch)
      @VTChar = ch
    end

    # Set the object's box-attributes.
    def setCdkBXattr(ch)
      @BXAttr = ch
    end

    # This sets the background color of the widget.
    def setCDKObjectBackgroundColor(color)
      return if color.nil? || color == ''

      junk1 = []
      junk2 = []
      
      # Convert the value of the environment variable to a chtype
      holder = CDK.char2Chtype(color, junk1, junk2)

      # Set the widget's background color
      self.SetBackAttrObj(holder[0])
    end

    # Set the widget's title.
    def setCdkTitle (title, box_width)
      if !title.nil? 
        temp = title.split("\n")
        @title_lines = temp.size
        
        if box_width >= 0
          max_width = 0
          temp.each do |line|
            len = []
            align = []
            holder = CDK.char2Chtype(line, len, align)
            max_width = [len, max_width].max
          end
          box_width = [box_width, max_width + 2 * @border_size].max
        else
          box_width = -(box_width - 1)
        end

        # For each line in the title convert from string to chtype array
        title_width = box_width - (2 * @border_size)
        @title = []
        @title_pos = []
        @title_len = []
        (0...@title_lines).each do |x|
          len_x = []
          pos_x = []
          @title << CDK.char2Chtype(temp[x], len_x, pos_x)
          @title_len.concat(len_x)
          @title_pos << CDK.justifyString(title_width, len_x, pos_x)
        end
      end

      return box_width
    end

    # Draw the widget's title
    def drawCdkTitle(win)
      (0...@title_lines).each do |x|
        Draw.writeChtype(@win, @title_pos[x] + @border_size,
            x + @border_size, @title[x], CDK::HORIZONTAL, 0,
            @title_len[x])
      end
    end

    # Remove storage for the widget's title.
    def cleanCdkTitle
      @title_lines = 0
    end

    # Set data for preprocessing
    def setCDKObjectPreProcess (fn, data)
      @pre_process_function = fn
      @pre_process_data = data
    end

    # Set data for postprocessing
    def setCDKObjectPostProcess (fn, data)
      @post_process_function = fn
      @post_process_data = data
    end
    
    # Set the object's exit-type based on the input.
    # The .exitType field should have been part of the CDKOBJS struct, but it
    # is used too pervasively in older applications to move (yet).
    def setCdkExitType(type, ch)
      type << 0
      case ch
      when Ncurses::KEY_ERROR
        type[0] = :ERROR
      when Ncurses::KEY_ESC
        type[0] = :ESCAPE_HIT
      when Ncurses::KEY_TAB, Ncurses::KEY_ENTER
        type[0] = :NORMAL
      when 0
        type[0] = :EARLY_EXIT
      end
      # make the result available via the object
      @exit_type = type[0]
    end

    def validCDKObject
      result = false
      if CDK::ALL_OBJECTS.include?(self)
        result = self.validObjType(@object_type)
      end
      return result
    end

    def getc
      cdktype = @object_type
      # CDKOBJS *test = bindableObject (&cdktype, obj);
      result = @input_window.wgetch

      #if (result >= 0
      #    && test != 0
      #    && (unsigned)result < test->bindingCount
      #    && test->bindingList[result].bindFunction == getcCDKBind)
      # [...]
      # else if (test == 0
      #          || (unsigned)result >= test->bindingCount
      #          || test->bindingList[result].bindFunction == 0)
      case result
      when "\r".ord, "\n".ord
        result = Ncurses::KEY_ENTER
      when "\t".ord
        result = Ncurses::KEY_TAB
      when "\177".ord  # DELETE
        result = Ncurses::KEY_DC
      when "\b".ord
        result = Ncurses::KEY_BACKSPACE
      when "A".ord & 0x1f  # CDK_BEGOFLINE - Ctrl-A
        result = Ncurses::KEY_HOME
      when "E".ord & 0x1f  # CDK_ENDOFLINE - Ctrl-E
        result = Ncurses::KEY_END
      when "F".ord & 0x1f  # CDK_FORCHAR - Ctrl-F
        result = Ncurses::KEY_RIGHT
      when "B".ord & 0x1f  # CDK_BACKCHAR - Ctrl-B
        result = Ncurses::KEY_LEFT
      when "N".ord & 0x1f  # CDK_NEXT - Ctrl-N
        result = Ncurses::KEY_TAB
      when "P".ord & 0x1f  # CDK_PREF - Ctrl-P
        result = Ncurses::KEY_BTAB
      end

      return result
    end

    def getch(function_key)
      key = self.getc
      function_key << (key >= Ncurses::KEY_MIN && key <= Ncurses::KEY_MAX)
      return key
    end
#  CDKOBJS struct values copied below for reference convenience

#   const CDKFUNCS * fn;
#   int          borderSize;
#   boolean      acceptsFocus;
#   WINDOW *     inputWindow;
#   void *       dataPtr;
#   CDKDataUnion resultData;
#   unsigned     bindingCount;
#   CDKBINDING * bindingList;
#   /* title-drawing */
#   chtype **    title;
#   int *        titlePos;
#   int *        titleLen;
#   int          titleLines;
#   /* events */
#   EExitType    exitType;
#   EExitType    earlyExit;
#   /* pre/post-processing */
#   PROCESSFN    preProcessFunction;
#   void *       preProcessData;
#   PROCESSFN    postProcessFunction;
#   void *       postProcessData;

#  CDKFUNCS functions pasted below for reference convenience
#   EObjectType  objectType;
#   CDKDataType  returnType;
#   void         (*drawObj)         (struct CDKOBJS *, boolean);
#   void         (*eraseObj)        (struct CDKOBJS *);
#   void         (*moveObj)         (struct CDKOBJS *, int, int, boolean, boolean);
#   int          (*injectObj)       (struct CDKOBJS *, chtype);
#   void         (*focusObj)        (struct CDKOBJS *);
#   void         (*unfocusObj)      (struct CDKOBJS *);
#   void         (*saveDataObj)     (struct CDKOBJS *);
#   void         (*refreshDataObj)  (struct CDKOBJS *);
#   void         (*destroyObj)      (struct CDKOBJS *);
#   /* line-drawing */
#   void         (*setULcharObj)    (struct CDKOBJS *, chtype);
#   void         (*setURcharObj)    (struct CDKOBJS *, chtype);
#   void         (*setLLcharObj)    (struct CDKOBJS *, chtype);
#   void         (*setLRcharObj)    (struct CDKOBJS *, chtype);
#   void         (*setVTcharObj)    (struct CDKOBJS *, chtype);
#   void         (*setHZcharObj)    (struct CDKOBJS *, chtype);
#   void         (*setBXattrObj)    (struct CDKOBJS *, chtype);
#   /* background attribute */
#   void         (*setBKattrObj)    (struct CDKOBJS *, chtype);

  end

  class SCREEN
    attr_accessor :object_focus, :object_count, :object_limit, :object, :window
    def initialize (window)
      # initialization for the first time
      if CDK::ALL_SCREENS.size == 0
        # Set up basic curses settings.
        # #ifdef HAVE_SETLOCALE
        # setlocale (LC_ALL, "");
        # #endif
        
        Ncurses.noecho
        Ncurses.cbreak
      end

      CDK::ALL_SCREENS << self
      @object_count = 0
      @object_limit = 2
      @object = Array.new(@object_limit, nil)
      @window = window
    end

    def destroyCDKObject
      # TODO Let Ruby take care of memory management, please
      # This is currently just kept for ease of porting.
      # It should be deleted at nearest convenience
    end

    # This registers a CDK object with a screen.
    def register(cdktype, object)
      if @object_count + 1 >= @object_limit
        @object_limit += 2
        @object_limit *= 2
        @object.concat(Array.new(@object_limit - @object.size, nil))
      end

      if object.validObjType(cdktype)
        self.setScreenIndex(@object_count, object)
        @object_count += 1
      end
    end

    # This removes an object from the CDK screen.
    def self.unregisterCDKObject(cdktype, object)
      if object.validObjType(cdktype) && object.screen_index >= 0
        screen = object.screen

        unless screen.nil?
          index = object.screen_index
          object.screen_index = -1

          # Resequence the objects
          (index...screen.object_count - 1).each do |x|
            screen.setScreenIndex(x, screen.object[x+1])
          end

          if screen.object_count <= 1
            # if no more objects, remove the array
            screen.object = []
            screen.object_count = 0
            screen.object_limit = 0
          else
            screen.object[screen.object_count] = nil
            screen.object_count -= 1

            # Update the object-focus
            if screen.object_focus == index
              screen.object_focus -= 1
              screen.setCDKFocusNext
            elsif screen.object_focus > index
              screen.object_focus -= 1
            end
          end
        end
      end
    end

    def setScreenIndex(number, obj)
      obj.screen_index = number
      obj.screen = self
      self.object[number] = obj
    end

    def validIndex(n)
      n >= 0 && n < @object_count
    end

    def swapCDKIndices(n1, n2)
      if n1 != n2 && self.validIndex(n1) && self.validIndex(n2)
        o1 = screen.object[n1]
        o2 = screen.object[n2]
        self.setScreenIndex(screen, n1, o2)
        self.setScreenIndex(n2, o1)

        if screen.object_focus == n1
          screen.object_focus = n2
        elsif screen.object_focus == n2
          screen.object_focus = n1
        end
      end
    end

    # This 'brings' a CDK object to the top of the stack.
    def self.raiseCDKObject(cdktype, object)
      if object.validObjType(cdktype)
        object.screen.swapCDKIndices(object.screen_index, object.screen.object_count - 1)
      end
    end

    # This 'lowers' an object.
    def self.lowerCDKObject(cdktype, object)
      if object.validObjType(cdktype)
        object.screen.swapCDKIndices(object.screen_index, 0)
      end
    end

    # This calls SCREEN.refresh, (made consistent with widgets)
    def draw
      self.refresh
    end

    # Refresh one CDK window.
    # FIXME(original): this should be rewritten to use the panel library, so
    # it would not be necessary to touch the window to ensure that it covers
    # other windows.
    def SCREEN.refreshCDKWindow(win)
      win.touchwin
      win.wrefresh
    end

    # This refreshes all the objects in the screen.
    def refresh
      focused = -1
      visible = -1

      CDK::SCREEN.refreshCDKWindow(@window)

      # We erase all the invisible objects, then only draw it all back, so
      # that the objects can overlap, and the visible ones will always be
      # drawn after all the invisible ones are erased
      (0...@object_count).each do |x|
        obj = @object[x]
        if obj.validObjType(obj.object_type)
          if obj.is_visible
            if visible < 0
              visible = x
            end
            if obj.has_focus && focused < 0
              focused = x
            end
          else
            obj.erase
          end
        end
      end

      (0...@object_count).each do |x|
        obj = @object[x]

        if obj.validObjType(obj.object_type)
          obj.has_focus = (x == focused)

          if obj.is_visible
            obj.draw(obj.box)
          end
        end
      end
    end

    # This clears all the objects in the screen
    def erase
      # We just call the object erase function
      (0...@object_count).each do |x|
        obj = @object[x]
        if obj.validObjType(obj.object_Type)
          obj.erase
        end
      end

      # Refresh the screen.
      @window.wrefresh
    end

    # Destroy all the objects on a screen
    def destroyCDKScreenObjects
      (0...@object_count).each do |x|
        obj = @object[x]
        before = @object_count

        if obj.validObjType(obj.object_type)
          obj.erase
          obj.destroyCDKObject
          x -= (@object_count - before)
        end
      end
    end

    # This destroys a CDK screen.
    def destroy
      CDK::ALL_SCREENS.delete(self)
    end

    # This is added to remain consistent
    def self.endCDK
      Ncurses.echo
      Ncurses.nocbreak
      Ncurses.endwin
    end
  end

  class LABEL < CDK::CDKOBJS
    def initialize(cdkscreen, xplace, yplace, mesg, rows, box, shadow)
      super()
      parent_width = cdkscreen::window.getmaxx
      parent_height = cdkscreen::window.getmaxy
      box_width = -2**30  # -INFINITY
      box_height = 0
      xpos = [xplace]
      ypos = [yplace]
      x = 0

      #   if (rows <= 0
      #       || (label = newCDKObject (CDKLABEL, &my_funcs)) == 0
      #       || (label->info = typeCallocN (chtype *, rows + 1)) == 0
      #       || (label->infoLen = typeCallocN (int, rows + 1)) == 0
      #       || (label->infoPos = typeCallocN (int, rows + 1)) == 0)
      #   {
      #      destroyCDKObject (label);
      #      return (0);
      #   }

      if rows <= 0
        return 0
      end

      #setCDKLabelBox (label, Box)
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
        #destroyCDKObject (label);
        #return (0);
        return
      end

      @win.keypad(true)

      # If a shadow was requested, then create the shadow window.
      if shadow
        @shadow_win = Ncurses::WINDOW.new(box_height, box_width,
            ypos[0] + 1, xpos[0] + 1)
      end

      # Register this
      cdkscreen.register(:LABEL, self)
      #
      # Return the label pointer
      # return (label);
    end

    # This was added for the builder.
    # void activateCDKLabel (CDKLABEL #label, chtype *actions GCC_UNUSED)
    def activate(actions)
      self.drawCDKLabel(@box)
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
        @info_pos = 0
        @info_len = 0
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
        @info_pos[x] = info_pos[0]
        @info_pos[x] = Cdk.justifyString(@box_width - 2 * @border_size,
            @info_len[x], info_pos[x])
      end

      # Redraw the label widget.
      # eraseCDKLabel (label);
      # drawCDKLabel (label, ObjOf (label)->box;
      self.erase
      self.draw(box)
    end

    def getMessage(size)
      size << @rows
      return @info
    end

    # This sets the box flag for the label widget.
    def setBox(box)
      @box = box
      @border_size = if @box then 1 else 0 end
    end

    def getBox
      return @box
    end

    # This sets the background attribute of the widget.
    def setBKattrLabel(attrib)
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
    def moveCDKLabel(xplace, yplace, relative, refresh_flag)
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
      SCREEN.refreshCDKWindow(@screen.window)

      # Redraw the window, if they asked for it.
      if refresh_flag
        self.draw(@box)
      end
    end

    # This destroys the label object pointer.
    # static void _destroyCDKLabel (CDKOBJS *object)
    def destroy
      # if (object != 0)
      # {
      #    CDKLABEL *label = (CDKLABEL *)object;
    
      #    CDKfreeChtypes (label->info);
      #    freeChecked (label->infoLen);
      #    freeChecked (label->infoPos);
    
      #    /* Free up the window pointers. */
      #    deleteCursesWindow (label->shadowWin);
      #    deleteCursesWindow (label->win);
    
      #    /* Clean the key bindings. */
      #    cleanCDKObjectBindings (vLABEL, label);
    
      #    /* Unregister the object. */
      #    unregisterCDKObject (vLABEL, label);
      # }
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

    # dummyInject (Label)
    # dummyFocus (Label)
    # dummyUnfocus (Label)
    # dummyRefreshData (Label)
    # dummySaveData (Label)
  end

  class SCROLL < CDK::CDKOBJS
    #struct SScroll {
    #   CDKOBJS      obj;
    #   WINDOW       *parent;
    #   WINDOW       *win;
    #   WINDOW       *scrollbarWin;
    #   WINDOW       *listWin;
    #   WINDOW       *shadowWin;
    #   int          titleAdj;       /* unused */
    #   chtype **    item;           /* */
    #   int *        itemPos;        /* */
    #   int *        itemLen;        /* */
    #   int          maxTopItem;     /* */
    #   int          maxLeftChar;    /* */
    #   int          leftChar;       /* */
    #   int          lastItem;       /* */
    #   int          currentTop;     /* */
    #   int          currentItem;    /* */
    #   int          currentHigh;    /* */
    #   int          listSize;       /* */
    #   int          boxWidth;       /* */
    #   int          boxHeight;      /* */
    #   int          viewSize;       /* */
    #
    #   int          scrollbarPlacement; /* UNUSED */
    #   boolean      scrollbar;      /* UNUSED */
    #   int          toggleSize;     /* size of scrollbar thumb/toggle */
    #   int          togglePos;      /* position of scrollbar thumb/toggle */
    #   float        step;           /* increment for scrollbar */
    #
    #   EExitType    exitType;       /* */
    #   boolean      shadow;         /* */
    #   boolean      numbers;        /* */
    #   chtype       titlehighlight; /* */
    #   chtype       highlight;      /* */
    #};
    
    attr_reader :exit_type

    def initialize (cdkscreen, xplace, yplace, splace, height, width, title,
        list, list_size, numbers, highlight, box, shadow)
      parent_width = cdkscreen.window.getmaxx
      parent_height = cdkscree.nwindow.height
      box_width = width
      box_height = height
      xpos = xplace
      ypos = yplace
      scroll_adjust = 0
      bindings = {
        CDK_BACKCHAR => Ncurses::KEY_PPAGE,
        CDK_FORCHAR  => Ncurses::KEY_NPAGE,
        'g'          => Ncurses::KEY_HOME,
        '1'          => Ncurses::KEY_HOME,
        'G'          => Ncurses::KEY_END,
        '<'          => Ncurses::KEY_HOME,
        '>'          => Ncurses::KEY_END
      }

      @box = box
      @border_size = if box.nil? then 0 else 1 end

      # If the height is a negative value, the height will be ROWS-height,
      # otherwise the height will be the given height
      box_height = CDK.setWidgetDimension(parent_height, height, 0)

      # If the width is a negative value, the width will be COLS-width,
      # otherwise the width will be the given width
      box_width = CDK.setWidgetDimension(parent_width, width, 0)
    
      self.setCdkTitle(title, box_width)

      # Set the box height.
      if @title_lines > box_height
        box_height = @title_lines + [list_size, 8].min + 2 * @border_size
      end

      # Adjust the box width if there is a scroll bar
      if splace == CDK::LEFT || splace == CDK::RIGHT
        @scrollbar = true
        box_width += 1
      else
        @scrollbar = false
      end

      # Make sure we didn't extend beyond the dimensions of the window.
      box_width = if box_width > parent_width 
                   then parent_width - scroll_adjust 
                   else box_width 
                   end
      box_height = if box_height > parent_height
                    then parent_height
                    else box_height
                    end

      self.setViewSize(list_size)

      # Rejustify the x and y positions if we need to.
      xtmp = [xpos]
      ytmp = [ypos] 
      CDK.alignxy(TMPWINDOWTMP, xtmp, ytmp, box_width, box_height)
      xpos = xtmp[0]
      ypos = ytmp[0]

      # Make the scrolling window
      @win = Ncurses::WINDOW.new(box_height, box_width, ypos, xpos)

      # Is the scrolling window null?
      if @win.nil?
        return nil
      end

      # Turn the keypad on for the window
      @win.keypad(true)

      # Create the scrollbar window.
      if splace == CDK::RIGHT
        @scrollbar_win = @win.subwin(self.maxViewSize, 1, ypos, 
            xpos + box_width - @border_size - 1)
      elsif splace == CDK::LEFT
        @scrollbar_win = @win.subwin(self.maxViewSize, 1, ypos,
            self.SCREEN_XPOS(xpos))
      else
        @scrollbar_win = nil
      end

      # create the list window
      
      @list_win = @win.subwin(self.maxViewSize,
          box_width - (2 * @border_size) - scroll_adjust,
          ypos, SCREEN_XPOS(xpos) + (if splace == CDK::LEFT then 1 else 0 end))

      # Set the rest of the variables
      @screen = cdkscreen
      @parent = cdkscreen.window
      @shadow_win = 0
      @scrollbar_placement = splace
      @max_left_char = 0
      @left_char = 0
      @highlight = highlight
      # initExitType (scrollp);
      @accepts_focus = true
      @input_window = @win
      @shadow = shadow

      self.setCDKScrollPosition(0);

      # Create the scrolling list item list and needed variables.
      if self.createCDKScrollItemList(numbers, list, list_size) <= 0
        return 0
      end

      # Do we need to create a shadow?
      if shadow
        @shadow_win = Ncurses::WINDOW.new(box_height, box_width,
            ypos + 1, xpos + 1)
      end

      # Setup the key bindings.
      # for (x = 0; x < (int)SIZEOF (bindings); ++x)
      #   bindCDKObject (vSCROLL,
      #                  scrollp,
      #                  (chtype)bindings[x].from,
      #                  getcCDKBind,
      #                  (void *)(long)bindings[x].to);
      #
      #   registerCDKObject (cdkscreen, vSCROLL, scrollp);
      
      return self
    end

    # Put the cursor on the currently-selected item's row.
    def fixCursorPosition
      scrollbar_adj = if @scrollbar_placemtn == LEFT then 1 else 0 end
      ypos = self.SCREEN_YPOS(@current_item - @current_top)
      xpos = self.SCREEN_XPOS(0) + scrollbar_adj

      @input_window.wmove(ypos, xpos)
      @input_window.wrefresh
    end

    # This actually does all the 'real' work of managing the scrolling list.
    def activateCDKScroll(actions)
      # Draw the scrolling list
      self.drawCDKScroll(@box)

      if actions.nil? || actions.size == 0
        while true
          self.fixCursorPosition
          function_key = []
          input = self.obj.getch(function_key)

          # Inject the character into the widget.
          ret = self.injectCDKScroll(input)
          if @exit_type != :EARLY_EXIT
            return ret
          end
        end
      else
        # Inject each character one at a time.
        (0...actions.size).each do |i|
          ret = self.injectCDKScroll(actions[i])
          if @exit_type != :EARLY_EXIT
            return ret
          end
        end
      end

      # Set the exit type for the widget and return
      self.setExitType(0)
      return -1
    end

    # This injects a single character into the widget.
    def injectCDKScroll(input)
      pp_return = 1
      ret = -1
      complete = false

      # Set the exit type for the widget.
      self.setExitType(0)

      # Draw the scrolling list
      self.drawCDKScrollList(@box)

      #Check if there is a pre-process function to be called.
      # if (PreProcessFuncOf (widget) != 0)
      # {
      #   /* Call the pre-process function. */
      #   ppReturn = PreProcessFuncOf (widget) (vSCROLL,
      #                                         widget,
      #                                         PreProcessDataOf (widget),
      #                                         input);
      # }

      # Should we continue?
      if pp_return != 0
        # Check for a predefined key binding.
        if self.checkCDKObjectBind(:SCROLL, input) != 0
          self.checkEarlyExit
          complete = true
        else
          case input
          when Ncurses::KEY_UP
            #scroller_KEY_UP (widget)
          when Ncurses::KEY_DOWN
            #scroller_KEY_DOWN (widget)
          when Ncurses::KEY_RIGHT
            #scroller_KEY_RIGHT (widget)
          when Ncurses::KEY_LEFT
            #scroller_KEY_LEFT (widget)
          when Ncurses::KEY_PPAGE
            #scroller_KEY_PPAGE (widget)
          when Ncurses::KEY_NPAGE
            #scroller_KEY_NPAGE (widget)
          when Ncurses::KEY_HOME
            #scroller_KEY_HOME (widget)
          when Ncurses::KEY_END
            #scroller_KEY_END (widget)
          when '$'
            @left_char = @max_left_char
          when '|'
            @left_char = 0
          when Ncurses.KEY_ESC
            self.setExitType(input)
            complete = true
          when Ncurses.KEY_ERROR
            self.setExitType(input)
            complete = true
          when CDK_REFRESH
            @screen.erase
            @screen.refresh
          when Ncurses::KEY_TAB, Ncurses::KEY_ENTER
            self.setExitType(input)
            ret = @current_item
            complete = true
          else
          end
        end
        
        # Should we call a post-process?
        # if (!complete && (PostProcessFuncOf (widget) != 0))
        # {
        #   PostProcessFuncOf (widget) (vSCROLL,
        #                               widget,
        #                               PostProcessDataOf (widget),
        #                               input);
        # }
      end

      if !complete
        self.drawCDKScrollList(@box)
        self.setExitType(0)
      end

      self.fixCursorPosition
      # ResultOf (widget).valueInt = ret
      return ret != -1
    end

    # This allows the user to accelerate to a position in the scrolling list.
    def setCDKScrollPosition (item)
      # scroller_SetPosition (scrollp, item);
    end

    # Get/Set the current item number of the scroller.
    def getCDKScrollCurrentItem
      @current_item
    end

    def setCDKScrollCurrentItem(item)
      # scroller_SetPosition(widget, item);
    end

    def getCDKScrollCurrentTop
      return @current_top
    end

    def setCDKScrollCurrentTop(item)
      if item < 0
        item = 0
      elsif item > @max_top_item
        item = @max_top_item
      end
      @current_top = item

      # scroller_SetPosition(widget, item);
    end

    # This moves the scroll field to the given location.
    def moveCDKScroll(xplace, yplace, relative, refresh_flag)
      current_x = @win.getbegx
      current_y = @win.getbegy
      xpos = xplace
      ypos = yplace
      xdiff = 0
      ydiff = 0

      # If this is a relative move, then we will adjust where we want to
      # move to
      if relative
        xpos = @win.getbegx + xplace
        ypos = @win.gebegy + yplace
      end

      # Adjust the window if we need to.
      # alignxy (WindowOf (scrollp, &xpos, &pos, scrollp->boxWidth, scrollp->boxHeight);
      
      # Get the difference
      xdiff = current_x - xpos
      ydiff - current_y - ypos

      # Move the window to the new location.
      CDK.moveCursesWindow(@win, -xdiff, -ydiff)
      CDK.moveCursesWindow(@list_win, -xdiff, -ydiff)
      CDK.moveCursesWindow(@shadow_win, -xdiff, -ydiff)
      CDK.moveCursesWindow(@scrollbar_win, -xdiff, -ydiff)

      # Touch the windows so they 'move'.
      # refreshCDKWindow (WindowOf (scrollp));

      # Redraw the window, if they asked for it.
      if refresh_flag
        self.drawCDKScroll(@box)
      end
    end

    # This function draws the scrolling list widget.
    def drawCDKScroll(box)
      # Draw in the shadow if we need to.
      unless @shadow_win.nil?
        Draw.drawShadow(@shadow_win)
      end

      self.drawCdkTitle(@win)

      # Draw in the scrolling list items.
      self.drawCDKScrollList(box)
    end

    def drawCDKScrollCurrent
      # Rehighlight the current menu item.
      screen_pos = @item_pos[@current_item] - @left_char
      highlight = if self.HasFocusObj
                  then @highlight
                  else Ncurses::A_NORMAL
                  end

      Draw.writeChtypeAttrib(@list_win,
          if screen_pos >= 0 then screen_pos else 0 end,
          @current_high, @item[@current_item], highlight, CDK::HORIZONTAL,
          if screen_pos >= 0 then 0 else 1 - screen_pos end,
          @item_len[@current_item])
    end

    def maxViewSize
      # return scroller_MaxViewSize (scrollp)
    end

    # Set variables that depend upon the list-size
    def setViewSize(list_size)
      # scroller_SetViewSize (scrollp, listSize);
    end

    def drawCDKScrollList(box)
      # If the list is empty, don't draw anything.
      if @list_size > 0
        # Redraw the list
        (0...@view_size).each do |j|
          k = j + @current_top

          Draw.writeBlanks(@list_win, 0, j, CDK::HORIZONTAL, 0,
            @box_width - (2 * @border_size))

          # Draw the elements in the scrolling list.
          if k < @list_size
            screen_pos = @item_pos[k] - @left_char
            ypos = j

            # Write in the correct line.
            Draw.writeChtype(@list_win,
                if screen_pos >= 0 then screenPos else 1 end,
                ypos, @item[k], CDK::HORIZONTAL,
                if screen_pos >= 0 then 0 else 1 - screen_pos end,
                @item_len[k])
          end
        end

        self.drawCDKScrollCurrent

        # Determine where the toggle is supposed to be.
        unless @scrollbar_win.nil?
          @toggle_pos = (@current_item * @step).floor

          # Make sure the toggle button doesn't go out of bounds.
          
          if @toggle_pos >= @scrollbar_win.getmaxy
            @toggle_pos = @scrollbar_win.getmaxy - 1
          end

          # Draw the scrollbar
          @scrollbar_win.mvwvline(0, 0, Ncurses::ACS_CKBOARD,
              @scrollbar_win.getmaxy)
          @scrollbar_win.mvwvline(@toggle_pos, 0, ' '.ord | Ncurses::A_REVERSE,
              @toggle_size)
        end
      end

      # Box it if needed.
      if box
        Draw.drawObjBox(@win, self)
      end

      # Refresh the window
      @win.wrefresh
    end

    # This sets the background attribute of the widget.
    def setBKattrScroll(attrib)
      @win.wbkgd(attrib)
      @list_win.wbkgd(attrib)
      unless @scrollbar_win.nil?
        @scrollbar_win.wbkgd(attrib)
      end
    end

    # This function destroys
    def destroyCDKScroll
    end

    # This function erases the scrolling list from the screen.
    def eraseCDKScroll
      CDK.eraseCursesWindow(@win)
      CDK.eraseCursesWindow(@shadow_win)
    end

    def allocListArrays(old_size, new_size)
      result = true
      new_list = Array.new(new_size)
      new_len = Array.new(new_size)
      new_pos = Array.new(new_size)

      (0...old_size).each do |n|
        new_list[n] = @item[n]
        new_len[n] = @item_len[n]
        new_pos[n] = @item_pos[n]
      end

      @item = new_list
      @item_len = new_len
      @item_pos = new_pos

      return result
    end

    def allocListItem(which, work, used, number, value)
      if number > 0
        value = "%4d. %s" % [number, value]
      end

      item_len = []
      item_pos = []
      @item[which] = CDK.char2Chtype(value, item_len, item_pos)
      @item_len = item_len[0]
      @item_pos = item_pos[0]

      @item_pos[which] = CDK.char2Chtype(value, @item_len, @item_pos)
      return true
    end

    # This function creates the scrolling list information and sets up the
    # needed variables for the scrolling list to work correctly.
    def createCDKScrollItemList(numbers, list, list_size)
      status = 0
      if list_size > 0
        widest_item = 0
        x = 0
        have = 0
        temp = ''
        if allocListArrays(0, list_size)
          # Create the items in the scrolling list.
          status = 1
          (0...list_size).each do |x|
            number = if numbers then x + 1 else 0 end
            if !self.allocListItem(x, temp, have, number, list[x])
              status = 0
              break
            end

            widest_item = [@item_len[x], widest_item].max
          end

          if status
            self.updateViewWidth(widest_item);

            # Keep the boolean flag 'numbers'
            @numbers = numbers
          end
        end
      else
        status = 1  # null list is ok - for a while
      end

      return status
    end

    # This sets certain attributes of the scrolling list.
    def setCDKScroll(list, list_size, numbers, highlight, box)
      self.setCDKScrollItems(list, list_size, numbers)
      self.setCDKScrollHighlight(highlight)
      self.setCDKScrollBox(box)
    end

    # This sets the scrolling list items
    def setCDKScrollItems(list, list_size, numbers)
      if self.createCDKScrollItemList(numbers, list, list_size) <= 0
        return
      end

      # Clean up the display.
      (x...@view_size).each do |x|
        writeBlanks(@win, 1, x, CDK::HORIZONTAL, 0, @box_width - 2);
      end

      self.setViewSize(list_size)
      self.setCDKScrollPosition(0)
      @left_char = 0
    end

    def getCDKScrollItems(list)
      (0...@list_size).each do |x|
        list << CDK.chtype2Char(@item[x])
      end

      return @list_size
    end

    # This sets the highlight of the scrolling list.
    def setCDKScrollHighlight(highlight)
      @highlight = highlight
    end

    def getCDKScrollHighlight(highlight)
      return @highlight
    end

    # This sets the box attribute of the scrolling list.
    def setCDKScrollBox(box)
      @box = box
      @border_size = if box then 1 else 0 end
    end

    # Resequence the numbers after an insertion/deletion.
    def resequence
      if @numbers
        (0...@list_size).each do |j|
          target = @item[j]

          source = "%4d. %s" % [j + 1, ""]

          k = 0
          while k < source.size
            # handle deletions that change the length of number
            if source[k] == "." && target[k] != "."
              source = source[0...k] + source[k+1..-1]
            end

            target[k] &= Ncurses::A_ATTRIBUTES
            target[k] |= source[k].ord
          end
        end
      end
    end

    def insertListItem(item)
      # TODO revisit this
      true
    end

    # This adds a single item to a scrolling list, at the end of the list.
    def addCDKScrollItem(item)
      item_number = @list_size
      widest_item = self.WidestItem
      temp = ''
      have = 0

      if self.allocListArrays(@list_size, @list_size + 1) &&
          self.allocListItem(@item_number, temp, have,
          if @numbers then item_number + 1 else 0 end,
          item)
        # Determine the size of the widest item.
        widest_item = [@item_len[item_number], widest_item].max

        self.updateViewWidth(widest_item)
        self.setViewSize(@list_size + 1)
      end
    end

    # This adds a single item to a scrolling list before the current item
    def insertCDKScrollItem(item)
      widest_item = self.WidestItem
      temp = ''
      have = 0

      if self.allocListArrays(@list_size, @list_size + 1) &&
          self.insertListItem(@current_item) &&
          self.allocListItem(@current_item, temp, have,
          if @numbers then @current_item + 1 else 0 end,
          item)
        # Determine the size of the widest item.
        widest_item = [@item_len[@current_item], widest_item].max

        self.updateViewWidth(widest_item)
        self.setViewSize(@list_size + 1)
        self.resequence
      end
    end

    # This removes a single item from a scrolling list.
    def deleteCDKScrollItem(position)
      if position >= 0 && position < @list_size
        # Adjust the list
        @item = @item[0...position] + @item[position+1..-1]
        @item_len = @item[0...position] + @item[position+1..-1]
        @item_pos = @item[0...position] + @item[position+1..-1]

        self.setViewSize(@list_size - 1)

        if @list_size > 0
          self.resequence
        end

        if @list_size < self.maxViewSize
          @win.werase  # force the next redraw to be complete
        end

        # do this to update the view size, etc
        self.setCDKScrollPosition(@current_item)
      end
    end
    
    def focusCDKScroll
      self.drawCDKScrollCurrent
      @list_win.wrefresh
    end

    def unfocusCDKScroll
      self.drawCDKScrollCurrent
      @list_win.wrefresh
    end

    def AvailableWidth
      @box_width - (2 * @border_size)
    end

    def updateViewWidth(widest)
      @max_left_char = if @box_idth > widest then 0 else widest - self.AvailableWidth end
    end

    def WidestItem
      @max_left_char + self.AvailableWidth
    end

    def KEY_HOME
      @current_top = 0
      @current_item = 0
      @current_high = 0
    end

    def setCDKScrollPosition(item)
      self.SetPosition(item)
    end

    def SetPosition(item)
      if item <= 0
        self.KEY_HOME
      elsif item > @list_size - 1
        @current_top = @max_top_item
        @current_item = @list_size - 1
        @current_high = @view_size - 1
      elsif item >= @current_top && item < @current_top + @view_size
        @current_item = item
        @current_high = item - @current_top
      else
        @current_top = item - (@view_size - 1)
        @current_item = item
        @current_high = @view_size - 1
      end
    end

    def maxViewSize
      @box_height - (2 * @border_size + @title_lines)
    end

    def setViewSize(list_size)
      @view_size = self.maxViewSize
      @list_size = list_size
      @last_item = list_size - 1
      @max_top_item = list_size - view_size

      if list_size < @view_size
        @view_size = list_size
        @max_top_item = 0
      end

      if @list_size > 0 && self.maxViewSize > 0
        @step = self.maxViewSize / (1.0 * @list_size)
        @toggle_size = if @list_size > self.maxViewSize
                       then 1
                       else @step.ceil
                       end
      else
        @step = 1
        @toggle_size = 1
      end
    end
  end

  module Draw
    # This sets up a basic set of color pairs. These can be redefined if wanted
    def Draw.initCDKColor
      color = [Ncurses::COLOR_WHITE, Ncurses::COLOR_RED, Ncurses::COLOR_GREEN,
          Ncurses::COLOR_YELLOW, Ncurses::COLOR_BLUE, Ncurses::COLOR_MAGENTA,
          Ncurses::COLOR_CYAN, Ncurses::COLOR_BLACK]
      pair = 1

      if Ncurses.has_colors?
        # XXX: Only checks if terminal has colours not if colours are started
        Ncurses.start_color
        limit = if Ncurses.COLORS < 8 then Ncurses.COLORS else 8 end

        # Create the color pairs
        (0...limit).each do |fg|
          (0...limit).each do |bg|
            Ncurses.init_pair(pair, color[fg], color[bg])
            pair += 1
          end
        end
      end
    end

    # This prints out a box around a window with attributes
    def Draw.boxWindow(window, attr)
      tlx = 0
      tly = 0
      brx = window.getmaxx - 1
      bry = window.getmaxy - 1

      # Draw horizontal lines.
      window.mvwhline(tly, 0, Ncurses::ACS_HLINE | attr, window.getmaxx)
      window.mvwhline(bry, 0, Ncurses::ACS_HLINE | attr, window.getmaxx)

      # Draw horizontal lines.
      window.mvwvline(0, tlx, Ncurses::ACS_VLINE | attr, window.getmaxy)
      window.mvwvline(0, brx, Ncurses::ACS_VLINE | attr, window.getmaxy)

      # Draw in the corners.
      window.mvwaddch(tly, tlx, Ncurses::ACS_ULCORNER | attr)
      window.mvwaddch(tly, brx, Ncurses::ACS_URCORNER | attr)
      window.mvwaddch(bry, tlx, Ncurses::ACS_LLCORNER | attr)
      window.mvwaddch(bry, brx, Ncurses::ACS_LRCORNER | attr)
      window.wrefresh
    end

    # This draws a box with attributes and lets the user define each
    # element of the box
    def Draw.attrbox(win, tlc, trc, blc, brc, horz, vert, attr)
      x1 = 0
      y1 = 0
      y2 = win.getmaxy - 1
      x2 = win.getmaxx - 1
      count = 0

      # Draw horizontal lines
      if horz != 0
        win.mvwhline(y1, 0, horz | attr, win.getmaxx)
        win.mvwhline(y2, 0, horz | attr, win.getmaxx)
        count += 1
      end

      # Draw vertical lines
      if vert != 0
        win.mvwvline(0, x1, vert | attr, win.getmaxy)
        win.mvwvline(0, x2, vert | attr, win.getmaxy)
        count += 1
      end

      # Draw in the corners.
      if tlc != 0
        win.mvwaddch(y1, x1, tlc | attr)
        count += 1
      end
      if trc != 0
        win.mvwaddch(y1, x2, trc | attr)
        count += 1
      end
      if blc != 0
        win.mvwaddch(y2, x1, blc | attr)
        count += 1
      end
      if brc != 0
        win.mvwaddch(y2, x2, brc | attr)
        count += 1
      end
      if count != 0
        win.wrefresh
      end
    end

    # Draw a box around the given window using the object's defined
    # line-drawing characters
    def Draw.drawObjBox(win, object)
      Draw.attrbox(win,
          object.ULChar, object.URChar, object.LLChar, object.LRChar,
          object.HZChar, object.VTChar, object.BXAttr)
    end

    # This draws a line on the given window. (odd angle lines not working yet)
    def Draw.drawLine(window, startx, starty, endx, endy, line)
      xdiff = endx - startx
      ydiff = endy - starty
      x = 0
      y = 0

      # Determine if we're drawing a horizontal or vertical line.
      if ydiff == 0
        if xdiff > 0
          window.mvwhline(starty, startx, line, xdiff)
        end
      elsif xdiff == 0
        if ydiff > 0
          window.mvwvline(window, starty, startx, line, ydiff)
        end
      else
        # We need to determine the angle of the line.
        height = xdiff
        width = ydiff
        xratio = if height > width then 1 else width / height end
        yration = if width > height then width / height else 1 end
        xadj = 0
        yadj = 0

        # Set the vars
        x = startx
        y = starty
        while x!= endx && y != endy
          # Add the char to the window
          window.mvwaddch(y, x, line)

          # Make the x and y adjustments.
          if xadj != xratio
            x = if xdiff < 0 then x - 1 else x + 1 end
            xadj += 1
          else
            xadj = 0
          end
          if yadj != yratio
            y = if ydiff < 0 then y - 1 else y + 1 end
            yadj += 1
          else
            yadj = 0
          end
        end
      end
    end

    # This draws a shadow around a window.
    def Draw.drawShadow(shadow_win)
      unless shadow_win.nil?
        x_hi = shadow_win.getmaxx - 1
        y_hi = shadow_win.getmaxy - 1

        # Draw the line on the bottom.
        shadow_win.mvwhline(y_hi, 1, Ncurses::ACS_HLINE | Ncurses::A_DIM, x_hi)
        
        # Draw the line on teh right.
        shadow_win.mvwvline(0, x_hi, Ncurses::ACS_VLINE | Ncurses::A_DIM, y_hi)

        shadow_win.mvwaddch(0, x_hi, Ncurses::ACS_URCORNER | Ncurses::A_DIM)
        shadow_win.mvwaddch(y_hi, 0, Ncurses::ACS_LLCORNER | Ncurses::A_DIM)
        shadow_win.mvwaddch(y_hi, x_hi, Ncurses::ACS_LRCORNER | Ncurses::A_DIM)
        shadow_win.wrefresh
      end
    end

    # Write a string of blanks using writeChar()
    def Draw.writeBlanks(window, xpos, ypos, align, start, endn)
      if start < endn
        want = (endn - start) + 1000
        blanks = ''

        CDK.cleanChar(blanks, want - 1, ' ')
        Draw.writeChar(window, xpos, ypos, blanks, align, start, endn)
      end
    end

    # This writes out a char string with no attributes
    def Draw.writeChar(window, xpos, ypos, string, align, start, endn)
      Draw.writeCharAttrib(window, xpos, ypos, string, Ncurses::A_NORMAL,
          align, start, endn)
    end

    # This writes out a char string with attributes
    def Draw.writeCharAttrib(window, xpos, ypos, string, attr, align,
        start, endn)
      display = endn - start

      if align == CDK::HORIZONTAL
        # Draw the message on a horizontal axis
        display = [display, window.getmaxx - 1].min
        (0...display).each do |x|
          window.mvwaddch(ypos, xpos + x, string[x + start].ord | attr)
        end
      else
        # Draw the message on a vertical axis
        display = [display, window.getmaxy - 1].min
        (0...display).each do |x|
          window.mvwaddch(ypos + x, xpos, string[x + start].ord | attr)
        end
      end
    end

    # This writes out a chtype string
    def Draw.writeChtype (window, xpos, ypos, string, align, start, endn)
      Draw.writeChtypeAttrib(window, xpos, ypos, string, Ncurses::A_NORMAL,
          align, start, endn)
    end

    # This writes out a chtype string with the given attributes added.
    def Draw.writeChtypeAttrib(window, xpos, ypos, string, attr,
        align, start, endn)
      diff = endn - start
      display = 0
      x = 0
      if align == CDK::HORIZONTAL
        # Draw the message on a horizontal axis.
        display = [diff, window.getmaxx - xpos].min
        (0...display).each do |x|
          window.mvwaddch(ypos, xpos + x, string[x + start].ord | attr)
        end
      else
        # Draw the message on a vertical axis.
        display = [diff, window.getmaxy - ypos].min
        (0...display).each do |x|
          window.mvwaddch(ypos + x, xpos, string[x + start].ord | attr)
        end
      end
    end
  end

  module Display
    # Given a string, returns the equivalent display type
    def Display.char2DisplayType(string)
      table = {
        "CHAR"     => :CHAR,
        "HCHAR"    => :HCHAR,
        "INT"      => :INT,
        "HINT"     => :HINT,
        "UCHAR"    => :UCHAR,
        "LCHAR"    => :LCHAR,
        "UHCHAR"   => :UHCHAR,
        "LHCHAR"   => :LHCHAR,
        "MIXED"    => :MIXED,
        "HMIXED"   => :HMIXED,
        "UMIXED"   => :UMIXED,
        "LMIXED"   => :LMIXED,
        "UHMIXED"  => :UHMIXED,
        "LHMIXED"  => :LHMIXED,
        "VIEWONLY" => :VIEWONLY,
        0          => :INVALID 
      }
 
      if table.include?(string)
        table[string]
      else
        :INVALID
      end
    end

    # Tell if a display type is "hidden"
    def Display.isHiddenDisplayType(type)
      case type
      when :HCHAR, :HINT, :HMIXED, :LHCHAR, :LHMIXED, :UHCHAR, :UHMIXED
        true
      when :CHAR, :INT, :INVALID, :LCHAR, :LMIXED, :MIXED, :UCHAR, :UMIXED, :VIEWONLY
        false
      end
    end

    # Given a character input, check if it is allowed by the display type
    # and return the character to apply to the display, or ERR if not
    def Display.filterByDisplayType(type, input)
      result = input
      if !CDK.isChar(input)
        result = Ncurses::ERR
      elsif [:INT, :HINT].include?(type) && !CDK.digit?(result.chr)
        result = Ncurses::ERR
      elsif [:CHAR, :UCHAR, :LCHAR, :UHCHAR, :LHCHAR].include?(type) && CDK.digit?(result.chr)
        result = Ncurses::ERR
      elsif type == :VIEWONLY
        result = ERR
      elsif [:UCHAR, :UHCHAR, :UMIXED, :UHMIXED].include?(type) && CDK.alpha?(result.chr)
        result = result.chr.upcase.ord
      elsif [:LCHAR, :LHCHAR, :LMIXED, :LHMIXED].include?(type) && CDK.alpha?(result.chr)
        result = result.chr.downcase.ord
      end

      return result
    end
  end
end
