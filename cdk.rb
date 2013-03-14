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
require 'scanf'  # For the SCALE module

module CDK
  # some useful global values

  def CDK.CTRL(c)
    c.ord & 0x1f
  end

  VERSION_MAJOR = 0
  VERSION_MINOR = 2
  VERSION_PATCH = 0
  
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

  REFRESH = CDK.CTRL('L')
  PASTE = CDK.CTRL('V')
  COPY = CDK.CTRL('Y')
  ERASE = CDK.CTRL('U')
  CUT = CDK.CTRL('X')
  BEGOFLINE = CDK.CTRL('A')
  ENDOFLINE = CDK.CTRL('E')
  BACKCHAR = CDK.CTRL('B')
  FORCHAR = CDK.CTRL('F')
  TRANSPOSE = CDK.CTRL('T')
  NEXT = CDK.CTRL('N')
  PREV = CDK.CTRL('P')
  DELETE = "\177".ord
  KEY_ESC = "\033".ord
  KEY_RETURN = "\012".ord
  KEY_TAB = "\t".ord

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
    lines = fd.readlines.map do |line|
      if line.size > 0 && line[-1] == "\n"
        line[0...-1]
      else
        line
      end
    end
    array.concat(lines)
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

    result = if string.nil? then '' else string end
    base_len = result.size
    tmpattr = oldattr & Ncurses::A_ATTRIBUTES

    newattr &= Ncurses::A_ATTRIBUTES
    if tmpattr != newattr
      while tmpattr != newattr
        found = false
        table.keys.each do |key|
          if (table[key] & tmpattr) != (table[key] & newattr)
            found = true
            result << CDK::L_MARKER
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
          if (tmpattr & Ncurses::A_COLOR) != (newattr & Ncurses::A_COLOR)
            oldpair = Ncurses.PAIR_NUMBER(tmpattr)
            newpair = Ncurses.PAIR_NUMBER(newattr)
            if !found
              found = true
              result << CDK::L_MARKER
            end
            if newpair.zero?
              result << '!'
              result << oldpair.to_s
            else
              result << '/'
              result << newpair.to_s
            end
            tmpattr &= ~(Ncurses::A_COLOR)
            newattr &= ~(Ncurses::A_COLOR)
          end
        end

        if found
          result << CDK::R_MARKER
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

      # The original code makes two passes since it has to pre-allocate space but
      # we should be able to make do with one since we can dynamically size it
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
            result << (string[x].ord | Ncurses::A_BOLD)
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
                last_char = Ncurses::ACS_LLCORNER
              when 'U'
                last_char = Ncurses::ACS_ULCORNER
              when 'H'
                last_char = Ncurses::ACS_HLINE
              when 'V'
                last_char = Ncurses::ACS_VLINE
              when 'P'
                last_char = Ncurses::ACS_PLUS
              end
            when 'R'
              case string[from + 1]
              when 'L'
                last_char = Ncurses::ACS_LRCORNER
              when 'U'
                last_char = Ncurses::ACS_URCORNER
              end
            when 'T'
              case string[from + 1]
              when 'T'
                last_char = Ncurses::ACS_TTEE
              when 'R'
                last_char = Ncurses::ACS_RTEE
              when 'L'
                last_char = Ncurses::ACS_LTEE
              when 'B'
                last_char = Ncurses::ACS_BTEE
              end
            when 'A'
              case string[from + 1]
              when 'L'
                last_char = Ncurses::ACS_LARROW
              when 'R'
                last_char = Ncurses::ACS_RARROW
              when 'U'
                last_char = Ncurses::ACS_UARROW
              when 'D'
                last_char = Ncurses::ACS_DARROW
              end
            else
              case [string[from + 1], string[from + 2]]
              when ['D', 'I']
                last_char = Ncurses::ACS_DIAMOND
              when ['C', 'B']
                last_char = Ncurses::ACS_CKBOARD
              when ['D', 'G']
                last_char = Ncurses::ACS_DEGREE
              when ['P', 'M']
                last_char = Ncurses::ACS_PLMINUS
              when ['B', 'U']
                last_char = Ncurses::ACS_BULLET
              when ['S', '1']
                last_char = Ncurses::ACS_S1
              when ['S', '9']
                last_char = Ncurses::ACS_S9
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
                  from += 1
                end
              end
            end
            (0...adjust).each do |x|
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
            attrib &= ~(mask[0])
          end
        end
        from += 1
      end

      if result.size == 0
        result << attrib
      end
      to[0] = used
    else
      result = []
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

  def CDK.CharOf(chtype)
    (chtype.ord & 255).chr
  end

  # This returns a string from a chtype array
  # Formatting codes are omitted.
  def CDK.chtype2Char(string)
    newstring = ''
    
    unless string.nil?
      string.each do |char|
        newstring << CDK.CharOf(char)
      end
    end

    return newstring
  end

  # This returns a string from a chtype array
  # Formatting codes are embedded
  def CDK.chtype2String(string)
    newstring = ''
    unless string.nil?
      need = 0
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
      next if filename == '.'
      list << filename
    end

    list.sort!
    return list.size
  end

  # This looks for a subset of a word in the given list
  def CDK.searchList(list, list_size, pattern)
    index = -1

    if pattern.size > 0
      (0...list_size).each do |x|
        len = [list[x].size, pattern.size].min
        ret = (list[x][0...len] <=> pattern)

        # If 'ret' is less than 0 then the current word is alphabetically
        # less than the provided word.  At this point we will set the index
        # to the current position.  If 'ret' is greater than 0, then the
        # current word is alphabetically greater than the given word. We
        # should return with index, which might contain the last best match.
        # If they are equal then we've found it.
        if ret < 0
          index = ret
        else
          if ret == 0
            index = x
          end
          break
        end
      end
    end
    return index
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
    if window.mvwin(ypos[0], xpos[0]) != Ncurses::ERR
      xpos[0] += xdiff
      ypos[0] += ydiff
      window.werase
      window.mvwin(ypos[0], xpos[0])
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

  def CDK.KEY_F(n)
    264 + n
  end

  def CDK.Version
    return "%d.%d - %d" %
        [CDK::VERSION_MAJOR, CDK::VERSION_MINOR, CDK::VERSION_PATCH]
  end

  def CDK.getString(screen, title, label, init_value)
    # Create the widget.
    widget = CDK::ENTRY.new(screen, CDK::CENTER, CDK::CENTER, title, label,
        Ncurses::A_NORMAL, '.', :MIXED, 40, 0, 5000, true, false)

    # Set the default value.
    widget.setValue(init_value)

    # Get the string.
    value = widget.activate([])

    # Make sure they exited normally.
    if widget.exit_type != :NORMAL
      widget.destroy
      return nil
    end

    # Return a copy of the string typed in.
    value = entry.getValue.clone
    widget.destroy
    return value
  end

  # This allows a person to select a file.
  def CDK.selectFile(screen, title)
    # Create the file selector.
    fselect = CDK::FSELECT.new(screen, CDK::CENTER, CDK::CENTER, -4, -20,
        title, 'File: ', Ncurses::A_NORMAL, '_', Ncurses::A_REVERSE,
        '</5>', '</48>', '</N>', '</N>', true, false)

    # Let the user play.
    filename = fselect.activate([])

    # Check the way the user exited the selector.
    if fselect.exit_type != :NORMAL
      fselect.destroy
      screen.refresh
      return nil
    end

    # Otherwise...
    fselect.destroy
    screen.refresh
    return filename
  end

  # This returns a selected value in a list
  def CDK.getListindex(screen, title, list, list_size, numbers)
    selected = -1
    height = 10
    width = -1
    len = 0

    # Determine the height of the list.
    if list_size < 10
      height = list_size + if title.size == 0 then 2 else 3 end
    end

    # Determine the width of the list.
    list.each do |item|
      width = [width, item.size + 10].max
    end

    width = [width, title.size].max
    width += 5

    # Create the scrolling list.
    scrollp = CDK::SCROLL.new(screen, CDK::CENTER, CDK::CENTER, CDK::RIGHT,
        height, width, title, list, list_size, numbers, Ncurses::A_REVERSE,
        true, false)

    # Check if we made the lsit.
    if scrollp.nil?
      screen.refresh
      return -1
    end

    # Let the user play.
    selected = scrollp.activate([])

    # Check how they exited.
    if scrollp.exit_type != :NORMAL
      selected = -1
    end

    # Clean up.
    scrollp.destroy
    screen.refresh
    return selected
  end

  # This allows the user to view information.
  def CDK.viewInfo(screen, title, info, count, buttons, button_count,
      interpret)
    selected = -1

    # Create the file viewer to view the file selected.
    viewer = CDK::VIEWER.new(screen, CDK::CENTER, CDK::CENTER, -6, -16,
        buttons, button_count, Ncurses::A_REVERSE, true, true)

    # Set up the viewer title, and the contents to the widget.
    viewer.set(title, info, count, Ncurses::A_REVERSE, interpret, true, true)

    # Activate the viewer widget.
    selected = viewer.activate([])

    # Make sure they exited normally.
    if viewer.exit_type != :NORMAL
      viewer.destroy
      return -1
    end

    # Clean up and return the button index selected
    viewer.destroy
    return selected
  end

  # This allows the user to view a file.
  def CDK.viewFile(screen, title, filename, buttons, button_count)
    info = []
    result = 0

    # Open the file and read the contents.
    lines = CDK.readFile(filename, info)

    # If we couldn't read the file, return an error.
    if lines == -1
      result = lines
    else
      result = CDK.viewInfo(screen, title, info, lines, buttons,
          button_count, true)
    end
    return result
  end

  class CDKOBJS
    attr_accessor :screen_index, :screen, :has_focus, :is_visible, :box
    attr_accessor :ULChar, :URChar, :LLChar, :LRChar, :HZChar, :VTChar, :BXAttr
    attr_reader :binding_list, :accepts_focus, :exit_type, :border_size

    @@g_paste_buffer = ''

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

      @accepts_focus = false

      # Bound functions
      @binding_list = {}
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

    def draw(a)
    end

    def erase
    end

    def move(a,b,c,d)
    end

    def inject(a)
    end

    def setBox(box)
      @box = box
      @border_size = if @box then 1 else 0 end
    end

    def getBox
      return @box
    end

    def focus
    end

    def unfocus
    end

    def saveData
    end

    def refreshData
    end

    def destroy
    end

    # Set the object's upper-left-corner line-drawing character.
    def setULchar(ch)
      @ULChar = ch
    end

    # Set the object's upper-right-corner line-drawing character.
    def setURchar(ch)
      @URChar = ch
    end

    # Set the object's lower-left-corner line-drawing character.
    def setLLchar(ch)
      @LLChar = ch
    end

    # Set the object's upper-right-corner line-drawing character.
    def setLRchar(ch)
      @LRChar = ch
    end

    # Set the object's horizontal line-drawing character
    def setHZchar(ch)
      @HZChar = ch
    end

    # Set the object's vertical line-drawing character
    def setVTchar(ch)
      @VTChar = ch
    end

    # Set the object's box-attributes.
    def setBXattr(ch)
      @BXAttr = ch
    end

    # This sets the background color of the widget.
    def setBackgroundColor(color)
      return if color.nil? || color == ''

      junk1 = []
      junk2 = []
      
      # Convert the value of the environment variable to a chtype
      holder = CDK.char2Chtype(color, junk1, junk2)

      # Set the widget's background color
      self.SetBackAttrObj(holder[0])
    end

    # Set the widget's title.
    def setTitle (title, box_width)
      if !title.nil? 
        temp = title.split("\n")
        @title_lines = temp.size
        
        if box_width >= 0
          max_width = 0
          temp.each do |line|
            len = []
            align = []
            holder = CDK.char2Chtype(line, len, align)
            max_width = [len[0], max_width].max
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
          @title_pos << CDK.justifyString(title_width, len_x[0], pos_x[0])
        end
      end

      return box_width
    end

    # Draw the widget's title
    def drawTitle(win)
      (0...@title_lines).each do |x|
        Draw.writeChtype(@win, @title_pos[x] + @border_size,
            x + @border_size, @title[x], CDK::HORIZONTAL, 0,
            @title_len[x])
      end
    end

    # Remove storage for the widget's title.
    def cleanTitle
      @title_lines = ''
    end

    # Set data for preprocessing
    def setPreProcess (fn, data)
      @pre_process_func = fn
      @pre_process_data = data
    end

    # Set data for postprocessing
    def setPostProcess (fn, data)
      @post_process_func = fn
      @post_process_data = data
    end
    
    # Set the object's exit-type based on the input.
    # The .exitType field should have been part of the CDKOBJS struct, but it
    # is used too pervasively in older applications to move (yet).
    def setExitType(ch)
      case ch
      when Ncurses::ERR
        @exit_type = :ERROR
      when CDK::KEY_ESC
        @exit_type = :ESCAPE_HIT
      when CDK::KEY_TAB, Ncurses::KEY_ENTER, CDK::KEY_RETURN
        @exit_type = :NORMAL
      when 0
        @exit_type = :EARLY_EXIT
      end
    end

    def validCDKObject
      result = false
      if CDK::ALL_OBJECTS.include?(self)
        result = self.validObjType(self.object_type)
      end
      return result
    end

    def getc
      cdktype = self.object_type
      # CDKOBJS *test = bindableObject (&cdktype, obj);
      test = self.bindableObject(cdktype)
      result = @input_window.wgetch

      #if (result >= 0
      #    && test != 0
      #    && (unsigned)result < test->bindingCount
      #    && test->bindingList[result].bindFunction == getcCDKBind)
      # [...]
      # else if (test == 0
      #          || (unsigned)result >= test->bindingCount
      #          || test->bindingList[result].bindFunction == 0)
      if result >= 0 && !(test.nil?) && test.binding_list.include?(result) &&
          test.binding_list[result][0] == :getc
        result = test.binding_list[result][1]
      elsif test.nil? || !(test.binding_list.include?(result)) ||
          test.binding_list[result][0].nil?
        case result
        when "\r".ord, "\n".ord
          result = Ncurses::KEY_ENTER
        when "\t".ord
          result = KEY_TAB
        when CDK::DELETE
          result = Ncurses::KEY_DC
        when "\b".ord
          result = Ncurses::KEY_BACKSPACE
        when CDK::BEGOFLINE
          result = Ncurses::KEY_HOME
        when CDK::ENDOFLINE
          result = Ncurses::KEY_END
        when CDK::FORCHAR
          result = Ncurses::KEY_RIGHT
        when CDK::BACKCHAR
          result = Ncurses::KEY_LEFT
        when CDK::NEXT
          result = Ncurses::KEY_TAB
        when CDK::PREV
          result = Ncurses::KEY_BTAB
        end
      end

      return result
    end

    def getch(function_key)
      key = self.getc
      function_key << (key >= Ncurses::KEY_MIN && key <= Ncurses::KEY_MAX)
      return key
    end

    def bindableObject(cdktype)
      if cdktype != self.object_type
        return nil
      elsif [:FSELECT, :ALPHALIST].include?(self.object_type)
        return @entry_field
      else
        return self
      end
    end

    def bind(type, key, function, data)
      obj = self.bindableObject(type)
      if key.ord < Ncurses::KEY_MAX && !(obj.nil?)
        if key.ord != 0
          obj.binding_list[key.ord] = [function, data]
        end
      end
    end

    def unbind(type, key)
      obj = self.bindableObject(type)
      unless obj.nil?
        obj.binding_list.delete(key)
      end
    end

    def cleanBindings(type)
      obj = self.bindableObject(type)
      if !(obj.nil?) && !(obj.binding_list.nil?)
        obj.binding_list.clear
      end
    end

    # This checks to see if the binding for the key exists:
    # If it does then it runs the command and returns its value, normally true
    # If it doesn't it returns a false.  This way we can 'overwrite' coded
    # bindings.
    def checkBind(type, key)
      obj = self.bindableObject(type)
      if !(obj.nil?) && obj.binding_list.include?(key)
        function = obj.binding_list[key][0]
        data = obj.binding_list[key][1]

        if function == :getc
          return data
        else
          return function.call(type, obj, data, key)
        end
      end
      return false
    end

    # This checks to see if the binding for the key exists.
    def isBind(type, key)
      result = false
      obj = self.bindableObject(type)
      unless obj.nil?
        result = obj.binding_list.include?(key)
      end

      return result
    end

    # This allows the user to use the cursor keys to adjust the
    # postion of the widget.
    def position(win)
      parent = @screen.window
      orig_x = win.getbegx
      orig_y = win.getbegy
      beg_x = parent.getbegx
      beg_y = parent.getbegy
      end_x = beg_x + @screen.window.getmaxx
      end_y = beg_y + @screen.window.getmaxy

      # Let them move the widget around until they hit return.
      while !([CDK::KEY_RETURN, Ncurses::KEY_ENTER].include?(
          key = self.getch([])))
        case key
        when Ncurses::KEY_UP, '8'.ord
          if win.getbegy > beg_y
            self.move(0, -1, true, true)
          else
            CDK.Beep
          end
        when Ncurses::KEY_DOWN, '2'.ord
          if (win.getbegy + win.getmaxy) < end_y
            self.move(0, 1, true, true)
          else
            CDK.Beep
          end
        when Ncurses::KEY_LEFT, '4'.ord
          if win.getbegx > beg_x
            self.move(-1, 0, true, true)
          else
            CDK.Beep
          end
        when Ncurses::KEY_RIGHT, '6'.ord
          if (win.getbegx + win.getmaxx) < end_x
            self.move(1, 0, true, true)
          else
            CDK.Beep
          end
        when '7'.ord
          if win.getbegy > beg_y && win.getbegx > beg_x
            self.move(-1, -1, true, true)
          else
            CDK.Beep
          end
        when '9'.ord
          if (win.getbegx + win.getmaxx) < end_x && win.getbegy > beg_y
            self.move(1, -1, true, true)
          else
            CDK.Beep
          end
        when '1'.ord
          if win.getbegx > beg_x && (win.getbegy + win.getmaxy) < end_y
            self.move(-1, 1, true, true)
          else
            CDK.Beep
          end
        when '3'.ord
          if (win.getbegx + win.getmaxx) < end_x &&
              (win.getbegy + win.getmaxy) < end_y
            self.move(1, 1, true, true)
          else
            CDK.Beep
          end
        when '5'.ord
          self.move(CDK::CENTER, CDK::CENTER, false, true)
        when 't'.ord
          self.move(win.getbegx, CDK::TOP, false, true)
        when 'b'.ord
          self.move(win.getbegx, CDK::BOTTOM, false, true)
        when 'l'.ord
          self.move(CDK::LEFT, win.getbegy, false, true)
        when 'r'.ord
          self.move(CDK::RIGHT, win.getbegy, false, true)
        when 'c'.ord
          self.move(CDK::CENTER, win.getbegy, false, true)
        when 'C'.ord
          self.move(win.getbegx, CDK::CENTER, false, true)
        when CDK::REFRESH
          @screen.erase
          @screen.refresh
        when CDK::KEY_ESC
          self.move(orig_x, orig_y, false, true)
        else
          CDK.Beep
        end
      end
    end
  end

  class SCREEN
    attr_accessor :object_focus, :object_count, :object_limit, :object, :window
    attr_accessor :exit_status

    NOEXIT = 0
    EXITOK = 1
    EXITCANCEL = 2

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
      @object_focus = 0
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
    def self.unregister(cdktype, object)
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
              Traverse.setCDKFocusNext(screen)
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
      @object[number] = obj
    end

    def validIndex(n)
      n >= 0 && n < @object_count
    end

    def swapCDKIndices(n1, n2)
      if n1 != n2 && self.validIndex(n1) && self.validIndex(n2)
        o1 = @object[n1]
        o2 = @object[n2]
        self.setScreenIndex(n1, o2)
        self.setScreenIndex(n2, o1)

        if @object_focus == n1
          @object_focus = n2
        elsif @object_focus == n2
          @object_focus = n1
        end
      end
    end

    # This 'brings' a CDK object to the top of the stack.
    def self.raiseCDKObject(cdktype, object)
      if object.validObjType(cdktype)
        screen = object.screen
        screen.swapCDKIndices(object.screen_index, screen.object_count - 1)
      end
    end

    # This 'lowers' an object.
    def self.lowerCDKObject(cdktype, object)
      if object.validObjType(cdktype)
        object.screen.swapCDKIndices(object.screen_index, 0)
      end
    end

    # This pops up a message.
    def popupLabel(mesg, count)
      #Create the label.
      popup = CDK::LABEL.new(self, CENTER, CENTER, mesg, count, true, false)

      old_state = Ncurses.curs_set(0)
      #Draw it on the screen
      popup.draw(true)

      # Wait for some input.
      popup.win.keypad(true)
      popup.getch([])

      # Kill it.
      popup.destroy

      # Clean the screen.
      Ncurses.curs_set(old_state)
      self.erase
      self.refresh
    end

    # This pops up a message
    def popupLabelAttrib(mesg, count, attrib)
      # Create the label.
      popup = CDK::LABEL.new(self, CENTER, CENTER, mesg, count, true, false)
      popup.setBackgroundAttrib

      old_state = Ncurses.curs_set(0)
      # Draw it on the screen)
      popup.draw(true)

      # Wait for some input
      popup.win.keypad(true)
      popup.getch([])

      # Kill it.
      popup.destroy

      # Clean the screen.
      Ncurses.curs_set(old_state)
      screen.erase
      screen.refresh
    end

    # This pops up a dialog box.
    def popupDialog(mesg, mesg_count, buttons, button_count)
      # Create the dialog box.
      popup = CDK::DIALOG.new(self, CDK::CENTER, CDK::CENTER,
          mesg, mesg_count, buttons, button_count, Ncurses::A_REVERSE,
          true, true, false)

      # Activate the dialog box
      popup.draw(true)

      # Get the choice
      choice = popup.activate('')

      # Destroy the dialog box
      popup.destroy

      # Clean the screen.
      self.erase
      self.refresh

      return choice
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
        if obj.validObjType(obj.object_type)
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
          obj.destroy
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

  class SCROLLER < CDK::CDKOBJS
    def initialize
      super()
    end

    def KEY_UP
      if @list_size > 0
        if @current_item > 0
          if @current_high == 0
            if @current_top != 0
              @current_top -= 1
              @current_item -= 1
            else
              CDK.Beep
            end
          else
            @current_item -= 1
            @current_high -= 1
          end
        else
          CDK.Beep
        end
      else
        CDK.Beep
      end
    end

    def KEY_DOWN
      if @list_size > 0
        if @current_item < @list_size - 1
          if @current_high == @view_size - 1
            if @current_top < @max_top_item
              @current_top += 1
              @current_item += 1
            else
              CDK.Beep
            end
          else
            @current_item += 1
            @current_high += 1
          end
        else
          CDK.Beep
        end
      else
        CDK.Beep
      end
    end

    def KEY_LEFT
      if @list_size > 0
        if @left_char == 0
          CDK.Beep
        else
          @left_char -= 1
        end
      else
        CDK.Beep
      end
    end

    def KEY_RIGHT
      if @list_size > 0
        if @left_char >= @max_left_char
          CDK.Beep
        else
          @left_char += 1
        end
      else
        CDK.Beep
      end
    end

    def KEY_PPAGE
      if @list_size > 0
        if @current_top > 0
          if @current_top >= @view_size - 1
            @current_top -= @view_size - 1
            @current_item -= @view_size - 1
          else
            self.KEY_HOME
          end
        else
          CDK.Beep
        end
      else
        CDK.Beep
      end
    end

    def KEY_NPAGE
      if @list_size > 0
        if @current_top < @max_top_item
          if @current_top + @view_size - 1 <= @max_top_item
            @current_top += @view_size - 1
            @current_item += @view_size - 1
          else
            @current_top = @max_top_item
            @current_item = @last_item
            @current_high = @view_size - 1
          end
        else
          CDK.Beep
        end
      else
        CDK.Beep
      end
    end

    def KEY_HOME
      @current_top = 0
      @current_item = 0
      @current_high = 0
    end

    def KEY_END
      if @max_top_item == -1
        @current_top = 0
        @current_item = @last_item - 1
      else
        @current_top = @max_top_item
        @current_item = @last_item
      end
      @current_high = @view_size - 1
    end

    def maxViewSize
      return @box_height - (2 * @border_size + @title_lines)
    end

    # Set variables that depend upon the list_size
    def setViewSize(list_size)
      @view_size = self.maxViewSize
      @list_size = list_size
      @last_item = list_size - 1
      @max_top_item = list_size - @view_size

      if list_size < @view_size
        @view_size = list_size
        @max_top_item = 0
      end

      if @list_size > 0 && self.maxViewSize > 0
        @step = 1.0 * self.maxViewSize / @list_size
        @toggle_size = if @list_size > self.maxViewSize
                       then 1
                       else @step.ceil
                       end
      else
        @step = 1
        @toggle_size = 1
      end
    end

    def setPosition(item)
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

    # Get/Set the current item number of the scroller.
    def getCurrentItem
      @current_item
    end

    def setCurrentItem(item)
      self.setPosition(item);
    end
  end

  class SCROLL < CDK::SCROLLER
    attr_reader :item, :list_size, :current_item, :highlight

    def initialize (cdkscreen, xplace, yplace, splace, height, width, title,
        list, list_size, numbers, highlight, box, shadow)
      super()
      parent_width = cdkscreen.window.getmaxx
      parent_height = cdkscreen.window.getmaxy
      box_width = width
      box_height = height
      xpos = xplace
      ypos = yplace
      scroll_adjust = 0
      bindings = {
        CDK::BACKCHAR => Ncurses::KEY_PPAGE,
        CDK::FORCHAR  => Ncurses::KEY_NPAGE,
        'g'           => Ncurses::KEY_HOME,
        '1'           => Ncurses::KEY_HOME,
        'G'           => Ncurses::KEY_END,
        '<'           => Ncurses::KEY_HOME,
        '>'           => Ncurses::KEY_END
      }

      self.setBox(box)

      # If the height is a negative value, the height will be ROWS-height,
      # otherwise the height will be the given height
      box_height = CDK.setWidgetDimension(parent_height, height, 0)

      # If the width is a negative value, the width will be COLS-width,
      # otherwise the width will be the given width
      box_width = CDK.setWidgetDimension(parent_width, width, 0)
    
      box_width = self.setTitle(title, box_width)

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
      @box_width = if box_width > parent_width 
                   then parent_width - scroll_adjust 
                   else box_width 
                   end
      @box_height = if box_height > parent_height
                    then parent_height
                    else box_height
                    end

      self.setViewSize(list_size)

      # Rejustify the x and y positions if we need to.
      xtmp = [xpos]
      ytmp = [ypos] 
      CDK.alignxy(cdkscreen.window, xtmp, ytmp, @box_width, @box_height)
      xpos = xtmp[0]
      ypos = ytmp[0]

      # Make the scrolling window
      @win = Ncurses::WINDOW.new(@box_height, @box_width, ypos, xpos)

      # Is the scrolling window null?
      if @win.nil?
        return nil
      end

      # Turn the keypad on for the window
      @win.keypad(true)

      # Create the scrollbar window.
      if splace == CDK::RIGHT
        @scrollbar_win = @win.subwin(self.maxViewSize, 1,
            self.SCREEN_YPOS(ypos), xpos + box_width - @border_size - 1)
      elsif splace == CDK::LEFT
        @scrollbar_win = @win.subwin(self.maxViewSize, 1,
            self.SCREEN_YPOS(ypos), self.SCREEN_XPOS(xpos))
      else
        @scrollbar_win = nil
      end

      # create the list window
      @list_win = @win.subwin(self.maxViewSize,
          box_width - (2 * @border_size) - scroll_adjust,
          self.SCREEN_YPOS(ypos),
          self.SCREEN_XPOS(xpos) + (if splace == CDK::LEFT then 1 else 0 end))

      # Set the rest of the variables
      @screen = cdkscreen
      @parent = cdkscreen.window
      @shadow_win = nil
      @scrollbar_placement = splace
      @max_left_char = 0
      @left_char = 0
      @highlight = highlight
      # initExitType (scrollp);
      @accepts_focus = true
      @input_window = @win
      @shadow = shadow

      self.setPosition(0);

      # Create the scrolling list item list and needed variables.
      if self.createItemList(numbers, list, list_size) <= 0
        return nil
      end

      # Do we need to create a shadow?
      if shadow
        @shadow_win = Ncurses::WINDOW.new(@box_height, box_width,
            ypos + 1, xpos + 1)
      end

      # Set up the key bindings.
      bindings.each do |from, to|
        #self.bind(:SCROLL, from, getc_lambda, to)
        self.bind(:SCROLL, from, :getc, to)
      end

      cdkscreen.register(:SCROLL, self);
      
      return self
    end

    def object_type
      :SCROLL
    end

    def position
      super(@win)
    end

    # Put the cursor on the currently-selected item's row.
    def fixCursorPosition
      scrollbar_adj = if @scrollbar_placement == LEFT then 1 else 0 end
      ypos = self.SCREEN_YPOS(@current_item - @current_top)
      xpos = self.SCREEN_XPOS(0) + scrollbar_adj

      @input_window.wmove(ypos, xpos)
      @input_window.wrefresh
    end

    # This actually does all the 'real' work of managing the scrolling list.
    def activate(actions)
      # Draw the scrolling list
      self.draw(@box)

      if actions.nil? || actions.size == 0
        while true
          self.fixCursorPosition
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

      # Set the exit type for the widget and return
      self.setExitType(0)
      return -1
    end

    # This injects a single character into the widget.
    def inject(input)
      pp_return = 1
      ret = -1
      complete = false

      # Set the exit type for the widget.
      self.setExitType(0)

      # Draw the scrolling list
      self.drawList(@box)

      #Check if there is a pre-process function to be called.
      unless @pre_process_func.nil?
        pp_return = @pre_process_func.call(:SCROLL, self,
            @pre_process_data, input)
      end

      # Should we continue?
      if pp_return != 0
        # Check for a predefined key binding.
        if self.checkBind(:SCROLL, input) != false
          #self.checkEarlyExit
          complete = true
        else
          case input
          when Ncurses::KEY_UP
            self.KEY_UP
          when Ncurses::KEY_DOWN
            self.KEY_DOWN
          when Ncurses::KEY_RIGHT
            self.KEY_RIGHT
          when Ncurses::KEY_LEFT
            self.KEY_LEFT
          when Ncurses::KEY_PPAGE
            self.KEY_PPAGE
          when Ncurses::KEY_NPAGE
            self.KEY_NPAGE
          when Ncurses::KEY_HOME
            self.KEY_HOME
          when Ncurses::KEY_END
            self.KEY_END
          when '$'
            @left_char = @max_left_char
          when '|'
            @left_char = 0
          when CDK::KEY_ESC
            self.setExitType(input)
            complete = true
          when Ncurses::ERR
            self.setExitType(input)
            complete = true
          when CDK::REFRESH
            @screen.erase
            @screen.refresh
          when CDK::KEY_TAB, Ncurses::KEY_ENTER, CDK::KEY_RETURN
            self.setExitType(input)
            ret = @current_item
            complete = true
          end
        end

        if !complete && !(@post_process_func.nil?)
          @post_process_func.call(:SCROLL, self, @post_process_data, input)
        end
      end

      if !complete
        self.drawList(@box)
        self.setExitType(0)
      end

      self.fixCursorPosition
      @result_data = ret

      #return ret != -1
      return ret
    end

    def getCurrentTop
      return @current_top
    end

    def setCurrentTop(item)
      if item < 0
        item = 0
      elsif item > @max_top_item
        item = @max_top_item
      end
      @current_top = item

      self.setPosition(item);
    end

    # This moves the scroll field to the given location.
    def move(xplace, yplace, relative, refresh_flag)
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
        ypos = @win.getbegy + yplace
      end

      # Adjust the window if we need to.
      xtmp = [xpos]
      ytmp = [ypos]
      CDK.alignxy(@screen.window, xpos, ypos, @box_width, @box_height)
      xpos = xtmp[0]
      ypos = ytmp[0]
      
      # Get the difference
      xdiff = current_x - xpos
      ydiff - current_y - ypos

      # Move the window to the new location.
      CDK.moveCursesWindow(@win, -xdiff, -ydiff)
      CDK.moveCursesWindow(@list_win, -xdiff, -ydiff)
      CDK.moveCursesWindow(@shadow_win, -xdiff, -ydiff)
      CDK.moveCursesWindow(@scrollbar_win, -xdiff, -ydiff)

      # Touch the windows so they 'move'.
      self.screen.window.refresh

      # Redraw the window, if they asked for it.
      if refresh_flag
        self.draw(@box)
      end
    end

    # This function draws the scrolling list widget.
    def draw(box)
      # Draw in the shadow if we need to.
      unless @shadow_win.nil?
        Draw.drawShadow(@shadow_win)
      end

      self.drawTitle(@win)

      # Draw in the scrolling list items.
      self.drawList(box)
    end

    def drawCurrent
      # Rehighlight the current menu item.
      screen_pos = @item_pos[@current_item] - @left_char
      highlight = if self.has_focus
                  then @highlight
                  else Ncurses::A_NORMAL
                  end

      Draw.writeChtypeAttrib(@list_win,
          if screen_pos >= 0 then screen_pos else 0 end,
          @current_high, @item[@current_item], highlight, CDK::HORIZONTAL,
          if screen_pos >= 0 then 0 else 1 - screen_pos end,
          @item_len[@current_item])
    end

    def drawList(box)
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
                if screen_pos >= 0 then screen_pos else 1 end,
                ypos, @item[k], CDK::HORIZONTAL,
                if screen_pos >= 0 then 0 else 1 - screen_pos end,
                @item_len[k])
          end
        end

        self.drawCurrent

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
    def setBKattr(attrib)
      @win.wbkgd(attrib)
      @list_win.wbkgd(attrib)
      unless @scrollbar_win.nil?
        @scrollbar_win.wbkgd(attrib)
      end
    end

    # This function destroys
    def destroy
      self.cleanTitle

      # Clean up the windows.
      CDK.deleteCursesWindow(@scrollbar_win)
      CDK.deleteCursesWindow(@shadow_win)
      CDK.deleteCursesWindow(@list_win)
      CDK.deleteCursesWindow(@win)

      # Clean the key bindings.
      self.cleanBindings(:SCROLL)

      # Unregister this object
      CDK::SCREEN.unregister(:SCROLL, self)
    end

    # This function erases the scrolling list from the screen.
    def erase
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
      @item_len[which] = item_len[0]
      @item_pos[which] = item_pos[0]

      @item_pos[which] = CDK.justifyString(@box_width,
          @item_len[which], @item_pos[which])
      return true
    end

    # This function creates the scrolling list information and sets up the
    # needed variables for the scrolling list to work correctly.
    def createItemList(numbers, list, list_size)
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
    def set(list, list_size, numbers, highlight, box)
      self.setItems(list, list_size, numbers)
      self.setHighlight(highlight)
      self.setBox(box)
    end

    # This sets the scrolling list items
    def setItems(list, list_size, numbers)
      if self.createItemList(numbers, list, list_size) <= 0
        return
      end

      # Clean up the display.
      (0...@view_size).each do |x|
        Draw.writeBlanks(@win, 1, x, CDK::HORIZONTAL, 0, @box_width - 2);
      end

      self.setViewSize(list_size)
      self.setPosition(0)
      @left_char = 0
    end

    def getItems(list)
      (0...@list_size).each do |x|
        list << CDK.chtype2Char(@item[x])
      end

      return @list_size
    end

    # This sets the highlight of the scrolling list.
    def setHighlight(highlight)
      @highlight = highlight
    end

    def getHighlight(highlight)
      return @highlight
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
            k += 1
          end
        end
      end
    end

    def insertListItem(item)
      @item = @item[0..item] + @item[item..-1]
      @item_len = @item_len[0..item] + @item_len[item..-1]
      @item_pos = @item_pos[0..item] + @item_pos[item..-1]
      return true
    end

    # This adds a single item to a scrolling list, at the end of the list.
    def addItem(item)
      item_number = @list_size
      widest_item = self.WidestItem
      temp = ''
      have = 0

      if self.allocListArrays(@list_size, @list_size + 1) &&
          self.allocListItem(item_number, temp, have,
          if @numbers then item_number + 1 else 0 end,
          item)
        # Determine the size of the widest item.
        widest_item = [@item_len[item_number], widest_item].max

        self.updateViewWidth(widest_item)
        self.setViewSize(@list_size + 1)
      end
    end

    # This adds a single item to a scrolling list before the current item
    def insertItem(item)
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
    def deleteItem(position)
      if position >= 0 && position < @list_size
        # Adjust the list
        @item = @item[0...position] + @item[position+1..-1]
        @item_len = @item_len[0...position] + @item_len[position+1..-1]
        @item_pos = @item_pos[0...position] + @item_pos[position+1..-1]

        self.setViewSize(@list_size - 1)

        if @list_size > 0
          self.resequence
        end

        if @list_size < self.maxViewSize
          @win.werase  # force the next redraw to be complete
        end

        # do this to update the view size, etc
        self.setPosition(@current_item)
      end
    end
    
    def focus
      self.drawCurrent
      @list_win.wrefresh
    end

    def unfocus
      self.drawCurrent
      @list_win.wrefresh
    end

    def AvailableWidth
      @box_width - (2 * @border_size)
    end

    def updateViewWidth(widest)
      @max_left_char = if @box_width > widest
                       then 0
                       else widest - self.AvailableWidth
                       end
    end

    def WidestItem
      @max_left_char + self.AvailableWidth
    end
  end

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

  class BUTTON < CDK::CDKOBJS
    def initialize(cdkscreen, xplace, yplace, text, callback, box, shadow)
      super()
      parent_width = cdkscreen.window.getmaxx
      parent_height = cdkscreen.window.getmaxy
      box_width = 0
      xpos = xplace
      ypos = yplace

      self.setBox(box)
      box_height = 1 + 2 * @border_size

      # Translate the string to a chtype array.
      info_len = []
      info_pos = []
      @info = CDK.char2Chtype(text, info_len, info_pos)
      @info_len = info_len[0]
      @info_pos = info_pos[0]
      box_width = [box_width, @info_len].max + 2 * @border_size

      # Create the string alignments.
      @info_pos = CDK.justifyString(box_width - 2 * @border_size,
          @info_len, @info_pos)

      # Make sure we didn't extend beyond the dimensions of the window.
      box_width = if box_width > parent_width
                  then parent_width
                  else box_width
                  end
      box_height = if box_height > parent_height
                   then parent_height
                   else box_height
                   end

      # Rejustify the x and y positions if we need to.
      xtmp = [xpos]
      ytmp = [ypos]
      CDK.alignxy(cdkscreen.window, xtmp, ytmp, box_width, box_height)
      xpos = xtmp[0]
      ypos = ytmp[0]

      # Create the button.
      @screen = cdkscreen
      # ObjOf (button)->fn = &my_funcs;
      @parent = cdkscreen.window
      @win = Ncurses::WINDOW.new(box_height, box_width, ypos, xpos)
      @shadow_win = nil
      @xpos = xpos
      @ypos = ypos
      @box_width = box_width
      @box_height = box_height
      @callback = callback
      @input_window = @win
      @accepts_focus = true
      @shadow = shadow

      if @win.nil?
        self.destroy
        return nil
      end

      @win.keypad(true)

      # If a shadow was requested, then create the shadow window.
      if shadow
        @shadow_win = Ncurses::WINDOW.new(box_height, box_width,
            ypos + 1, xpos + 1)
      end

      # Register this baby.
      cdkscreen.register(:BUTTON, self)
    end

    # This was added for the builder.
    def activate(actions)
      self.draw(@box)
      ret = -1

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
        actions.each do |x|
          ret = self.inject(action)
          if @exit_type == :EARLY_EXIT
            return ret
          end
        end
      end

      # Set the exit type and exit
      self.setExitType(0)
      return -1
    end

    # This sets multiple attributes of the widget.
    def set(mesg, box)
      self.setMessage(mesg)
      self.setBox(box)
    end

    # This sets the information within the button.
    def setMessage(info)
      info_len = []
      info_pos = []
      @info = CDK.char2Chtype(info, info_len, info_pos)
      @info_len = info_len[0]
      @info_pos = CDK.justifyString(@box_width - 2 * @border_size,
          info_pos[0])

      # Redraw the button widget.
      self.erase
      self.draw(box)
    end

    def getMessage
      return @info
    end

    # This sets the background attribute of the widget.
    def setBKattr(attrib)
      @win.wbkgd(attrib)
    end

    def drawText
      box_width = @box_width

      # Draw in the message.
      (0...(box_width - 2 * @border_size)).each do |i|
        pos = @info_pos
        len = @info_len
        if i >= pos && (i - pos) < len
          c = @info[i - pos]
        else
          c = ' '
        end

        if @has_focus
          c = Ncurses::A_REVERSE | c
        end

        @win.mvwaddch(@border_size, i + @border_size, c)
      end
    end

    # This draws the button widget
    def draw(box)
      # Is there a shadow?
      unless @shadow_win.nil?
        Draw.drawShadow(@shadow_win)
      end

      # Box the widget if asked.
      if @box
        Draw.drawObjBox(@win, self)
      end
      self.drawText
      @win.wrefresh
    end

    # This erases the button widget.
    def erase
      if self.validCDKObject
        CDK.eraseCursesWindow(@win)
        CDK.eraseCursesWindow(@shadow_win)
      end
    end

    # This moves the button field to the given location.
    def move(xplace, yplace, relative, refresh_flag)
      current_x = @win.getbegx
      current_y = @win.getbegy
      xpos = xplace
      ypos = yplace

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

      # Get the difference
      xdiff = current_x - xpos
      ydiff = current_y - ypos

      # Move the window to the new location.
      CDK.moveCursesWindow(@win, -xdiff, -ydiff)
      CDK.moveCursesWindow(@shadow_win, -xdiff, -ydiff)

      # Thouch the windows so they 'move'.
      CDK::SCREEN.refreshCDKWindow(@screen.window)

      # Redraw the window, if they asked for it.
      if refresh_flag
        self.draw(@box)
      end
    end

    # This allows the user to use the cursor keys to adjust the
    # position of the widget.
    def position
      # Declare some variables
      orig_x = @win.getbegx
      orig_y = @win.getbegy
      key = 0

      # Let them move the widget around until they hit return
      while key != Ncurses::KEY_ENTER && key != CDK::KEY_RETURN
        key = self.getch([])
        if key == Ncurses::KEY_UP || key == '8'.ord
          if @win.getbegy > 0
            self.move(0, -1, true, true)
          else
            CDK.Beep
          end
        elsif key == Ncurses::KEY_DOWN || key == '2'.ord
          if @win.getbegy + @win.getmaxy < @screen.window.getmaxy - 1
            self.move(0, 1, true, true)
          else
            CDK.Beep
          end
        elsif key == Ncurses::KEY_LEFT || key == '4'.ord
          if @win.getbegx > 0
            self.move(-1, 0, true, true)
          else
            CDK.Beep
          end
        elsif key == Ncurses::KEY_RIGHT || key == '6'.ord
          if @win.getbegx + @win.getmaxx < @screen.window.getmaxx - 1
            self.move(1, 0, true, true)
          else
            CDK.Beep
          end
        elsif key == '7'.ord
          if @win.getbegy > 0 && @win.getbegx > 0
            self.move(-1, -1, true, true)
          else
            CDK.Beep
          end
        elsif key == '9'.ord
          if @win.getbegx + @win.getmaxx < @screen.window.getmaxx - 1 &&
              @win.getbegy > 0
            self.move(1, -1, true, true)
          else
            CDK.Beep
          end
        elsif key == '1'.ord
          if @win.getbegx > 0 &&
              @win.getbegx + @win.getmaxx < @screen.window.getmaxx - 1
            self.move(-1, 1, true, true)
          else
            CDK.Beep
          end
        elsif key == '3'.ord
          if @win.getbegx + @win.getmaxx < @screen.window.getmaxx - 1 &&
              @win.getbegy + @win.getmaxy < @screen.window.getmaxy - 1
            self.move(1, 1, true, true)
          else
            CDK.Beep
          end
        elsif key == '5'.ord
          self.move(CDK::CENTER, CDK::CENTER, false, true)
        elsif key == 't'.ord
          self.move(@win.getbegx, CDK::TOP, false, true)
        elsif key == 'b'.ord
          self.move(@win.getbegx, CDK::BOTTOM, false, true)
        elsif key == 'l'.ord
          self.move(CDK::LEFT, @win.getbegy, false, true)
        elsif key == 'r'
          self.move(CDK::RIGHT, @win.getbegy, false, true)
        elsif key == 'c'
          self.move(CDK::CENTER, @win.getbegy, false, true)
        elsif key == 'C'
          self.move(@win.getbegx, CDK::CENTER, false, true)
        elsif key == CDK::REFRESH
          @screen.erase
          @screen.refresh
        elsif key == CDK::KEY_ESC
          self.move(orig_x, orig_y, false, true)
        elsif key != CDK::KEY_RETURN && key != Ncurses::KEY_ENTER
          CDK.Beep
        end
      end
    end

    # This destroys the button object pointer.
    def destroy
      CDK.deleteCursesWindow(@shadow_win)
      CDK.deleteCursesWindow(@win)

      self.cleanBindings(:BUTTON)

      CDK::SCREEN.unregister(:BUTTON, self)
    end

    # This injects a single character into the widget.
    def inject(input)
      ret = -1
      complete = false

      self.setExitType(0)

      # Check a predefined binding.
      if self.checkBind(:BUTTON, input)
        complete = true
      else
        case input
        when CDK::KEY_ESC
          self.setExitType(input)
          complete = true
        when Ncurses::ERR
          self.setExitType(input)
          complete = true
        when ' '.ord, CDK::KEY_RETURN, Ncurses::KEY_ENTER
          unless @callback.nil?
            @callback.call(self)
          end
          self.setExitType(Ncurses::KEY_ENTER)
          ret = 0
          complete = true
        when CDK::REFRESH
          @screen.erase
          @screen.refresh
        else
          CDK.Beep
        end
      end

      unless complete
        self.setExitType(0)
      end

      @result_data = ret
      return ret
    end

    def focus
      self.drawText
      @win.wrefresh
    end

    def unfocus
      self.drawText
      @win.wrefresh
    end

    def object_type
      :BUTTON
    end
  end

  class BUTTONBOX < CDK::CDKOBJS
    attr_reader :current_button

    def initialize(cdkscreen, x_pos, y_pos, height, width, title, rows, cols,
        buttons, button_count, highlight, box, shadow)
      super()
      parent_width = cdkscreen.window.getmaxx
      parent_height = cdkscreen.window.getmaxy
      col_width = 0
      current_button = 0
      @button = []
      @button_len = []
      @button_pos = []
      @column_widths = []

      if button_count <= 0
        self.destroy
        return nil
      end

      self.setBox(box)

      # Set some default values for the widget.
      @row_adjust = 0
      @col_adjust = 0

      # If the height is a negative value, the height will be
      # ROWS-height, otherwise the height will be the given height.
      box_height = CDK.setWidgetDimension(parent_height, height, rows + 1)

      # If the width is a negative value, the width will be
      # COLS-width, otherwise the width will be the given width.
      box_width = CDK.setWidgetDimension(parent_width, width, 0)

      box_width = self.setTitle(title, box_width)

      # Translate the buttons string to a chtype array
      (0...button_count).each do |x|
        button_len = []
        @button << CDK.char2Chtype(buttons[x], button_len ,[]) 
        @button_len << button_len[0]
      end

      # Set the button positions.
      (0...cols).each do |x|
        max_col_width = -2**31

        # Look for the widest item in this column.
        (0...rows).each do |y|
          if current_button < button_count
            max_col_width = [@button_len[current_button], max_col_width].max
            current_button += 1
          end
        end

        # Keep the maximum column width for this column.
        @column_widths << max_col_width
        col_width += max_col_width
      end
      box_width += 1

      # Make sure we didn't extend beyond the dimensions of the window.
      box_width = if box_width > parent_width
                  then parent_width
                  else box_width
                  end
      box_height = if box_height > parent_height
                   then parent_height
                   else box_height
                   end

      # Now we have to readjust the x and y positions
      xtmp = [x_pos]
      ytmp = [y_pos]
      CDK.alignxy(cdkscreen.window, xtmp, ytmp, box_width, box_height)
      xpos = xtmp[0]
      ypos = ytmp[0]

      # Set up the buttonbox box attributes.
      @screen = cdkscreen
      @parent = cdkscreen.window
      @win = Ncurses::WINDOW.new(box_height, box_width, ypos, xpos)
      @shadow_win = nil
      @button_count = button_count
      @current_button = 0
      @rows = rows
      @cols = if button_count < cols then button_count else cols end
      @box_height = box_height
      @box_width = box_width
      @highlight = highlight
      @accepts_focus = true
      @input_window = @win
      @shadow = shadow
      @button_attrib = Ncurses::A_NORMAL

      # Set up the row adjustment.
      if box_height - rows - @title_lines > 0
        @row_adjust = (box_height - rows - @title_lines) / @rows
      end

      # Set the col adjustment
      if box_width - col_width > 0
        @col_adjust = ((box_width - col_width) / @cols) - 1
      end

      # If we couldn't create the window, we should return a null value.
      if @win.nil?
        self.destroy
        return nil
      end

      # Was there a shadow?
      if shadow
        @shadow_win = Ncurses::WINDOW.new(box_height, box_width,
            ypos + 1, xpos + 1)
      end

      # Register this baby.
      cdkscreen.register(:BUTTONBOX, self)
    end

    # This activates the widget.
    def activate(actions)
      input = 0

      # Draw the buttonbox box.
      self.draw(@box)

      if actions.nil? || actions.size == 0
        while true
          input = self.getch([])

          # Inject the characer into the widget.
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

      # Set the exit type and exit
      self.setExitType(0)
      return -1
    end

    # This injects a single character into the widget.
    def inject(input)
      first_button = 0
      last_button = @button_count - 1
      pp_return = 1
      ret = -1
      complete = false

      # Set the exit type
      self.setExitType(0)

      unless @pre_process_func.nil?
        pp_return = @pre_process_func.call(:BUTTONBOX, self,
            @pre_process_data, input)
      end

      # Should we continue?
      if pp_return != 0
        # Check for a key binding.
        if self.checkBind(:BUTTONBOX, input)
          complete = true
        else
          case input
          when Ncurses::KEY_LEFT, Ncurses::KEY_BTAB, Ncurses::KEY_BACKSPACE
            if @current_button - @rows < first_button
              @current_button = last_button
            else
              @current_button -= @rows
            end
          when Ncurses::KEY_RIGHT, CDK::KEY_TAB, ' '.ord
            if @current_button + @rows > last_button
              @current_button = first_button
            else
              @current_button += @rows
            end
          when Ncurses::KEY_UP
            if @current_button -1 < first_button
              @current_button = last_button
            else
              @current_button -= 1
            end
          when Ncurses::KEY_DOWN
            if @current_button + 1 > last_button
              @current_button = first_button
            else
              @current_button += 1
            end
          when CDK::REFRESH
            @screen.erase
            @screen.refresh
          when CDK::KEY_ESC
            self.setExitType(input)
            complete = true
          when Ncurses::ERR
            self.setExitType(input)
            complete = true
          when CDK::KEY_RETURN, Ncurses::KEY_ENTER
            self.setExitType(input)
            ret = @current_button
            complete = true
          end
        end

        if !complete && !(@post_process_func.nil?)
          @post_process_func.call(:BUTTONBOX, self, @post_process_data,
              input)
        end

      end
        
      unless complete
        self.drawButtons
        self.setExitType(0)
      end

      @result_data = ret
      return ret
    end

    # This sets multiple attributes of the widget.
    def set(highlight, box)
      self.setHighlight(highlight)
      self.setBox(box)
    end

    # This sets the highlight attribute for the buttonboxes
    def setHighlight(highlight)
      @highlight = highlight
    end

    def getHighlight
      return @highlight
    end

    # This sets th background attribute of the widget.
    def setBKattr(attrib)
      @win.wbkgd(attrib)
    end

    # This draws the buttonbox box widget.
    def draw(box)
      # Is there a shadow?
      unless @shadow_win.nil?
        Draw.drawShadow(@shadow_win)
      end

      # Box the widget if they asked.
      if box
        Draw.drawObjBox(@win, self)
      end

      # Draw in the title if there is one.
      self.drawTitle(@win)

      # Draw in the buttons.
      self.drawButtons
    end

    # This draws the buttons on the button box widget.
    def drawButtons
      row = @title_lines + 1
      col = @col_adjust / 2
      current_button = 0
      cur_row = -1
      cur_col = -1

      # Draw the buttons.
      while current_button < @button_count
        (0...@cols).each do |x|
          row = @title_lines + @border_size

          (0...@rows).each do |y|
            attr = @button_attrib
            if current_button == @current_button
              attr = @highlight
              cur_row = row
              cur_col = col
            end
            Draw.writeChtypeAttrib(@win, col, row,
                @button[current_button], attr, CDK::HORIZONTAL, 0,
                @button_len[current_button])
            row += (1 + @row_adjust)
            current_button += 1
          end
          col += @column_widths[x] + @col_adjust + @border_size
        end
      end

      if cur_row >= 0 && cur_col >= 0
        @win.wmove(cur_row, cur_col)
      end
      @win.wrefresh
    end

    # This erases the buttonbox box from the screen.
    def erase
      if self.validCDKObject
        CDK.eraseCursesWindow(@win)
        CDK.eraseCursesWindow(@shadow_win)
      end
    end

    # This moves the buttonbox box to a new screen location.
    def move(xplace, yplace, relative, refresh_flag)
      current_x = @win.getbegx
      current_y = @win.getbegy
      xpos = xplace
      ypos = yplace
      xdiff = 0
      ydiff = 0

      # If this a relative move, then we will adjust where we want
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

    # This destroys the widget
    def destroy
      self.cleanTitle

      CDK.deleteCursesWindow(@shadow_win)
      CDK.deleteCursesWindow(@win)

      self.cleanBindings(:BUTTONBOX)

      CDK::SCREEN.unregister(:BUTTONBOX, self)
    end

    def setCurrentButton(button)
      if button >= 0 && button < @button_count
        @current_button = button
      end
    end

    def getCurrentButton
      @current_button
    end

    def getButtonCount
      @button_count
    end

    def focus
      self.draw(@box)
    end

    def unfocus
      self.draw(@box)
    end

    def object_type
      :BUTTONBOX
    end

    def position
      super(@win)
    end
  end

  class ENTRY < CDK::CDKOBJS
    attr_accessor :info, :left_char, :screen_col
    attr_reader :win, :box_height, :box_width, :max, :field_width
    attr_reader :min, :max

    def initialize(cdkscreen, xplace, yplace, title, label, field_attr, filler,
        disp_type, f_width, min, max, box, shadow)
      super()
      parent_width = cdkscreen.window.getmaxx
      parent_height = cdkscreen.window.getmaxy
      field_width = f_width
      box_width = 0
      xpos = xplace
      ypos = yplace
      
      self.setBox(box)
      box_height = @border_size * 2 + 1

      # If the field_width is a negative value, the field_width will be
      # COLS-field_width, otherwise the field_width will be the given width.
      field_width = CDK.setWidgetDimension(parent_width, field_width, 0)
      box_width = field_width + 2 * @border_size

      # Set some basic values of the entry field.
      @label = 0
      @label_len = 0
      @label_win = nil

      # Translate the label string to a chtype array
      if !(label.nil?) && label.size > 0
        label_len = [@label_len]
        @label = CDK.char2Chtype(label, label_len, [])
        @label_len = label_len[0]
        box_width += @label_len
      end

      old_width = box_width
      box_width = self.setTitle(title, box_width)
      horizontal_adjust = (box_width - old_width) / 2

      box_height += @title_lines

      # Make sure we didn't extend beyond the dimensinos of the window.
      box_width = [box_width, parent_width].min
      box_height = [box_height, parent_height].min
      field_width = [field_width,
          box_width - @label_len - 2 * @border_size].min

      # Rejustify the x and y positions if we need to.
      xtmp = [xpos]
      ytmp = [ypos]
      CDK.alignxy(cdkscreen.window, xtmp, ytmp, box_width, box_height)
      xpos = xtmp[0]
      ypos = ytmp[0]

      # Make the label window.
      @win = cdkscreen.window.subwin(box_height, box_width, ypos, xpos)
      if @win.nil?
        self.destroy
        return nil
      end
      @win.keypad(true)

      # Make the field window.
      @field_win = @win.subwin(1, field_width,
          ypos + @title_lines + @border_size,
          xpos + @label_len + horizontal_adjust + @border_size)

      if @field_win.nil?
        self.destroy
        return nil
      end
      @field_win.keypad(true)

      # make the label win, if we need to
      if !(label.nil?) && label.size > 0
        @label_win = @win.subwin(1, @label_len,
            ypos + @title_lines + @border_size,
            xpos + horizontal_adjust + @border_size)
      end

      # cleanChar (entry->info, max + 3, '\0');
      @info = ''
      @info_width = max + 3

      # Set up the rest of the structure.
      @screen = cdkscreen
      @parent = cdkscreen.window
      @shadow_win = nil
      @field_attr = field_attr
      @field_width = field_width
      @filler = filler
      @hidden = filler
      @input_window = @field_win
      @accepts_focus = true
      @data_ptr = nil
      @shadow = shadow
      @screen_col = 0
      @left_char = 0
      @min = min
      @max = max
      @box_width = box_width
      @box_height = box_height
      @disp_type = disp_type
      @callbackfn = lambda do |entry, character|
        plainchar = Display.filterByDisplayType(entry, character)

        if plainchar == Ncurses::ERR || entry.info.size >= entry.max
          CDK.Beep
        else
          # Update the screen and pointer
          if entry.screen_col != entry.field_width - 1
            front = (entry.info[0...(entry.screen_col + entry.left_char)] or '')
            back = (entry.info[(entry.screen_col + entry.left_char)..-1] or '')
            entry.info = front + plainchar.chr + back
            entry.screen_col += 1
          else
            # Update the character pointer.
            entry.info << plainchar
            # Do not update the pointer if it's the last character
            if entry.info.size < entry.max
              entry.left_char += 1
            end
          end

          # Update the entry field.
          entry.drawField
        end
      end

      # Do we want a shadow?
      if shadow
        @shadow_win = cdkscreen.window.subwin(box_height, box_width,
            ypos + 1, xpos + 1)
      end

      cdkscreen.register(:ENTRY, self)
    end

    # This means you want to use the given entry field. It takes input
    # from the keyboard, and when it's done, it fills the entry info
    # element of the structure with what was typed.
    def activate(actions)
      input = 0
      ret = 0

      # Draw the widget.
      self.draw(@box)

      if actions.nil? or actions.size == 0
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

      # Make sure we return the correct info.
      if @exit_type == :NORMAL
        return @info
      else
        return 0
      end
    end

    def setPositionToEnd
      if @info.size >= @field_width
        if @info.size < @max
          char_count = @field_width - 1
          @left_char = @info.size - char_count
          @screen_col = char_count
        else
          @left_char = @info.size - @field_width
          @screen_col = @info.size - 1
        end
      else
        @left_char = 0
        @screen_col = @info.size
      end
    end

    # This injects a single character into the widget.
    def inject(input)
      pp_return = 1
      ret = 1
      complete = false

      # Set the exit type
      self.setExitType(0)
      
      # Refresh the widget field.
      self.drawField

      unless @pre_process_func.nil?
        pp_return = @pre_process_func.call(:ENTRY, self,
            @pre_process_data, input)
      end

      # Should we continue?
      if pp_return != 0
        # Check a predefined binding
        if self.checkBind(:ENTRY, input)
          complete = true
        else
          curr_pos = @screen_col + @left_char

          case input
          when Ncurses::KEY_UP, Ncurses::KEY_DOWN
            CDK.Beep
          when Ncurses::KEY_HOME
            @left_char = 0
            @screen_col = 0
            self.drawField
          when CDK::TRANSPOSE
            if curr_pos >= @info.size - 1
              CDK.Beep
            else
              holder = @info[curr_pos]
              @info[curr_pos] = @info[curr_pos + 1]
              @info[curr_pos + 1] = holder
              self.drawField
            end
          when Ncurses::KEY_END
            self.setPositionToEnd
            self.drawField
          when Ncurses::KEY_LEFT
            if curr_pos <= 0
              CDK.Beep
            elsif @screen_col == 0
              # Scroll left.
              @left_char -= 1
              self.drawField
            else
              @screen_col -= 1
              @field_win.wmove(0, @screen_col)
            end
          when Ncurses::KEY_RIGHT
            if curr_pos >= @info.size
              CDK.Beep
            elsif @screen_col == @field_width - 1
              # Scroll to the right.
              @left_char += 1
              self.drawField
            else
              # Move right.
              @screen_col += 1
              @field_win.wmove(0, @screen_col)
            end
          when Ncurses::KEY_BACKSPACE, Ncurses::KEY_DC
            if @disp_type == :VIEWONLY
              CDK.Beep
            else
              success = false
              if input == Ncurses::KEY_BACKSPACE
                curr_pos -= 1
              end

              if curr_pos >= 0 && @info.size > 0
                if curr_pos < @info.size
                  @info = @info[0...curr_pos] + @info[curr_pos+1..-1]
                  success = true
                elsif input == Ncurses::KEY_BACKSPACE
                  @info = @info[0...-1]
                  success = true
                end
              end
              
              if success
                if input == Ncurses::KEY_BACKSPACE
                  if @screen_col > 0
                    @screen_col -= 1
                  else
                    @left_char -= 1
                  end
                end
                self.drawField
              else
                CDK.Beep
              end
            end
          when CDK::KEY_ESC
            self.setExitType(input)
            complete = true
          when CDK::ERASE
            if @info.size != 0
              self.clean
              self.drawField
            end
          when CDK::CUT
            if @info.size != 0
              @@g_paste_buffer = @info.clone
              self.clean
              self.drawField
            else
              CDK.Beep
            end
          when CDK::COPY
            if @info.size != 0
              @@g_paste_buffer = @info.clone
            else
              CDK.Beep
            end
          when CDK::PASTE
            if @@g_paste_buffer != 0
              self.setValue(@@g_paste_buffer)
              self.drawField
            else
              CDK.Beep
            end
          when CDK::KEY_TAB, CDK::KEY_RETURN, Ncurses::KEY_ENTER
            if @info.size >= @min
              self.setExitType(input)
              ret = @info
              complete = true
            else
              CDK.Beep
            end
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

        if !complete && !(@post_process_func.nil?)
          @post_process_func.call(:ENTRY, self, @post_process_data, input)
        end
      end

      unless complete
        self.setExitType(0)
      end

      @result_data = ret
      return ret
    end

    # This moves the entry field to the given location.
    def move(xplace, yplace, relative, refresh_flag)
      current_x = @win.getbegx
      current_y = @win.getbegy
      xpos = xplace
      ypos = yplace

      # If this is a relative move, then we will adjust where we want
      # to move to.
      if relative
        xpos = @win.getbegx + xplace
        ypos = @win.getbegy + yplace
      end

      # Adjust the window if we need to
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
      CDK.moveCursesWindow(@field_win, -xdiff, -ydiff)
      CDK.moveCursesWindow(@label_win, -xdiff, -ydiff)
      CDK.moveCursesWindow(@shadow_win, -xdiff, -ydiff)

      # Touch the windows so they 'move'
      CDK::SCREEN.refreshCDKWindow(@screen.window)

      # Redraw the window, if they asked for it
      if refresh_flag
        self.draw(@box)
      end
    end
    
    # This erases the information in the entry field and redraws
    # a clean and empty entry field.
    def clean
      width = @field_width

      @info = ''

      # Clean the entry screen field.
      @field_win.mvwhline(0, 0, @filler.ord, width)

      # Reset some variables
      @screen_col = 0
      @left_char = 0

      # Refresh the entry field.
      @field_win.wrefresh
    end

    # This draws the entry field.
    def draw(box)
      # Did we ask for a shadow?
      unless @shadow_win.nil?
        Draw.drawShadow(@shadow_win)
      end

      # Box the widget if asked.
      if box
        Draw.drawObjBox(@win, self)
      end

      self.drawTitle(@win)

      @win.wrefresh

      # Draw in the label to the widget.
      unless @label_win.nil?
        Draw.writeChtype(@label_win, 0, 0, @label, CDK::HORIZONTAL, 0,
            @label_len)
        @label_win.wrefresh
      end

      self.drawField
    end

    def drawField
      # Draw in the filler characters.
      @field_win.mvwhline(0, 0, @filler.ord, @field_width)

      # If there is information in the field then draw it in.
      if !(@info.nil?) && @info.size > 0
        # Redraw the field.
        if Display.isHiddenDisplayType(@disp_type)
          (@left_char...@info.size).each do |x|
            @field_win.mvwaddch(0, x - @left_char, @hidden)
          end
        else
          (@left_char...@info.size).each do |x|
            @field_win.mvwaddch(0, x - @left_char, @info[x].ord | @field_attr)
          end
        end
        @field_win.wmove(0, @screen_col)
      end

      @field_win.wrefresh
    end

    # This erases an entry widget from the screen.
    def erase
      if self.validCDKObject
        CDK.eraseCursesWindow(@field_win)
        CDK.eraseCursesWindow(@label_win)
        CDK.eraseCursesWindow(@win)
        CDK.eraseCursesWindow(@shadow_win)
      end
    end

    # This destroys an entry widget.
    def destroy
      self.cleanTitle

      CDK.deleteCursesWindow(@field_win)
      CDK.deleteCursesWindow(@label_win)
      CDK.deleteCursesWindow(@shadow_win)
      CDK.deleteCursesWindow(@win)

      self.cleanBindings(:ENTRY)

      CDK::SCREEN.unregister(:ENTRY, self)
    end

    # This sets specific attributes of the entry field.
    def set(value, min, max, box)
      self.setValue(value)
      self.setMin(min)
      self.setMax(max)
    end

    # This removes the old information in the entry field and keeps
    # the new information given.
    def setValue(new_value)
      if new_value.nil?
        @info = ''

        @left_char = 0
        @screen_col = 0
      else
        @info = new_value.clone

        self.setPositionToEnd
      end
    end

    def getValue
      return @info
    end

    # This sets the maximum length of the string that will be accepted
    def setMax(max)
      @max = max
    end

    def getMax
      @max
    end

    # This sets the minimum length of the string that will be accepted.
    def setMin(min)
      @min = min
    end

    def getMin
      @min
    end

    # This sets the filler character to be used in the entry field.
    def setFillerChar(filler_char)
      @filler = filler_char
    end

    def getFillerChar
      @filler
    end

    # This sets the character to use when a hidden type is used.
    def setHiddenChar(hidden_characer)
      @hidden = hidden_character
    end

    def getHiddenChar
      @hidden
    end

    # This sets the background attribute of the widget.
    def setBKattr(attrib)
      @win.wbkgd(attrib)
      @field_win.wbkgd(attrib)
      unless @label_win.nil?
        @label_win.wbkgd(attrib)
      end
    end

    # This sets the attribute of the entry field.
    def setHighlight(highlight, cursor)
      @field_win.wbkgd(highlight)
      @field_attr = highlight
      Ncurses.curs_set(cursor)
      # FIXME(original) - if (cursor) { move the cursor to this widget }
    end

    # This sets the entry field callback function.
    def setCB(callback)
      @callbackfn = callback
    end

    def focus
      @field_win.wmove(0, @screen_col)
      @field_win.wrefresh
    end

    def unfocus
      self.draw(box)
      @field_win.wrefresh
    end

    def position
      super(@win)
    end

    def object_type
      :ENTRY
    end
  end

  class DIALOG < CDK::CDKOBJS
    attr_reader :current_button
    MIN_DIALOG_WIDTH = 10

    def initialize(cdkscreen, xplace, yplace, mesg, rows, button_label,
        button_count, highlight, separator, box, shadow)
      super()
      box_width = DIALOG::MIN_DIALOG_WIDTH
      max_message_width = -1
      button_width = 0
      xpos = xplace
      ypos = yplace
      temp = 0
      buttonadj = 0
      @info = []
      @info_len = []
      @info_pos = []
      @button_label = []
      @button_len = []
      @button_pos = []

      if rows <= 0 || button_count <= 0
        self.destroy
        return nil
      end

      self.setBox(box)
      box_height = if separator then 1 else 0 end
      box_height += rows + 2 * @border_size + 1

      # Translate the string message to a chtype array
      (0...rows).each do |x|
        info_len = []
        info_pos = []
        @info << CDK.char2Chtype(mesg[x], info_len, info_pos)
        @info_len << info_len[0]
        @info_pos << info_pos[0]
        max_message_width = [max_message_width, info_len[0]].max
      end

      # Translate the button label string to a chtype array
      (0...button_count).each do |x|
        button_len = []
        @button_label << CDK.char2Chtype(button_label[x], button_len, [])
        @button_len << button_len[0]
        button_width += button_len[0] + 1
      end

      button_width -= 1

      # Determine the final dimensions of the box.
      box_width = [box_width, max_message_width, button_width].max
      box_width = box_width + 2 + 2 * @border_size

      # Now we have to readjust the x and y positions.
      xtmp = [xpos]
      ytmp = [ypos]
      CDK.alignxy(cdkscreen.window, xtmp, ytmp, box_width, box_height)
      xpos = xtmp[0]
      ypos = ytmp[0]

      # Set up the dialog box attributes.
      @screen = cdkscreen
      @parent = cdkscreen.window
      @win = Ncurses::WINDOW.new(box_height, box_width, ypos, xpos)
      @shadow_win = nil
      @button_count = button_count
      @current_button = 0
      @message_rows = rows
      @box_height = box_height
      @box_width = box_width
      @highlight = highlight
      @separator = separator
      @accepts_focus = true
      @input_window = @win
      @shadow = shadow

      # If we couldn't create the window, we should return a nil value.
      if @win.nil?
        self.destroy
        return nil
      end
      @win.keypad(true)

      # Find the button positions.
      buttonadj = (box_width - button_width) / 2
      (0...button_count).each do |x|
        @button_pos[x] = buttonadj
        buttonadj = buttonadj + @button_len[x] + @border_size
      end

      # Create the string alignments.
      (0...rows).each do |x|
        @info_pos[x] = CDK.justifyString(box_width - 2 * @border_size,
            @info_len[x], @info_pos[x])
      end

      # Was there a shadow?
      if shadow
        @shadow_win = Ncurses::WINDOW.new(box_height, box_width,
            ypos + 1, xpos + 1)
      end

      # Register this baby.
      cdkscreen.register(:DIALOG, self)
    end

    # This lets the user select the button.
    def activate(actions)
      input = 0

      # Draw the dialog box.
      self.draw(@box)

      # Lets move to the first button.
      Draw.writeChtypeAttrib(@win, @button_pos[@current_button],
          @box_height - 1 - @border_size, @button_label[@current_button],
          @highlight, CDK::HORIZONTAL, 0, @button_len[@current_button])
      @win.wrefresh

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

      # Set the exit type and exit
      self.setExitType(0)
      return -1
    end

    # This injects a single character into the dialog widget
    def inject(input)
      first_button = 0
      last_button = @button_count - 1
      pp_return = 1
      ret = -1
      complete = false

      # Set the exit type.
      self.setExitType(0)

      # Check if there is a pre-process function to be called.
      unless @pre_process_func.nil?
        pp_return = @pre_process_func.call(:DIALOG, self,
            @pre_process_data, input)
      end

      # Should we continue?
      if pp_return != 0
        # Check for a key binding.
        if self.checkBind(:DIALOG, input)
          complete = true
        else
          case input
          when Ncurses::KEY_LEFT, Ncurses::KEY_BTAB, Ncurses::KEY_BACKSPACE
            if @current_button == first_button
              @current_button = last_button
            else
              @current_button -= 1
            end
          when Ncurses::KEY_RIGHT, CDK::KEY_TAB, ' '.ord
            if @current_button == last_button
              @current_button = first_button
            else
              @current_button += 1
            end
          when Ncurses::KEY_UP, Ncurses::KEY_DOWN
            CDK.Beep
          when CDK::REFRESH
            @screen.erase
            @screen.refresh
          when CDK::KEY_ESC
            self.setExitType(input)
            complete = true
          when Ncurses::ERR
            self.setExitType(input)
          when Ncurses::KEY_ENTER, CDK::KEY_RETURN
            self.setExitType(input)
            ret = @current_button
            complete = true
          end
        end

        # Should we call a post_process?
        if !complete && !(@post_process_func.nil?)
          @post_process_func.call(:DIALOG, self,
              @post_process_data, input)
        end
      end

      unless complete
        self.drawButtons
        @win.wrefresh
        self.setExitType(0)
      end

      @result_data = ret
      return ret
    end

    # This moves the dialog field to the given location.
    def move(xplace, yplace, relative, refresh_flag)
      current_x = @win.getbegx
      current_y = @win.getbegy
      xpos = xplace
      ypos = yplace

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

      # Move the window to the new location.
      CDK.moveCursesWindow(@win, -xdiff, -ydiff)
      CDK.moveCursesWindow(@shadow_win, -xdiff, -ydiff)

      # Touch the windows so they 'move'.
      if refresh_flag
        self.draw(@box)
      end
    end

    # This function draws the dialog widget.
    def draw(box)
      # Is there a shadow?
      unless @shadow_win.nil?
        Draw.drawShadow(@shadow_win)
      end

      # Box the widget if they asked.
      if box
        Draw.drawObjBox(@win, self)
      end

      # Draw in the message.
      (0...@message_rows).each do |x|
        Draw.writeChtype(@win,
            @info_pos[x] + @border_size, x + @border_size, @info[x],
            CDK::HORIZONTAL, 0, @info_len[x])
      end

      # Draw in the buttons.
      self.drawButtons

      @win.wrefresh
    end

    # This function destroys the dialog widget.
    def destroy
      # Clean up the windows.
      CDK.deleteCursesWindow(@win)
      CDK.deleteCursesWindow(@shadow_win)

      # Clean the key bindings
      self.cleanBindings(:DIALOG)

      # Unregister this object
      CDK::SCREEN.unregister(:DIALOG, self)
    end

    # This function erases the dialog widget from the screen.
    def erase
      if self.validCDKObject
        CDK.eraseCursesWindow(@win)
        CDK.eraseCursesWindow(@shadow_win)
      end
    end

    # This sets attributes of the dialog box.
    def set(highlight, separator, box)
      self.setHighlight(highlight)
      self.setSeparator(separator)
      self.setBox(box)
    end

    # This sets the highlight attribute for the buttons.
    def setHighlight(highlight)
      @highlight = highlight
    end

    def getHighlight
      return @highlight
    end

    # This sets whether or not the dialog box will have a separator line.
    def setSeparator(separator)
      @separator = separator
    end

    def getSeparator
      return @separator
    end

    # This sets the background attribute of the widget.
    def setBKattr(attrib)
      @win.wbkgd(attrib)
    end

    # This draws the dialog buttons and the separation line.
    def drawButtons
      (0...@button_count).each do |x|
        Draw.writeChtype(@win, @button_pos[x],
            @box_height -1 - @border_size,
            @button_label[x], CDK::HORIZONTAL, 0,
            @button_len[x])
      end

      # Draw the separation line.
      if @separator
        boxattr = @BXAttr

        (1...@box_width).each do |x|
          @win.mvwaddch(@box_height - 2 - @border_size, x,
              Ncurses::ACS_HLINE | boxattr)
        end
        @win.mvwaddch(@box_height - 2 - @border_size, 0,
            Ncurses::ACS_LTEE | boxattr)
        @win.mvwaddch(@box_height - 2 - @border_size, @win.getmaxx - 1,
            Ncurses::ACS_RTEE | boxattr)
      end
      Draw.writeChtypeAttrib(@win, @button_pos[@current_button],
          @box_height - 1 - @border_size, @button_label[@current_button],
          @highlight, CDK::HORIZONTAL, 0, @button_len[@current_button])
    end

    def focus
      self.draw(@box)
    end

    def unfocus
      self.draw(@box)
    end

    def object_type
      :DIALOG
    end

    def position
      super(@win)
    end
  end

  class GRAPH < CDK::CDKOBJS
    def initialize(cdkscreen, xplace, yplace, height, width,
        title, xtitle, ytitle)
      super()
      parent_width = cdkscreen.window.getmaxx
      parent_height = cdkscreen.window.getmaxy

      self.setBox(false)

      box_height = CDK.setWidgetDimension(parent_height, height, 3)
      box_width = CDK.setWidgetDimension(parent_width, width, 0)
      box_width = self.setTitle(title, box_width)
      box_height += @title_lines
      box_width = [parent_width, box_width].min
      box_height = [parent_height, box_height].min

      # Rejustify the x and y positions if we need to
      xtmp = [xplace]
      ytmp = [yplace]
      CDK.alignxy(cdkscreen.window, xtmp, ytmp, box_width, box_height)
      xpos = xtmp[0]
      ypos = ytmp[0]

      # Create the widget pointer
      @screen = cdkscreen
      @parent = cdkscreen.window
      @win = Ncurses::WINDOW.new(box_height, box_width, ypos, xpos)
      @box_height = box_height
      @box_width = box_width
      @minx = 0
      @maxx = 0
      @xscale = 0
      @yscale = 0
      @count = 0
      @display_type = :LINE

      if @win.nil?
        self.destroy
        return nil
      end
      @win.keypad(true)

      # Translate the X axis title string to a chtype array
      if !(xtitle.nil?) && xtitle.size > 0
        xtitle_len = []
        xtitle_pos = []
        @xtitle = CDK.char2Chtype(xtitle, xtitle_len, xtitle_pos)
        @xtitle_len = xtitle_len[0]
        @xtitle_pos = CDK.justifyString(@box_height,
            @xtitle_len, xtitle_pos[0])
      else
        xtitle_len = []
        xtitle_pos = []
        @xtitle = CDK.char2Chtype("<C></5>X Axis", xtitle_len, xtitle_pos)
        @xtitle_len = title_len[0]
        @xtitle_pos = CDK.justifyString(@box_height,
            @xtitle_len, xtitle_pos[0])
      end

      # Translate the Y Axis title string to a chtype array
      if !(ytitle.nil?) && ytitle.size > 0
        ytitle_len = []
        ytitle_pos = []
        @ytitle = CDK.char2Chtype(ytitle, ytitle_len, ytitle_pos)
        @ytitle_len = ytitle_len[0]
        @ytitle_pos = CDK.justifyString(@box_width, @ytitle_len, ytitle_pos[0])
      else
        ytitle_len = []
        ytitle_pos = []
        @ytitle = CDK.char2Chtype("<C></5>Y Axis", ytitle_len, ytitle_pos)
        @ytitle_len = ytitle_len[0]
        @ytitle_pos = CDK.justifyString(@box_width, @ytitle_len, ytitle_pos[0])
      end

      @graph_char = 0
      @values = []

      cdkscreen.register(:GRAPH, self)
    end

    # This was added for the builder.
    def activate(actions)
      self.draw(@box)
    end

    # Set multiple attributes of the widget
    def set(values, count, graph_char, start_at_zero, display_type)
      ret = self.setValues(values, count, start_at_zero)
      self.setCharacters(graph_char)
      self.setDisplayType(display_type)
      return ret
    end

    # Set the scale factors for the graph after wee have loaded new values.
    def setScales
      @xscale = (@maxx - @minx) / [1, @box_height - @title_lines - 5].max
      if @xscale <= 0
        @xscale = 1
      end

      @yscale = (@box_width - 4) / [1, @count].max
      if @yscale <= 0
        @yscale = 1
      end
    end

    # Set the values of the graph.
    def setValues(values, count, start_at_zero)
      min = 2**30
      max = -2**30

      # Make sure everything is happy.
      if count < 0
        return false
      end

      if !(@values.nil?) && @values.size > 0
        @values = []
        @count = 0
      end

      # Copy the X values
      values.each do |value|
        min = [value, @minx].min
        max = [value, @maxx].max

        # Copy the value.
        @values << value
      end

      # Keep the count and min/max values
      @count = count
      @minx = min
      @maxx = max

      # Check the start at zero status.
      if start_at_zero
        @minx = 0
      end

      self.setScales

      return true
    end

    def getValues(size)
      size << @count
      return @values
    end

    # Set the value of the graph at the given index.
    def setValue(index, value, start_at_zero)
      # Make sure the index is within range.
      if index < 0 || index >= @count
        return false
      end

      # Set the min, max, and value for the graph
      @minx = [value, @minx].min
      @maxx = [value, @maxx].max
      @values[index] = value

      # Check the start at zero status
      if start_at_zero
        @minx = 0
      end

      self.setScales

      return true
    end

    def getValue(index)
      if index >= 0 && index < @count then @values[index] else 0 end
    end

    # Set the characters of the graph widget.
    def setCharacters(characters)
      char_count = []
      new_tokens = CDK.char2Chtype(characters, char_count, [])

      if char_count[0] != @count
        return false
      end

      @graph_char = new_tokens
      return true
    end

    def getCharacters
      return @graph_char
    end

    # Set the character of the graph widget of the given index.
    def setCharacter(index, character)
      # Make sure the index is within range
      if index < 0 || index > @count
        return false
      end

      # Convert the string given to us
      char_count = []
      new_tokens = CDK.char2Chtype(character, char_count, [])

      # Check if the number of characters back is the same as the number
      # of elements in the list.
      if char_count[0] != @count
        return false
      end

      # Everything OK so far. Set the value of the array.
      @graph_char[index] = new_tokens[0]
      return true
    end

    def getCharacter(index)
      return graph_char[index]
    end

    # Set the display type of the graph.
    def setDisplayType(type)
      @display_type = type
    end

    def getDisplayType
      @display_type
    end

    # Set the background attribute of the widget.
    def setBKattr(attrib)
      @win.wbkgd(attrib)
    end

    # Move the graph field to the given location.
    def move(xplace, yplace, relative, refresh_flag)
      current_x = @win.getbegx
      current_y = @win.getbegy
      xpos = xplace
      ypos = yplace

      # If this is a relative move, then we will adjust where we want
      # to move to
      if relative
        xpos = @win.getbegx + xplace
        ypos = @win.getbegy + yplace
      end

      # Adjust the window if we need to.
      xtmp = [xpos]
      tymp = [ypos]
      CDK.alignxy(@screen.window, xtmp, ytmp, @box_width, @box_height)
      xpos = xtmp[0]
      ypos = ytmp[0]

      # Get the difference
      xdiff = current_x - xpos
      ydiff = current_y - ypos

      # Move the window to the new location.
      CDK.moveCursesWindow(@win, -xdiff, -ydiff)
      CDK.moveCursesWindow(@shadow_win, -xdiff, -ydiff)

      # Touch the windows so they 'move'.
      CDK::SCREEN.refreshCDKWindow(@screen.window)

      # Reraw the windowk if they asked for it
      if refresh_flag
        self.draw(@box)
      end
    end

    # Draw the grpah widget
    def draw(box)
      adj = 2 + (if @xtitle.nil? || @xtitle.size == 0 then 0 else 1 end)
      spacing = 0
      attrib = ' '.ord | Ncurses::A_REVERSE

      if box
        Draw.drawObjBox(@win, self)
      end

      # Draw in the vertical axis
      Draw.drawLine(@win, 2, @title_lines + 1, 2, @box_height - 3,
          Ncurses::ACS_VLINE)

      # Draw in the horizontal axis
      Draw.drawLine(@win, 3, @box_height - 3, @box_width, @box_height - 3,
          Ncurses::ACS_HLINE)

      self.drawTitle(@win)

      # Draw in the X axis title.
      if !(@xtitle.nil?) && @xtitle.size > 0
        Draw.writeChtype(@win, 0, @xtitle_pos, @xtitle, CDK::VERTICAL,
            0, @xtitle_len)
        attrib = @xtitle[0] & Ncurses::A_ATTRIBUTES
      end

      # Draw in the X axis high value
      temp = "%d" % [@maxx]
      Draw.writeCharAttrib(@win, 1, @title_lines + 1, temp, attrib,
          CDK::VERTICAL, 0, temp.size)

      # Draw in the X axis low value.
      temp = "%d" % [@minx]
      Draw.writeCharAttrib(@win, 1, @box_height - 2 - temp.size, temp, attrib,
          CDK::VERTICAL, 0, temp.size)

      # Draw in the Y axis title
      if !(@ytitle.nil?) && @ytitle.size > 0
        Draw.writeChtype(@win, @ytitle_pos, @box_height - 1, @ytitle,
            CDK::HORIZONTAL, 0, @ytitle_len)
      end

      # Draw in the Y axis high value.
      temp = "%d" % [@count]
      Draw.writeCharAttrib(@win, @box_width - temp.size - adj,
          @box_height - 2, temp, attrib, CDK::HORIZONTAL, 0, temp.size)

      # Draw in the Y axis low value.
      Draw.writeCharAttrib(@win, 3, @box_height - 2, "0", attrib,
          CDK::HORIZONTAL, 0, "0".size)

      # If the count is zero then there aren't any points.
      if @count == 0
        @win.wrefresh
        return
      end

      spacing = (@box_width - 3) / @count  # FIXME magic number (TITLE_LM)

      # Draw in the graph line/plot points.
      (0...@count).each do |y|
        colheight = (@values[y] / @xscale) - 1
        # Add the marker on the Y axis.
        @win.mvwaddch(@box_height - 3, (y + 1) * spacing + adj,
            Ncurses::ACS_TTEE)

        # If this is a plot graph, all we do is draw a dot.
        if @display_type == :PLOT
          xpos = @box_height - 4 - colheight
          ypos = (y + 1) * spacing + adj
          @win.mvwaddch(xpos, ypos, @graph_char[y])
        else
          (0..@yscale).each do |x|
            xpos = @box_height - 3
            ypos = (y + 1) * spacing - adj
            Draw.drawLine(@win, ypos, xpos - colheight, ypos, xpos,
                @graph_char[y])
          end
        end
      end

      # Draw in the axis corners.
      @win.mvwaddch(@title_lines, 2, Ncurses::ACS_URCORNER)
      @win.mvwaddch(@box_height - 3, 2, Ncurses::ACS_LLCORNER)
      @win.mvwaddch(@box_height - 3, @box_width, Ncurses::ACS_URCORNER)

      # Refresh and lets see it
      @win.wrefresh
    end

    def destroy
      self.cleanTitle
      self.cleanBindings(:GRAPH)
      CDK::SCREEN.unregister(:GRAPH, self)
      CDK.deleteCursesWindow(@win)
    end

    def erase
      if self.validCDKObject
        CDK.eraseCursesWindow(@win)
      end
    end

    def object_type
      :GRAPH
    end

    def position
      super(@win)
    end
  end

  class MENU < CDK::CDKOBJS
    TITLELINES = 1
    MAX_MENU_ITEMS = 30
    MAX_SUB_ITEMS = 98

    attr_reader :current_title, :current_subtitle
    attr_reader :sublist

    def initialize(cdkscreen, menu_list, menu_items, subsize,
        menu_location, menu_pos, title_attr, subtitle_attr)
      super()

      right_count = menu_items - 1
      rightloc = cdkscreen.window.getmaxx
      leftloc = 0
      xpos = cdkscreen.window.getbegx
      ypos = cdkscreen.window.getbegy
      ymax = cdkscreen.window.getmaxy
      
      # Start making a copy of the information.
      @screen = cdkscreen
      @box = false
      @accepts_focus = false
      rightcount = menu_items - 1
      @parent = cdkscreen.window
      @menu_items = menu_items
      @title_attr = title_attr
      @subtitle_attr = subtitle_attr
      @current_title = 0
      @current_subtitle = 0
      @last_selection = -1
      @menu_pos = menu_pos

      @pull_win = [nil] * menu_items
      @title_win = [nil] * menu_items
      @title = [''] * menu_items
      @title_len = [0] * menu_items
      @sublist = (1..menu_items).map {[nil] * subsize.max}.compact
      @sublist_len = (1..menu_items).map {
          [0] * subsize.max}.compact
      @subsize = [0] * menu_items


      # Create the pull down menus.
      (0...menu_items).each do |x|
        x1 = if menu_location[x] == CDK::LEFT
             then x
             else 
               rightcount -= 1
               rightcount + 1
             end
        x2 = 0
        y1 = if menu_pos == CDK::BOTTOM then ymax - 1 else 0 end
        y2 = if menu_pos == CDK::BOTTOM
             then ymax - subsize[x] - 2
             else CDK::MENU::TITLELINES
             end
        high = subsize[x] + CDK::MENU::TITLELINES

        # Limit the menu height to fit on the screen.
        if high + y2 > ymax
          high = ymax - CDK::MENU::TITLELINES
        end

        max = -1
        (CDK::MENU::TITLELINES...subsize[x]).to_a.each do |y|
          y0 = y - CDK::MENU::TITLELINES
          sublist_len = []
          @sublist[x1][y0] = CDK.char2Chtype(menu_list[x][y],
              sublist_len, [])
          @sublist_len[x1][y0] = sublist_len[0]
          max = [max, sublist_len[0]].max
        end

        if menu_location[x] == CDK::LEFT
          x2 = leftloc
        else
          x2 = (rightloc -= max + 2)
        end

        title_len = []
        @title[x1] = CDK.char2Chtype(menu_list[x][0], title_len, [])
        @title_len[x1] = title_len[0]
        @subsize[x1] = subsize[x] - CDK::MENU::TITLELINES
        @title_win[x1] = cdkscreen.window.subwin(CDK::MENU::TITLELINES,
            @title_len[x1] + 2, ypos + y1, xpos + x2)
        @pull_win[x1] = cdkscreen.window.subwin(high, max + 2,
            ypos + y2, xpos + x2)
        if @title_win[x1].nil? || @pull_win[x1].nil?
          self.destroy
          return nil
        end

        leftloc += @title_len[x] + 1
        @title_win[x1].keypad(true)
        @pull_win[x1].keypad(true)
      end
      @input_window = @title_win[@current_title]

      # Register this baby.
      cdkscreen.register(:MENU, self)
    end

    # This activates the CDK Menu
    def activate(actions)
      ret = 0

      # Draw in the screen.
      @screen.refresh

      # Display the menu titles.
      self.draw(@box)

      # Highlight the current title and window.
      self.drawSubwin

      # If the input string is empty this is an interactive activate.
      if actions.nil? || actions.size == 0
        @input_window = @title_win[@current_title]

        # Start taking input from the keyboard.
        while true
          input = self.getch([])

          # Inject the character into the widget.
          ret = self.inject(input)
          if @exit_type != :EARLY_EXIT
            return ret
          end
        end
      else
        actions.each do |action|
          if @exit_type != :EARLY_EXIT
            return ret
          end
        end
      end

      # Set the exit type and return.
      self.setExitType(0)
      return -1
    end

    def drawTitle(item)
      Draw.writeChtype(@title_win[item], 0, 0, @title[item],
          CDK::HORIZONTAL, 0, @title_len[item])
    end

    def drawItem(item, offset)
      Draw.writeChtype(@pull_win[@current_title], 1,
          item + CDK::MENU::TITLELINES - offset,
          @sublist[@current_title][item],
          CDK::HORIZONTAL, 0, @sublist_len[@current_title][item])
    end

    # Highlight the current sub-menu item
    def selectItem(item, offset)
      Draw.writeChtypeAttrib(@pull_win[@current_title], 1,
          item + CDK::MENU::TITLELINES - offset,
          @sublist[@current_title][item], @subtitle_attr,
          CDK::HORIZONTAL, 0, @sublist_len[@current_title][item])
    end

    def withinSubmenu(step)
      next_item = CDK::MENU.wrapped(@current_subtitle + step,
          @subsize[@current_title])

      if next_item != @current_subtitle
        ymax = @screen.window.getmaxy

        if 1 + @pull_win[@current_title].getbegy + @subsize[@current_title] >=
            ymax
          @current_subtitle = next_item
          self.drawSubwin
        else
          # Erase the old subtitle.
          self.drawItem(@current_subtitle, 0)

          # Set the values
          @current_subtitle = next_item

          # Draw the new sub-title.
          self.selectItem(@current_subtitle, 0)

          @pull_win[@current_title].wrefresh
        end

        @input_window = @title_win[@current_title]
      end
    end

    def acrossSubmenus(step)
      next_item = CDK::MENU.wrapped(@current_title + step, @menu_items)

      if next_item != @current_title
        # Erase the menu sub-window.
        self.eraseSubwin
        @screen.refresh

        # Set the values.
        @current_title = next_item
        @current_subtitle = 0

        # Draw the new menu sub-window.
        self.drawSubwin
        @input_window = @title_win[@current_title]
      end
    end

    # Inject a character into the menu widget.
    def inject(input)
      pp_return = 1
      ret = -1
      complete = false

      # Set the exit type.
      self.setExitType(0)

      # Check if there is a pre-process function to be called.
      unless @pre_process_func.nil?
        # Call the pre-process function.
        pp_return = @pre_process_func.call(:MENU, self,
            @pre_process_data, input)
      end

      # Should we continue?

      if pp_return != 0
        # Check for key bindings.
        if self.checkBind(:MENU, input)
          complete = true
        else
          case input
          when Ncurses::KEY_LEFT
            self.acrossSubmenus(-1)
          when Ncurses::KEY_RIGHT, CDK::KEY_TAB
            self.acrossSubmenus(1)
          when Ncurses::KEY_UP
            self.withinSubmenu(-1)
          when Ncurses::KEY_DOWN, ' '.ord
            self.withinSubmenu(1)
          when Ncurses::KEY_ENTER, CDK::KEY_RETURN
            self.cleanUpMenu
            self.setExitType(input)
            @last_selection = @current_title * 100 + @current_subtitle
            ret = @last_selection
            complete = true
          when CDK::KEY_ESC
            self.cleanUpMenu
            self.setExitType(input)
            @last_selection = -1
            ret = @last_selection
            complete = true
          when Ncurses::ERR
            self.setExitType(input)
            complete = true
          when CDK::REFRESH
            self.erase
            self.refresh
          end
        end

        # Should we call a post-process?
        if !complete && !(@post_process_func.nil?)
          @post_process_func.call(:MENU, self, @post_process_data, input)
        end
      end

      if !complete
        self.setExitType(0)
      end

      @result_data = ret
      return ret
    end

    # Draw a menu item subwindow
    def drawSubwin
      high = @pull_win[@current_title].getmaxy - 2
      x0 = 0
      x1 = @subsize[@current_title]

      if x1 > high
        x1 = high
      end

      if @current_subtitle >= x1
        x0 = @current_subtitle - x1 + 1
        x1 += x0
      end

      # Box the window
      @pull_win[@current_title]
      @pull_win[@current_title].box(Ncurses::ACS_VLINE, Ncurses::ACS_HLINE)
      if @menu_pos == CDK::BOTTOM
        @pull_win[@current_title].mvwaddch(@subsize[@current_title] + 1,
            0, Ncurses::ACS_LTEE)
      else
        @pull_win[@current_title].mvwaddch(0, 0, Ncurses::ACS_LTEE)
      end

      # Draw the items.
      (x0...x1).each do |x|
        self.drawItem(x, x0)
      end

      self.selectItem(@current_subtitle, x0)
      @pull_win[@current_title].wrefresh

      # Highlight the title.
      Draw.writeChtypeAttrib(@title_win[@current_title], 0, 0,
          @title[@current_title], @title_attr, CDK::HORIZONTAL,
          0, @title_len[@current_title])
      @title_win[@current_title].wrefresh
    end

    # Erase a menu item subwindow
    def eraseSubwin
      CDK.eraseCursesWindow(@pull_win[@current_title])

      # Redraw the sub-menu title.
      self.drawTitle(@current_title)
      @title_win[@current_title].wrefresh
    end

    # Draw the menu.
    def draw(box)
      # Draw in the menu titles.
      (0...@menu_items).each do |x|
        self.drawTitle(x)
        @title_win[x].wrefresh
      end
    end

    # Move the menu to the given location.
    def move(xplace, yplace, relative, refresh_flag)
      current_x = @screen.window.getbegx
      current_y = @screen.window.getbegy
      xpos = xplace
      ypos = yplace

      # if this is a relative move, then we will adjust where we want
      # to move to.
      if relative
        xpos = @screen.window.getbegx + xplace
        ypos = @screen.window.getbegy + yplace
      end

      # Adjust the window if we need to.
      xtmp = [xpos]
      ytmp = [ypos]
      CDK.alignxy(@screen.window, xtmp, ytmp,
          @screen.window.getmaxx, @screen.window.getmaxy)
      xpos = xtmp[0]
      ypos = ytmp[0]

      # Get the difference
      xdiff = current_x - xpos
      ydiff = current_y - ypos

      # Move the windows to the new location.
      CDK.moveCursesWindow(@screen.window, -xdiff, -ydiff)
      (0...@menu_items).each do |x|
        CDK.moveCursesWindow(@title_win[x], -xdiff, -ydiff)
      end

      # Touch the windows so they 'move.
      CDK::SCREEN.refresh(@screen.window)

      # Redraw the window, if they asked for it.
      if refresh_flag
        self.draw(@box)
      end
    end

    # Set the background attribute of the widget.
    def setBKattr(attrib)
      (0...@menu_items).each do |x|
        @title_win[x].wbkgd(attrib)
        @pull_win[x].wbkgd(attrib)
      end
    end

    # Destroy a menu widget.
    def destroy
      # Clean up the windows
      (0...@menu_items).each do |x|
        CDK.deleteCursesWindow(@title_win[x])
        CDK.deleteCursesWindow(@pull_win[x])
      end

      # Clean the key bindings.
      self.cleanBindings(:MENU)

      # Unregister the object
      CDK::SCREEN.unregister(:MENU, self)
    end

    # Erase the menu widget from the screen.
    def erase
      if self.validCDKObject
        (0...@menu_items).each do |x|
          @title_win[x].werase
          @title_win[x].wrefresh
          @pull_win[x].werase
          @pull_win[x].wrefresh
        end
      end
    end

    def set(menu_item, submenu_item, title_highlight, subtitle_highlight)
      self.setCurrentItem(menu_item, submenu_item)
      self.setTitleHighlight(title_highlight)
      self.setSubTitleHighlight(subtitle_highlight)
    end

    # Set the current menu item to highlight.
    def setCurrentItem(menuitem, submenuitem)
      @current_title = CDK::MENU.wrapped(menuitem, @menu_items)
      @current_subtitle = CDK::MENU.wrapped(
          submenuitem, @subsize[@current_title])
    end

    def getCurrentItem(menu_item, submenu_item)
      menu_item << @current_title
      submenu_item << @current_subtitle
    end

    # Set the attribute of the menu titles.
    def setTitleHighlight(highlight)
      @title_attr = highlight
    end

    def getTitleHighlight
      return @title_attr
    end

    # Set the attribute of the sub-title.
    def setSubTitleHighlight(highlight)
      @subtitle_attr = highlight
    end

    def getSubTitleHighlight
      return @subtitle_attr
    end

    # Exit the menu.
    def cleanUpMenu
      # Erase the sub-menu.
      self.eraseSubwin
      @pull_win[@current_title].wrefresh

      # Refresh the screen.
      @screen.refresh
    end

    def focus
      self.drawSubwin
      @input_window = @title_win[@current_title]
    end

    # The "%" operator is simpler but does not handle negative values
    def self.wrapped(within, limit)
      if within < 0
        within = limit - 1
      elsif within >= limit
        within = 0
      end
      return within
    end
          
    def object_type
      :MENU
    end
  end

  class ITEMLIST < CDK::CDKOBJS
    def initialize(cdkscreen, xplace, yplace, title, label, item, count,
        default_item, box, shadow)
      super()
      parent_width = cdkscreen.window.getmaxx
      parent_height = cdkscreen.window.getmaxy
      field_width = 0

      if !self.createList(item, count)
        self.destroy
        return nil
      end

      self.setBox(box)
      box_height = (@border_size * 2) + 1

      # Set some basic values of the item list
      @label = ''
      @label_len = 0
      @label_win = nil

      # Translate the label string to a chtype array
      if !(label.nil?) && label.size > 0
        label_len = []
        @label = CDK.char2Chtype(label, label_len, [])
        @label_len = label_len[0]
      end

      # Set the box width. Allow an extra char in field width for cursor
      field_width = self.maximumFieldWidth + 1
      box_width = field_width + @label_len + 2 * @border_size
      box_width = self.setTitle(title, box_width)
      box_height += @title_lines

      # Make sure we didn't extend beyond the dimensions of the window
      @box_width = [box_width, parent_width].min
      @box_height = [box_height, parent_height].min
      self.updateFieldWidth

      # Rejustify the x and y positions if we need to.
      xtmp = [xplace]
      ytmp = [yplace]
      CDK.alignxy(cdkscreen.window, xtmp, ytmp, box_width, box_height)
      xpos = xtmp[0]
      ypos = ytmp[0]

      # Make the window.
      @win = Ncurses::WINDOW.new(box_height, box_width, ypos, xpos)
      if @win.nil?
        self.destroy
        return nil
      end

      # Make the label window if there was a label.
      if @label.size > 0
        @label_win = @win.subwin(1, @label_len,
            ypos + @border_size + @title_lines,
            xpos + @border_size)

        if @label_win.nil?
          self.destroy
          return nil
        end
      end

      @win.keypad(true)

      # Make the field window.
      if !self.createFieldWin(
          ypos + @border_size + @title_lines,
          xpos + @label_len + @border_size)
        self.destroy
        return nil
      end

      # Set up the rest of the structure
      @screen = cdkscreen
      @parent = cdkscreen.window
      @shadow_win = nil
      @accepts_focus = true
      @shadow = shadow

      # Set the default item.
      if default_item >= 0 && default_item < @list_size
        @current_item = default_item
        @default_item = default_item
      else
        @current_item = 0
        @default_item = 0
      end

      # Do we want a shadow?
      if shadow
        @shadow_win = Ncurses::WINDOW.new(box_height, box_width,
            ypos + 1, xpos + 1)
        if @shadow_win.nil?
          self.destroy
          return nil
        end
      end

      # Register this baby.
      cdkscreen.register(:ITEMLIST, self)
    end

    # This allows the user to play with the widget.
    def activate(actions)
      ret = -1

      # Draw the widget.
      self.draw(@box)
      self.drawField(true)

      if actions.nil? || actions.size == 0
        input = 0
        
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

      # Set the exit type and exit.
      self.setExitType(0)
      return ret
    end

    # This injects a single character into the widget.
    def inject(input)
      pp_return = 1
      ret = -1
      complete = false

      # Set the exit type.
      self.setExitType(0)

      # Draw the widget field
      self.drawField(true)

      # Check if there is a pre-process function to be called.
      unless @pre_process_func.nil?
        pp_return = @pre_process_func.call(:ITEMLIST, self,
            @pre_process_data, input)
      end

      # Should we continue?
      if pp_return != 0
        # Check a predefined binding.
        if self.checkBind(:ITEMLIST, input)
          complete = true
        else
          case input
          when Ncurses::KEY_UP, Ncurses::KEY_RIGHT, ' '.ord, '+'.ord, 'n'.ord
            if @current_item < @list_size - 1
              @current_item += 1
            else
              @current_item = 0
            end
          when Ncurses::KEY_DOWN, Ncurses::KEY_LEFT, '-'.ord, 'p'.ord
            if @current_item > 0
              @current_item -= 1
            else
              @current_item = @list_size - 1
            end
          when 'd'.ord, 'D'.ord
            @current_item = @default_item
          when '0'.ord
            @current_item = 0
          when '$'.ord
            @current_item = @list_size - 1
          when CDK::KEY_ESC
            self.setExitType(input)
            complete = true
          when Ncurses::ERR
            self.setExitType(input)
            complete = true
          when CDK::KEY_TAB, CDK::KEY_RETURN, Ncurses::KEY_ENTER
            self.setExitType(input)
            ret = @current_item
            complete = true
          when CDK::REFRESH
            @screen.erase
            @screen.refresh
          else
            CDK.Beep
          end
        end

        # Should we call a post-process?
        if !complete && !(@post_process_func.nil?)
          @post_process_func.call(:ITEMLIST, self, @post_process_data, input)
        end
      end

      if !complete
        self.drawField(true)
        self.setExitType(0)
      end

      @result_data = ret
      return ret
    end

    # This moves the itemlist field to the given location.
    def move(xplace, yplace, relative, refresh_flag)
      current_x = @win.getbegx
      current_y = @win.getbegy
      xpos = xplace
      ypos = yplace

      # If this is a relative move, then we will adjust where we want
      # to move to
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
      CDK.moveCursesWindow(@field_win, -xdiff, -ydiff)
      CDK.moveCursesWindow(@label_win, -xdiff, -ydiff)
      CDK.moveCursesWindow(@shadow_win, -xdiff, -ydiff)

      # Touch the windows so they 'move'
      CDK::SCREEN.refreshCDKWindow(@screen.window)

      # Redraw the window, if they asked for it.
      if refresh_flag
        self.draw(@box)
      end
    end

    # This draws the widget on the screen.
    def draw(box)
      # Did we ask for a shadow?
      unless @shadow_win.nil?
        Draw.drawShadow(@shadow_win)
      end

      self.drawTitle(@win)

      # Draw in the label to the widget.
      unless @label_win.nil?
        Draw.writeChtype(@label_win, 0, 0, @label, CDK::HORIZONTAL,
            0, @label.size)
      end

      # Box the widget if asked.
      if box
        Draw.drawObjBox(@win, self)
      end

      @win.wrefresh

      # Draw in the field.
      self.drawField(false)
    end

    # This sets the background attribute of the widget
    def setBKattr(attrib)
      @win.wbkgd(attrib)
      @field_win.wbkgd(attrib)
      unless @label_win.nil?
        @label_win.wbkgd(attrib)
      end
    end

    # This function draws the contents of the field.
    def drawField(highlight)
      # Declare local vars.
      current_item = @current_item

      # Determine how much we have to draw.
      len = [@item_len[current_item], @field_width].min

      # Erase the field window.
      @field_win.werase

      # Draw in the current item in the field.
      (0...len).each do |x|
        c = @item[current_item][x]

        if highlight
          c = c.ord | Ncurses::A_REVERSE
        end

        @field_win.mvwaddch(0, x + @item_pos[current_item], c)
      end

      # Redraw the field window.
      @field_win.wrefresh
    end

    # This function removes the widget from the screen.
    def erase
      if self.validCDKObject
        CDK.eraseCursesWindow(@field_win)
        CDK.eraseCursesWindow(@label_win)
        CDK.eraseCursesWindow(@win)
        CDK.eraseCursesWindow(@shadow_win)
      end
    end

    def destroyInfo
      @list_size = 0
      @item = ''
    end

    # This function destroys the widget and all the memory it used.
    def destroy
      self.cleanTitle
      self.destroyInfo

      # Delete the windows
      CDK.deleteCursesWindow(@field_win)
      CDK.deleteCursesWindow(@label_win)
      CDK.deleteCursesWindow(@shadow_win)
      CDK.deleteCursesWindow(@win)

      # Clean the key bindings.
      self.cleanBindings(:ITEMLIST)

      CDK::SCREEN.unregister(:ITEMLIST, self)
    end

    # This sets multiple attributes of the widget.
    def set(list, count, current, box)
      self.setValues(list, count, current)
      self.setBox(box)
    end

    # This function sets the contents of the list
    def setValues(item, count, default_item)
      if self.createList(item, count)
        old_width = @field_width

        # Set the default item.
        if default_item >= 0 && default_item < @list_size
          @current_item = default_item
          @default_item = default_item
        end

        # This will not resize the outer windows but can still make a usable
        # field width if the title made the outer window wide enough
        self.updateFieldWidth
        if @field_width > old_width
          self.createFieldWin(@field_win.getbegy, @field_win.getbegx)
        end

        # Draw the field.
        self.erase
        self.draw(@box)
      end
    end

    def getValues(size)
      size << @list_size
      return @item
    end

    # This sets the default/current item of the itemlist
    def setCurrentItem(current_item)
      # Set the default item.
      if current_item >= 0 && current_item < @list_size
        @current_item = current_item
      end
    end

    def getCurrentItem
      return @current_item
    end

    # This sets the default item in the list.
    def setDefaultItem(default_item)
      # Make sure the item is in the correct range.
      if default_item < 0
        @default_item = 0
      elsif default_item >= @list_size
        @default_item = @list_size - 1
      else
        @default_item = default_item
      end
    end
    
    def getDefaultItem
      return @default_item
    end

    def focus
      self.drawField(true)
    end

    def unfocus
      self.drawField(false)
    end

    def createList(item, count)
      status = false
      new_items = []
      new_pos = []
      new_len = []
      if count >= 0
        field_width = 0

        # Go through the list and determine the widest item.
        status = true
        (0...count).each do |x|
          # Copy the item to the list.
          lentmp = []
          postmp = []
          new_items << CDK.char2Chtype(item[x], lentmp, postmp)
          new_len << lentmp[0]
          new_pos << postmp[0]
          if new_items[0] == 0
            status = false
            break
          end
          field_width = [field_width, new_len[x]].max
        end

        # Now we need to justify the strings.
        (0...count).each do |x|
          new_pos[x] = CDK.justifyString(field_width + 1,
              new_len[x], new_pos[x])
        end

        if status
          self.destroyInfo

          # Copy in the new information
          @list_size = count
          @item = new_items
          @item_pos = new_pos
          @item_len = new_len
        end
      else
        self.destroyInfo
        status = true
      end

      return status
    end

    # Go through the list and determine the widest item.
    def maximumFieldWidth
      max_width = -2**30

      (0...@list_size).each do |x|
        max_width = [max_width, @item_len[x]].max
      end
      max_width = [max_width, 0].max

      return max_width
    end

    def updateFieldWidth
      want = self.maximumFieldWidth + 1
      have = @box_width - @label_len - 2 * @border_size
      @field_width = [want, have].min
    end

    # Make the field window.
    def createFieldWin(ypos, xpos)
      @field_win = @win.subwin(1, @field_width, ypos, xpos)
      unless @field_win.nil?
        @field_win.keypad(true)
        @input_window = @field_win
        return true
      end
      return false
    end

    def position
      super(@win)
    end

    def object_type
      :ITEMLIST
    end
  end

  class RADIO < CDK::SCROLLER
    def initialize(cdkscreen, xplace, yplace, splace, height, width, title,
        list, list_size, choice_char, def_item, highlight, box, shadow)
      super()
      parent_width = cdkscreen.window.getmaxx
      parent_height = cdkscreen.window.getmaxy
      box_width = width
      box_height = height
      widest_item = 0

      bindings = {
        CDK::BACKCHAR => Ncurses::KEY_PPAGE,
        CDK::FORCHAR  => Ncurses::KEY_NPAGE,
        'g'           => Ncurses::KEY_HOME,
        '1'           => Ncurses::KEY_HOME,
        'G'           => Ncurses::KEY_END,
        '<'           => Ncurses::KEY_HOME,
        '>'           => Ncurses::KEY_END,
      }
      
      self.setBox(box)

      # If the height is a negative value, height will be ROWS-height,
      # otherwise the height will be the given height.
      box_height = CDK.setWidgetDimension(parent_height, height, 0)

      # If the width is a negative value, the width will be COLS-width,
      # otherwise the width will be the given width.
      box_width = CDK.setWidgetDimension(parent_width, width, 5)

      box_width = self.setTitle(title, box_width)

      # Set the box height.
      if @title_lines > box_height
        box_height = @title_lines + [list_size, 8].min + 2 * @border_size
      end

      # Adjust the box width if there is a scroll bar.
      if splace == CDK::LEFT || splace == CDK::RIGHT
        box_width += 1
        @scrollbar = true
      else
        scrollbar = false
      end

      # Make sure we didn't extend beyond the dimensions of the window
      @box_width = [box_width, parent_width].min
      @box_height = [box_height, parent_height].min

      self.setViewSize(list_size)

      # Each item in the needs to be converted to chtype array
      widest_item = self.createList(list, list_size, @box_width)
      if widest_item > 0
        self.updateViewWidth(widest_item)
      elsif list_size > 0
        self.destroy
        return nil
      end

      # Rejustify the x and y positions if we need to.
      xtmp = [xplace]
      ytmp = [yplace]
      CDK.alignxy(cdkscreen.window, xtmp, ytmp, @box_width, @box_height)
      xpos = xtmp[0]
      ypos = ytmp[0]

      # Make the radio window
      @win = Ncurses::WINDOW.new(@box_height, @box_width, ypos, xpos)

      # Is the window nil?
      if @win.nil?
        self.destroy
        return nil
      end

      # Turn on the keypad.
      @win.keypad(true)

      # Create the scrollbar window.
      if splace == CDK::RIGHT
        @scrollbar_win = @win.subwin(self.maxViewSize, 1,
            self.SCREEN_YPOS(ypos), xpos + @box_width - @border_size - 1)
      elsif splace == CDK::LEFT
        @scrollbar_win = @win.subwin(self.maxViewSize, 1,
            self.SCREEN_YPOS(ypos), self.SCREEN_XPOS(xpos))
      else
        @scrollbar_win = nil
      end

      # Set the rest of the variables
      @screen = cdkscreen
      @parent = cdkscreen.window
      @scrollbar_placement = splace
      @widest_item = widest_item
      @left_char = 0
      @selected_item = 0
      @highlight = highlight
      @choice_char = choice_char.ord
      @left_box_char = '['.ord
      @right_box_char = ']'.ord
      @def_item = def_item
      @input_window = @win
      @accepts_focus = true
      @shadow = shadow

      self.setCurrentItem(0)

      # Do we need to create the shadow?
      if shadow
        @shadow_win = Ncurses::WINDOW.new(box_height, box_width + 1,
            ypos + 1, xpos + 1)
      end

      # Setup the key bindings
      bindings.each do |from, to|
        self.bind(:RADIO, from, :getc, to)
      end

      cdkscreen.register(:RADIO, self)
    end

    # Put the cursor on the currently-selected item.
    def fixCursorPosition
      scrollbar_adj = if @scrollbar_placement == CDK::LEFT then 1 else 0 end
      ypos = self.SCREEN_YPOS(@current_item - @current_top)
      xpos = self.SCREEN_XPOS(0) + scrollbar_adj

      @input_window.wmove(ypos, xpos)
      @input_window.wrefresh
    end

    # This actually manages the radio widget.
    def activate(actions)
      # Draw the radio list.
      self.draw(@box)

      if actions.nil? || actions.size == 0
        while true
          self.fixCursorPosition
          input = self.getch([])

          # Inject the character into the widget.
          ret = self.inject(input)
          if @exit_type != :EARLY_EXIT
            return ret
          end
        end
      else
        actions.each do |action|
          ret = self.inject(action)
          if @exit_type != :EARLY_EXIT
            return ret
          end
        end
      end

      # Set the exit type and return
      self.setExitType(0)
      return -1
    end

    # This injects a single character into the widget.
    def inject(input)
      pp_return = 1
      ret = -1
      complete = false

      # Set the exit type
      self.setExitType(0)

      # Draw the widget list
      self.drawList(@box)

      # Check if there is a pre-process function to be called
      unless @pre_process_func.nil?
        # Call the pre-process function.
        pp_return = @pre_process_func.call(:RADIO, self,
            @pre_process_data, input)
      end

      # Should we continue?
      if pp_return != 0
        # Check for a predefined key binding.
        if self.checkBind(:RADIO, input)
          complete = true
        else
          case input
          when Ncurses::KEY_UP
            self.KEY_UP
          when Ncurses::KEY_DOWN
            self.KEY_DOWN
          when Ncurses::KEY_RIGHT
            self.KEY_RIGHT
          when Ncurses::KEY_LEFT
            self.KEY_LEFT
          when Ncurses::KEY_PPAGE
            self.KEY_PPAGE
          when Ncurses::KEY_NPAGE
            self.KEY_NPAGE
          when Ncurses::KEY_HOME
            self.KEY_HOME
          when Ncurses::KEY_END
            self.KEY_END
          when '$'.ord
            @left_char = @max_left_char
          when '|'.ord
            @left_char = 0
          when ' '.ord
            @selected_item = @current_item
          when CDK::KEY_ESC
            self.setExitType(input)
            ret = -1
            complete = true
          when Ncurses::ERR
            self.setExitType(input)
            complete = true
          when CDK::KEY_TAB, CDK::KEY_RETURN, Ncurses::KEY_ENTER
            self.setExitType(input)
            ret = @selected_item
            complete = true
          when CDK::REFRESH
            @screen.erase
            @screen.refresh
          end
        end

        # Should we call a post-process?
        if !complete && !(@post_process_func.nil?)
          @post_process_func.call(:RADIO, self, @post_process_data, input)
        end
      end

      if !complete
        self.drawList(@box)
        self.setExitType(0)
      end

      self.fixCursorPosition
      @return_data = ret
      return ret
    end

    # This moves the radio field to the given location.
    def move(xplace, yplace, relative, refresh_flag)
      current_x = @win.getbegx
      current_y = @win.getbegy
      xpos = xplace
      ypos = yplace

      # If this is a relative move, then we will adjust where we want
      # to move to.
      if relative
        xpos = @win.getbegx + xplace
        ypos = @win.getbegy + yplace
      end

      # Adjust the window if we need to.
      xtmp = []
      ytmp = []
      CDK.alignxy(@win, xtmp, ytmp, @box_width, @box_height)
      xpos = xtmp[0]
      ypos = ytmp[0]

      # Get the difference.
      xdiff = current_x - xpos
      ydiff = current_y - ypos

      # Move the window to the new location.
      CDK.moveCursesWindow(@win, -xdiff, -ydiff)
      CDK.moveCursesWindow(@scrollbar_win, -xdiff, -ydiff)
      CDK.moveCursesWindow(@shadow_win, -xdiff, -ydiff)

      # Touch the windows so they 'move'.
      @screen.window.refresh

      # Redraw the window, if they asked for it.
      if refresh_flag
        self.draw(@box)
      end
    end

    # This function draws the radio widget.
    def draw(box)
      # Do we need to draw in the shadow?
      if !(@shadow_win.nil?)
        Draw.drawShadow(@shadow_win)
      end

      self.drawTitle(@win)

      # Draw in the radio list.
      self.drawList(@box)
    end

    # This redraws the radio list.
    def drawList(box)
      scrollbar_adj = if @scrollbar_placement == CDK::LEFT then 1 else 0 end
      screen_pos = 0

      # Draw the list
      (0...@view_size).each do |j|
        k = j + @current_top
        if k < @list_size
          xpos = self.SCREEN_XPOS(0)
          ypos = self.SCREEN_YPOS(j)

          screen_pos = self.SCREENPOS(k, scrollbar_adj)

          # Draw the empty string.
          Draw.writeBlanks(@win, xpos, ypos, CDK::HORIZONTAL, 0,
              @box_width - @border_size)

          # Draw the line.
          Draw.writeChtype(@win,
              if screen_pos >= 0 then screen_pos else 1 end,
              ypos, @item[k], CDK::HORIZONTAL,
              if screen_pos >= 0 then 0 else 1 - screen_pos end,
              @item_len[k])

          # Draw the selected choice
          xpos += scrollbar_adj
          @win.mvwaddch(ypos, xpos, @left_box_char)
          @win.mvwaddch(ypos, xpos + 1,
              if k == @selected_item then @choice_char else ' '.ord end)
          @win.mvwaddch(ypos, xpos + 2, @right_box_char)
        end
      end

      # Highlight the current item
      if @has_focus
        k = @current_item
        if k < @list_size
          screen_pos = self.SCREENPOS(k, scrollbar_adj)
          ypos = self.SCREEN_YPOS(@current_high)

          Draw.writeChtypeAttrib(@win,
              if screen_pos >= 0 then screen_pos else 1 + scrollbar_adj end,
              ypos, @item[k], @highlight, CDK::HORIZONTAL,
              if screen_pos >= 0 then 0 else 1 - screen_pos end,
              @item_len[k])
        end
      end

      if @scrollbar
        @toggle_pos = (@current_item * @step).floor
        @toggle_pos = [@toggle_pos, @scrollbar_win.getmaxy - 1].min

        @scrollbar_win.mvwvline(0, 0, Ncurses::ACS_CKBOARD,
            @scrollbar_win.getmaxy)
        @scrollbar_win.mvwvline(@toggle_pos, 0, ' '.ord | Ncurses::A_REVERSE,
            @toggle_size)
      end

      # Box it if needed.
      if box
        Draw.drawObjBox(@win, self)
      end

      self.fixCursorPosition
    end

    # This sets the background attribute of the widget.
    def setBKattr(attrib)
      @win.wbkgd(attrib)
      unless @scrollbar_win.nil?
        @scrollbar_win.wbkgd(attrib)
      end
    end

    def destroyInfo
      @item = ''
    end

    # This function destroys the radio widget.
    def destroy
      self.cleanTitle
      self.destroyInfo

      # Clean up the windows.
      CDK.deleteCursesWindow(@scrollbar_win)
      CDK.deleteCursesWindow(@shadow_win)
      CDK.deleteCursesWindow(@win)

      # Clean up the key bindings.
      self.cleanBindings(:RADIO)

      # Unregister this object.
      CDK::SCREEN.unregister(:RADIO, self)
    end

    # This function erases the radio widget
    def erase
      if self.validCDKObject
        CDK.eraseCursesWindow(@win)
        CDK.eraseCursesWindow(@shadow_win)
      end
    end

    # This sets various attributes of the radio list.
    def set(highlight, choice_char, box)
      self.setHighlight(highlight)
      self.setChoiceCHaracter(choice_char)
      self.setBox(box)
    end

    # This sets the radio list items.
    def setItems(list, list_size)
      widest_item = self.createList(list, list_size, @box_width)
      if widest_item <= 0
        return
      end

      # Clean up the display.
      (0...@view_size).each do |j|
        Draw.writeBlanks(@win, self.SCREEN_XPOS(0), self.SCREEN_YPOS(j),
            CDK::HORIZONTAL, 0, @box_width - @border_size)
      end

      self.setViewSize(list_size)

      self.setCurrentItem(0)
      @left_char = 0
      @selected_item = 0

      self.updateViewWidth(widest_item)
    end

    def getItems(list)
      (0...@list_size).each do |j|
        list << CDK.chtype2Char(@item[j])
      end
      return @list_size
    end

    # This sets the highlight bar of the radio list.
    def setHighlight(highlight)
      @highlight = highlight
    end

    def getHighlight
      return @highlight
    end

    # This sets the character to use when selecting na item in the list.
    def setChoiceCharacter(character)
      @choice_char = character
    end

    def getChoiceCharacter
      return @choice_char
    end

    # This sets the character to use to drw the left side of the choice box
    # on the list
    def setLeftBrace(character)
      @left_box_char = character
    end

    def getLeftBrace
      return @left_box_char
    end

    # This sets the character to use to draw the right side of the choice box
    # on the list
    def setRightBrace(character)
      @right_box_char = character
    end

    def getRightBrace
      return @right_box_char
    end

    # This sets the current highlighted item of the widget
    def setCurrentItem(item)
      self.setPosition(item)
      @selected_item = item
    end

    def getCurrentItem
      return @current_item
    end

    # This sets the selected item of the widget
    def setSelectedItem(item)
      @selected_item = item
    end

    def getSelectedItem
      return @selected_item
    end

    def focus
      self.drawList(@box)
    end

    def unfocus
      self.drawList(@box)
    end

    def createList(list, list_size, box_width)
      status = false
      widest_item = 0

      if list_size >= 0
        new_list = []
        new_len = []
        new_pos = []

        # Each item in the needs to be converted to chtype array
        status = true
        box_width -= 2 + @border_size
        (0...list_size).each do |j|
          lentmp = []
          postmp = []
          new_list << CDK.char2Chtype(list[j], lentmp, postmp)
          new_len << lentmp[0]
          new_pos << postmp[0]
          if new_list[j].nil? || new_list[j].size == 0
            status = false
            break
          end
          new_pos[j] = CDK.justifyString(box_width, new_len[j], new_pos[j]) + 3
          widest_item = [widest_item, new_len[j]].max
        end
        if status
          self.destroyInfo
          @item = new_list
          @item_len = new_len
          @item_pos = new_pos
        end
      end

      return (if status then widest_item else 0 end)
    end

    # Determine how many characters we can shift to the right
    # before all the items have been scrolled off the screen.
    def AvailableWidth
      @box_width - 2 * @border_size - 3
    end

    def updateViewWidth(widest)
      @max_left_char = if @box_width > widest
                       then 0
                       else widest - self.AvailableWidth
                       end
    end

    def WidestItem
      @max_left_char + self.AvailableWidth
    end

    def SCREENPOS(n, scrollbar_adj)
      @item_pos[n] - @left_char + scrollbar_adj + @border_size
    end

    def object_type
      :RADIO
    end
  end

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
    def move(xplace, yplace, relative, refresh_flag)
      current_x = @win.getbegx
      current_y = @win.getbegy
      xpos = xplace
      ypos = yplace

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

  class MENTRY < CDK::CDKOBJS
    attr_accessor :info, :current_col, :current_row, :top_row
    attr_reader :disp_type, :field_width, :rows, :field_win

    def initialize(cdkscreen, xplace, yplace, title, label, field_attr,
        filler, disp_type, f_width, f_rows, logical_rows, min, box, shadow)
      super()
      parent_width = cdkscreen.window.getmaxx
      parent_height = cdkscreen.window.getmaxy
      field_width = f_width
      field_rows = f_rows

      self.setBox(box)

      # If the field_width is a negative value, the field_width will be
      # COLS-field_width, otherwise the field_width will be the given width.
      field_width = CDK.setWidgetDimension(parent_width, field_width, 0)
 
      # If the field_rows is a negative value, the field_rows will be
      # ROWS-field_rows, otherwise the field_rows will be the given rows.
      field_rows = CDK.setWidgetDimension(parent_width, field_rows, 0)
      box_height = field_rows + 2

      # Set some basic values of the mentry field
      @label = ''
      @label_len = 0
      @label_win = nil
      
      # We need to translate the string label to a chtype array
      if label.size > 0
        label_len = []
        @label = CDK.char2Chtype(label, label_len, [])
        @label_len = label_len[0]
      end
      box_width = @label_len + field_width + 2
      
      old_width = box_width
      box_width = self.setTitle(title, box_width)
      horizontal_adjust = (box_width - old_width) / 2

      box_height += @title_lines

      # Make sure we didn't extend beyond the parent window.
      box_width = [box_width, parent_width].min
      box_height = [box_height, parent_height].min
      field_width = [box_width - @label_len - 2, field_width].min
      field_rows = [box_height - @title_lines - 2, field_rows].min

      # Rejustify the x and y positions if we need to.
      xtmp = [xplace]
      ytmp = [yplace]
      CDK.alignxy(cdkscreen.window, xtmp, ytmp, box_width, box_height)
      xpos = xtmp[0]
      ypos = ytmp[0]

      # Make the label window.
      @win = Ncurses::WINDOW.new(box_height, box_width, ypos, xpos)

      # Is the window nil?
      if @win.nil?
        self.destroy
        return nil
      end

      # Create the label window.
      if @label.size > 0
        @label_win = @win.subwin(field_rows, @label_len + 2,
            ypos + @title_lines + 1, xpos + horizontal_adjust + 1)
      end

      # make the field window.
      @field_win = @win.subwin(field_rows, field_width,
          ypos + @title_lines + 1, xpos + @label_len + horizontal_adjust + 1)

      # Turn on the keypad.
      @field_win.keypad(true)
      @win.keypad(true)

      # Set up the rest of the structure.
      @parent = cdkscreen.window
      @total_width = (field_width * logical_rows) + 1

      # Create the info string
      @info = ''

      # Set up the rest of the widget information.
      @screen = cdkscreen
      @shadow_win = nil
      @field_attr = field_attr
      @field_width = field_width
      @rows = field_rows
      @box_height = box_height
      @box_width = box_width
      @filler = filler.ord
      @hidden = filler.ord
      @input_window = @win
      @accepts_focus = true
      @current_row = 0
      @current_col = 0
      @top_row = 0
      @shadow = shadow
      @disp_type = disp_type
      @min = min
      @logical_rows = logical_rows

      # This is a generic character parser for the mentry field. It is used as
      # a callback function, so any personal modifications can be made by
      # creating a new function and calling that one the mentry activation.
      mentry_callback = lambda do |mentry, character|
        cursor_pos = mentry.getCursorPos
        newchar = Display.filterByDisplayType(mentry.disp_type, character)

        if newchar == Ncurses::ERR
          CDK.Beep
        else
          mentry.info = mentry.info[0...cursor_pos] + newchar.chr +
              mentry.info[cursor_pos..-1]
          mentry.current_col += 1

          mentry.drawField

          # Have we gone out of bounds
          if mentry.current_col >= mentry.field_width
            # Update the row and col values.
            mentry.current_col = 0
            mentry.current_row += 1

            # If we have gone outside of the visual boundaries, we
            # need to scroll the window.
            if mentry.current_row == mentry.rows
              # We have to redraw the screen
              mentry.current_row -= 1
              mentry.top_row += 1
              mentry.drawField
            end
            mentry.field_win.wmove(mentry.current_row, mentry.current_col)
            mentry.field_win.wrefresh
          end
        end
      end
      @callbackfn = mentry_callback

      # Do we need to create a shadow.
      if shadow
        @shadow_win = Ncurses::WINDOW.new(box_height, box_width,
            ypos + 1, xpos + 1)
      end

      # Register
      cdkscreen.register(:MENTRY, self)
    end

    # This actually activates the mentry widget...
    def activate(actions)
      input = 0

      # Draw the mentry widget.
      self.draw(@box)

      if actions.size == 0
        while true
          input = self.getch([])

          # Inject this character into the widget.
          ret = self.inject(input)
          if @exit_type != :EARLY_EXIT
            return ret
          end
        end
      else
        actions.each do |action|
          ret = self.inject(action)
          if @exit_type != :EARLY_EXIT
            return ret
          end
        end
      end

      # Set the exit type and exit.
      self.setExitType(0)
      return 0
    end

    def setTopRow(row)
      if @top_row != row
        @top_row = row
        return true
      end
      return false
    end

    def setCurPos(row, col)
      if @current_row != row || @current_col != col
        @current_row = row
        @current_col = col
        return true
      end
      return false
    end

    def KEY_LEFT(moved, redraw)
      result = true
      if @current_col != 0
        moved[0] = self.setCurPos(@current_row, @current_col - 1)
      elsif @current_row == 0
        if @top_row != 0
          moved[0] = self.setCurPos(@current_row, @field_width - 1)
          redraw[0] = self.setTopRow(@top_row - 1)
        end
      else
        moved[0] = self.setCurPos(@current_row - 1, @field_width - 1)
      end

      if !moved[0] && !redraw[0]
        CDK.Beep
        result = false
      end
      return result
    end

    def getCursorPos
      return (@current_row + @top_row) * @field_width + @current_col
    end

    # This injects a character into the widget.
    def inject(input)
      cursor_pos = self.getCursorPos
      pp_return = 1
      ret = -1
      complete = false

      # Set the exit type.
      self.setExitType(0)

      # Refresh the field.
      self.drawField

      # Check if there is a pre-process function to be called.
      unless @pre_process_func.nil?
        # Call the pre-process function
        pp_return = @pre_process_func.call(:MENTRY, self,
            @pre_process_data, input)
      end

      # Should we continue?
      if pp_return != 0
        # Check for a key binding...
        if self.checkBind(:MENTRY, input)
          complete = true
        else
          moved = false
          redraw = false

          case input
          when Ncurses::KEY_HOME
            moved = self.setCurPos(0, 0)
            redraw = self.setTopRow(0)
          when Ncurses::KEY_END
            field_characters = @rows * @field_width
            if @info.size < field_characters
              redraw = self.setTopRow(0)
              moved = self.setCurPos(
                  @info.size / @field_width, @info.size % @field_width)
            else
              redraw = self.setTopRow(@info.size / @field_width, @rows + 1)
              moved = self.setCurPos(@rows - 1, @info.size % @field_width)
            end
          when Ncurses::KEY_LEFT
            mtmp = [moved]
            rtmp = [redraw]
            self.KEY_LEFT(mtmp, rtmp)
            moved = mtmp[0]
            redraw = rtmp[0]
          when Ncurses::KEY_RIGHT
            if @current_col < @field_width - 1
              if self.getCursorPos + 1 <= @info.size
                moved = self.setCurPos(@current_row, @current_col + 1)
              end
            elsif @current_row == @rows - 1
              if @top_row + @current_row + 1 < @logical_rows
                moved = self.setCurPos(@current_row, 0)
                redraw = self.setTopRow(@top_row + 1)
              end
            else
              moved = self.setCurPos(@current_row + 1, 0)
            end
            if !moved && !redraw
              CDK.Beep
            end
          when Ncurses::KEY_DOWN
            if @current_row != @rows - 1
              if self.getCursorPos + @field_width + 1 <= @info.size
                moved = self.setCurPos(@current_row + 1, @current_col)
              end
            elsif @top_row < @logical_rows - @rows
              if (@top_row + @current_row + 1) * @field_width <= @info.size
                redraw = self.setTopRow(@top_row + 1)
              end
            end
            if !moved && !redraw
              CDK.Beep
            end
          when Ncurses::KEY_UP
            if @current_row != 0
              moved = self.setCurPos(@current_row - 1, @current_col)
            elsif @top_row != 0
              redraw = self.setTopRow(@top_row - 1)
            end
            if !moved && !redraw
              CDK.Beep
            end
          when Ncurses::KEY_BACKSPACE, Ncurses::KEY_DC
            if @disp_type == :VIEWONLY
              CDK.Beep
            elsif @info.length == 0
              CDK.Beep
            elsif input == Ncurses::KEY_DC
              cursor_pos = self.getCursorPos
              if cursor_pos < @info.size
                @info = @info[0...cursor_pos] + @info[cursor_pos + 1..-1]
                self.drawField
              else
                CDK.Beep
              end
            else
              mtmp = [moved]
              rtmp = [redraw]
              hKL = self.KEY_LEFT(mtmp, rtmp)
              moved = mtmp[0]
              rtmp = [redraw]
              if hKL
                cursor_pos = self.getCursorPos
                if cursor_pos < @info.size
                  @info = @info[0...cursor_pos] + @info[cursor_pos + 1..-1]
                  self.drawField
                else
                  CDK.Beep
                end
              end
            end
          when CDK::TRANSPOSE
            if cursor_pos >= @info.size - 1
              CDK.Beep
            else
              holder = @info[cursor_pos]
              @info[cursor_pos] = @info[cursor_pos + 1]
              @info[cursor_pos + 1] = holder
              self.drawField
            end
          when CDK::ERASE
            if @info.size != 0
              self.clean
              self.drawField
            end
          when CDK::CUT
            if @info.size == 0
              CDK.Beep
            else
              @@g_paste_buffer = @info.clone
              self.clean
              self.drawField
            end
          when CDK::COPY
            if @info.size == 0
              CDK.Beep
            else
              @@g_paste_buffer = @info.clone
            end
          when CDK::PASTE
            if @@g_paste_buffer.size == 0
              CDK.Beep
            else
              self.setValue(@@g_paste_buffer)
              self.draw(@box)
            end
          when CDK::KEY_TAB, CDK::KEY_RETURN, Ncurses::KEY_ENTER
            if @info.size < @min + 1
              CDK.Beep
            else
              self.setExitType(input)
              ret = @info
              complete = true
            end
          when Ncurses::ERR
            self.setExitType(input)
            complete = true
          when CDK::KEY_ESC
            self.setExitType(input)
            complete = true
          when CDK::REFRESH
            @screen.erase
            @screen.refresh
          else
            if @disp_type == :VIEWONLY || @info.size >= @total_width
              CDK.Beep
            else
              @callbackfn.call(self, input)
            end
          end

          if redraw
            self.drawField
          elsif moved
            @field_win.wmove(@current_row, @current_col)
            @field_win.wrefresh
          end
        end

        # Should we do a post-process?
        if !complete && !(@post_process_func.nil?)
          @post_process_func.call(:MENTRY, self, @post_process_data, input)
        end
      end

      if !complete
        self.setExitType(0)
      end

      @result_data = ret
      return ret
    end

    # This moves the mentry field to the given location.
    def move(xplace, yplace, relative, refresh_flag)
      current_x = @win.getbegx
      current_y = @win.getbegy
      xpos = xplace
      ypos = yplace

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

      # Move the window to the new location.
      CDK.moveCursesWindow(@win, -xdiff, -ydiff)
      CDK.moveCursesWindow(@field_win, -xdiff, -ydiff)
      CDK.moveCursesWindow(@label_win, -xdiff, -ydiff)
      CDK.moveCursesWindow(@shadow_win, -xdiff, -ydiff)

      # Touch the windows so they 'move'.
      CDK::SCREEN.refreshCDKWindow(@screen.window)

      # Redraw the window, if they asked for it.
      if refresh_flag
        self.draw(@box)
      end
    end

    # This function redraws the multiple line entry field.
    def drawField
      currchar = @field_width * @top_row
  
      self.drawTitle(@win)
      @win.wrefresh
  
      lastpos = @info.size
  
      # Start redrawing the fields.
      (0...@rows).each do |x|
        (0...@field_width).each do |y|
          if currchar < lastpos
            if Display.isHiddenDisplayType(@disp_type)
              @field_win.mvwaddch(x, y, @filler)
            else
              @field_win.mvwaddch(x, y, @info[currchar].ord | @field_attr)
              currchar += 1
            end
          else
            @field_win.mvwaddch(x, y, @filler)
          end
        end
      end
  
      # Refresh the screen.
      @field_win.wmove(@current_row, @current_col)
      @field_win.wrefresh
    end
  
    # This function draws the multiple line entry field.
    def draw(box)
      # Box the widget if asked.
      if box
        Draw.drawObjBox(@win, self)
        @win.wrefresh
      end
  
      # Do we need to draw in the shadow?
      unless @shadow_win.nil?
        Draw.drawShadow(@shadow_win)
      end
  
      # Draw in the label to the widget.
      unless @label_win.nil?
        Draw.writeChtype(@label_win, 0, 0, @label, CDK::HORIZONTAL,
            0, @label_len)
        @label_win.wrefresh
      end
  
      # Draw the mentry field
      self.drawField
    end
  
    # This sets the background attribute of the widget.
    def setBKattr(attrib)
      @win.wbkgd(attrib)
      @field_win.wbkgd(attrib)
      unless @label_win.nil?
        @label_win.wbkgd(attrib)
      end
    end
  
    # This function erases the multiple line entry field from the screen.
    def erase
      if self.validCDKObject
        CDK.eraseCursesWindow(@field_win)
        CDK.eraseCursesWindow(@label_win)
        CDK.eraseCursesWindow(@win)
        CDK.eraseCursesWindow(@shadow_win)
      end
    end
  
    # This function destroys a multiple line entry field widget.
    def destroy
      self.cleanTitle
  
      # Clean up the windows.
      CDK.deleteCursesWindow(@field_win)
      CDK.deleteCursesWindow(@label_win)
      CDK.deleteCursesWindow(@shadow_win)
      CDK.deleteCursesWindow(@win)
  
      # Clean the key bindings.
      self.cleanBindings(:MENTRY)
  
      # Unregister this object.
      CDK::SCREEN.unregister(:MENTRY, self)
    end
  
    # This sets multiple attributes of the widget.
    def set(value, min, box)
      self.setValue(value)
      self.setMin(min)
      self.setBox(box)
    end
  
    # This removes the old information in the entry field and keeps the
    # new information given.
    def setValue(new_value)
      field_characters = @rows * @field_width
  
      @info = new_value
  
      # Set the cursor/row info
      if new_value.size < field_characters
        @top_row = 0
        @current_row = new_value.size / @field_width
        @current_col = new_value.size % @field_width
      else
        row_used = new_value.size / @field_width
        @top_row = row_used - @rows + 1
        @current_row = @rows - 1
        @current_col = new_value.size % @field_width
      end
  
      # Redraw the widget.
      self.drawField
    end
  
    def getValue
      return @info
    end
  
    # This sets the filler character to use when drawing the widget.
    def setFillerChar(filler)
      @filler = filler.ord
    end
  
    def getFillerChar
      return @filler
    end
  
    # This sets the character to use when a hidden character type is used
    def setHiddenChar(character)
      @hidden = character
    end
  
    def getHiddenChar
      return @hidden
    end
  
    # This sets a minimum length of the widget.
    def setMin(min)
      @min = min
    end
  
    def getMin
      return @min
    end
  
    # This erases the information in the multiple line entry widget
    def clean
      @info = ''
      @current_row = 0
      @current_col = 0
      @top_row = 0
    end
  
    # This sets the callback function.
    def setCB(callback)
      @callbackfn = callback
    end
  
    def focus
      @field_win.wmove(0, @current_col)
      @field_win.wrefresh
    end
  
    def unfocus
      @field_win.wrefresh
    end

    def position
      super(@win)
    end

    def object_type
      :MENTRY
    end
  end

  class SELECTION < CDK::SCROLLER
    attr_reader :selections

    def initialize(cdkscreen, xplace, yplace, splace, height, width, title,
        list, list_size, choices, choice_count, highlight, box, shadow)
      super()
      widest_item = -1
      parent_width = cdkscreen.window.getmaxx
      parent_height = cdkscreen.window.getmaxy
      box_width = width
      bindings = {
        CDK::BACKCHAR => Ncurses::KEY_PPAGE,
        CDK::FORCHAR  => Ncurses::KEY_NPAGE,
        'g'           => Ncurses::KEY_HOME,
        '1'           => Ncurses::KEY_HOME,
        'G'           => Ncurses::KEY_END,
        '<'           => Ncurses::KEY_HOME,
        '>'           => Ncurses::KEY_END,
      }

      if choice_count <= 0
        self.destroy
        return nil
      end

      @choice = []
      @choicelen = []

      self.setBox(box)

      # If the height is a negative value, the height will be ROWS-height,
      # otherwise the height will be the given height.
      box_height = CDK.setWidgetDimension(parent_height, height, 0)

      # If the width is a negative value, the width will be COLS-width,
      # otherwise the width will be the given width
      box_width = CDK.setWidgetDimension(parent_width, width, 0)
      box_width = self.setTitle(title, box_width)

      # Set the box height.
      if @title_lines > box_height
        box_height = @title_lines = [list_size, 8].min, + 2 * border_size
      end

      @maxchoicelen = 0

      # Adjust the box width if there is a scroll bar.
      if splace == CDK::LEFT || splace == CDK::RIGHT
        box_width += 1
        @scrollbar = true
      else
        @scrollbar = false
      end

      # Make sure we didn't extend beyond the dimensions of the window.
      @box_width = [box_width, parent_width].min
      @box_height = [box_height, parent_height].min

      self.setViewSize(list_size)

      # Rejustify the x and y positions if we need to.
      xtmp = [xplace]
      ytmp = [yplace]
      CDK.alignxy(cdkscreen.window, xtmp, ytmp, @box_width, @box_height)
      xpos = xtmp[0]
      ypos = ytmp[0]

      # Make the selection window.
      @win = Ncurses::WINDOW.new(@box_height, @box_width, ypos, xpos)

      # Is the window nil?
      if @win.nil?
        self.destroy
        return nil
      end

      # Turn the keypad on for this window.
      @win.keypad(true)

      # Create the scrollbar window.
      if splace == CDK::RIGHT
        @scrollbar_win = @win.subwin(self.maxViewSize, 1,
            self.SCREEN_YPOS(ypos), xpos + @box_width - @border_size - 1)
      elsif splace == CDK::LEFT
        @scrollbar_win = @win.subwin(self.maxViewSize, 1,
            self.SCREEN_YPOS(ypos), self.SCREEN_XPOS(ypos))
      else
        @scrollbar_win = nil
      end

      # Set the rest of the variables
      @screen = cdkscreen
      @parent = cdkscreen.window
      @scrollbar_placement = splace
      @max_left_char = 0
      @left_char = 0
      @highlight = highlight
      @choice_count = choice_count
      @accepts_focus = true
      @input_window = @win
      @shadow = shadow

      self.setCurrentItem(0)

      # Each choice has to be converted from string to chtype array
      (0...choice_count).each do |j|
        choicelen = []
        @choice << CDK.char2Chtype(choices[j], choicelen, [])
        @choicelen << choicelen[0]
        @maxchoicelen = [@maxchoicelen, choicelen[0]].max
      end

      # Each item in the needs to be converted to chtype array
      widest_item = self.createList(list, list_size)
      if widest_item > 0
        self.updateViewWidth(widest_item)
      elsif list_size > 0
        self.destroy
        return nil
      end

      # Do we need to create a shadow.
      if shadow
        @shadow_win = Ncurses::WINDOW.new(box_height, box_width,
            ypos + 1, xpos + 1)
      end

      # Setup the key bindings
      bindings.each do |from, to|
        self.bind(:SELECTION, from, :getc, to)
      end

      # Register this baby.
      cdkscreen.register(:SELECTION, self)
    end

    # Put the cursor on the currently-selected item.
    def fixCursorPosition
      scrollbar_adj = if @scrollbar_placement == CDK::LEFT
                      then 1
                      else 0
                      end
      ypos = self.SCREEN_YPOS(@current_item - @current_top)
      xpos = self.SCREEN_XPOS(0) + scrollbar_adj

      @input_window.wmove(ypos, xpos)
      @input_window.wrefresh
    end

    # This actually manages the selection widget
    def activate(actions)
      # Draw the selection list
      self.draw(@box)

      if actions.nil? || actions.size == 0
        while true
          self.fixCursorPosition
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

      # Set the exit type and return.
      self.setExitType(0)
      return 0
    end

    # This injects a single characer into the widget.
    def inject(input)
      pp_return = 1
      ret = -1
      complete = false

      # Set the exit type
      self.setExitType(0)

      # Draw the widget list.
      self.drawList(@box)

      # Check if there is a pre-process function to be called.
      unless @pre_process_func.nil?
        pp_return = @pre_process_func.call(:SELECTION, self,
            @pre_process_data, input)
      end

      # Should we continue?
      if pp_return != 0
        # Check for a predefined binding.
        if self.checkBind(:SELECTION, input)
          complete = true
        else
          case input
          when Ncurses::KEY_UP
            self.KEY_UP
          when Ncurses::KEY_DOWN
            self.KEY_DOWN
          when Ncurses::KEY_RIGHT
            self.KEY_RIGHT
          when Ncurses::KEY_LEFT
            self.KEY_LEFT
          when Ncurses::KEY_PPAGE
            self.KEY_PPAGE
          when Ncurses::KEY_NPAGE
            self.KEY_NPAGE
          when Ncurses::KEY_HOME
            self.KEY_HOME
          when Ncurses::KEY_END
            self.KEY_END
          when '$'.ord
            @left_char = @max_left_char
          when '|'
            @left_char = 0
          when ' '.ord
            if @mode[@current_item] == 0
              if @selections[@current_item] == @choice_count - 1
                @selections[@current_item] = 0
              else
                @selections[@current_item] += 1
              end
            else
              CDK.Beep
            end
          when CDK::KEY_ESC
            self.setExitType(input)
            complete = true
          when Ncurses::ERR
            self.setExitType(input)
            complete = true
          when Ncurses::KEY_ENTER, CDK::KEY_TAB, CDK::KEY_RETURN
            self.setExitType(input)
            ret = 1
            complete = true
          when CDK::REFRESH
            @screen.erase
            @screen.refresh
          end
        end
  
        # Should we call a post-process?
        if !complete && !(@post_process_func.nil?)
          @post_process_func.call(:SELECTION, self, @post_process_data, input)
        end
      end
  
      unless complete
        self.drawList(@box)
        self.setExitType(0)
      end
  
      @result_data = ret
      self.fixCursorPosition
      return ret
    end

    # This moves the selection field to the given location.
    def move(xplace, yplace, relative, refresh_flag)
      current_x = @win.getbegx
      current_y = @win.getbegy
      xpos = xplace
      ypos = yplace

      # If this is a relative move, then we will adjust where we want
      # to move to.
      if relative
        xpos = @win.getbegx + xplace
        ypos = @win.getbegy + yplace
      end

      # Adjust the window if we need to
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
      CDK.moveCursesWindow(@scrollbar_win, -xdiff, -ydiff)
      CDK.moveCursesWindow(@shadow_win, -xdiff, -ydiff)

      # Touch the windows so they 'move'.
      CDK::SCREEN.refreshCDKWindow(@screen.window)

      # Redraw the window, if they asked for it.
      if refresh_flag
        self.draw(@box)
      end
    end

    # This function draws the selection list.
    def draw(box)
      # Draw in the shadow if we need to.
      unless @shadow_win.nil?
        Draw.drawShadow(@shadow_win)
      end

      self.drawTitle(@win)

      # Redraw the list
      self.drawList(box)
    end

    # This function draws the selection list window.
    def drawList(box)
      scrollbar_adj = if @scrollbar_placement == LEFT then 1 else 0 end
      screen_pos = 0
      sel_item = -1

      # If there is to be a highlight, assign it now
      if @has_focus
        sel_item = @current_item
      end

      # draw the list...
      j = 0
      while j < @view_size && (j + @current_top) < @list_size
        k = j + @current_top
        if k < @list_size
          screen_pos = self.SCREENPOS(k, scrollbar_adj)
          ypos = self.SCREEN_YPOS(j)
          xpos = self.SCREEN_XPOS(0)

          # Draw the empty line.
          Draw.writeBlanks(@win, xpos, ypos, CDK::HORIZONTAL, 0, @win.getmaxx)

          # Draw the selection item.
          Draw.writeChtypeAttrib(@win,
              if screen_pos >= 0 then screen_pos else 1 end,
              ypos, @item[k],
              if k == sel_item then @highlight else Ncurses::A_NORMAL end,
              CDK::HORIZONTAL,
              if screen_pos >= 0 then 0 else 1 - screen_pos end,
              @item_len[k])

          # Draw the choice value
          Draw.writeChtype(@win, xpos + scrollbar_adj, ypos,
            @choice[@selections[k]], CDK::HORIZONTAL, 0,
            @choicelen[@selections[k]])
        end
        j += 1
      end

      # Determine where the toggle is supposed to be.
      if @scrollbar
        @toggle_pos = (@current_item * @step).floor
        @toggle_pos = [@toggle_pos, @scrollbar_win.getmaxy - 1].min

        @scrollbar_win.mvwvline(0, 0, Ncurses::ACS_CKBOARD,
            @scrollbar_win.getmaxy)
        @scrollbar_win.mvwvline(@toggle_pos, 0,
            ' '.ord | Ncurses::A_REVERSE, @toggle_size)
      end

      # Box it if needed
      if @box
        Draw.drawObjBox(@win, self)
      end

      self.fixCursorPosition
    end

    # This sets the background attribute of the widget.
    def setBKattr(attrib)
      @win.wbkgd(attrib)
      unless @scrollbar_win.nil?
        @scrollbar_win.wbkgd(attrib)
      end
    end

    def destroyInfo
      @item = []
    end

    # This function destroys the selection list.
    def destroy
      self.cleanTitle
      self.destroyInfo

      # Clean up the windows.
      CDK.deleteCursesWindow(@scrollbar_win)
      CDK.deleteCursesWindow(@shadow_win)
      CDK.deleteCursesWindow(@win)

      # Clean up the key bindings
      self.cleanBindings(:SELECTION)

      # Unregister this object.
      CDK::SCREEN.unregister(:SELECTION, self)
    end

    # This function erases the selection list from the screen.
    def erase
      if self.validCDKObject
        CDK.eraseCursesWindow(@win)
        CDK.eraseCursesWindow(@shadow_win)
      end
    end

    # This function sets a couple of the selection list attributes
    def set(highlight, choices, box)
      self.setChoices(choices)
      self.setHighlight(highlight)
      self.setBox(box)
    end

    # This sets the selection list items.
    def setItems(list, list_size)
      widest_item = self.createList(list, list_size)
      if widest_item <= 0
        return
      end

      # Clean up the display
      (0...@view_size).each do |j|
        Draw.writeBlanks(@win, self.SCREEN_XPOS(0), self.SCREEN_YPOS(j),
            CDK::HORIZONTAL, 0, @win.getmaxx)
      end

      self.setViewSize(list_size)
      self.setCurrentItem(0)

      self.updateViewWidth(widest_item)
    end

    def getItems(list)
      @item.each do |item|
        list << CDK.chtype2Char(item)
      end
      return @list_size
    end

    def setSelectionTitle(title)
      # Make sure the title isn't nil
      if title.nil?
        return
      end

      self.setTitle(title, -(@box_width + 1))

      self.setViewSize(@list_size)
    end

    def getTitle
      return CDK.chtype2Char(@title)
    end

    # This sets the highlight bar.
    def setHighlight(highlight)
      @highlight = highlight
    end

    def getHighlight
      @highlight
    end

    # This sets the default choices for the selection list.
    def setChoices(choices)
      # Set the choice values in the selection list.
      (0...@list_size).each do |j|
        if choices[j] < 0
          @selections[j] = 0
        elsif choices[j] > @choice_count
          @selections[j] = @choice_count - 1
        else
          @selections[j] = choices[j]
        end
      end
    end

    def getChoices
      @selections
    end

    # This sets a single item's choice value.
    def setChoice(index, choice)
      correct_choice = choice
      correct_index = index

      # Verify that the choice value is in range.
      if choice < 0
        correct_choice = 0
      elsif choice > @choice_count
        correct_choice = @choice_count - 1
      end

      # make sure the index isn't out of range.
      if index < 0
        correct_index = 0
      elsif index > @list_size
        correct_index = @list_size - 1
      end

      # Set the choice value.
      @selections[correct_index] = correct_choice
    end

    def getChoice(index)
      # Make sure the index isn't out of range.
      if index < 0
        return @selections[0]
      elsif index > list_size
        return @selections[@list_size - 1]
      else
        return @selections[index]
      end
    end

    # This sets the modes of the items in the selection list. Currently
    # there are only two: editable=0 and read-only=1
    def setModes(modes)
      # set the modes
      (0...@list_size).each do |j|
        @mode[j] = modes[j]
      end
    end

    def getModes
      return @mode
    end

    # This sets a single mode of an item in the selection list.
    def setMode(index, mode)
      # Make sure the index isn't out of range.
      if index < 0
        @mode[0] = mode
      elsif index > @list_size
        @mode[@list_size - 1] = mode
      else
        @mode[index] = mode
      end
    end

    def getMode(index)
      # Make sure the index isn't out of range
      if index < 0
        return @mode[0]
      elsif index > list_size
        return @mode[@list_size - 1]
      else
        return @mode[index]
      end
    end

    def getCurrent
      return @current_item
    end

    # methods for generic type methods
    def focus
      self.drawList(@box)
    end

    def unfocus
      self.drawList(@box)
    end

    def createList(list, list_size)
      status = 0
      widest_item = 0

      if list_size >= 0
        new_list = []
        new_len = []
        new_pos = []

        box_width = self.AvailableWidth
        adjust = @maxchoicelen + @border_size

        status = 1
        (0...list_size).each do |j|
          lentmp = []
          postmp = []
          new_list << CDK.char2Chtype(list[j], lentmp, postmp)
          new_len << lentmp[0]
          new_pos << postmp[0]
          #if new_list[j].size == 0
          if new_list[j].nil?
            status = 0
            break
          end
          new_pos[j] =
              CDK.justifyString(box_width, new_len[j], new_pos[j]) + adjust
          widest_item = [widest_item, new_len[j]].max
        end

        if status
          self.destroyInfo

          @item = new_list
          @item_pos = new_pos
          @item_len = new_len
          @selections = [0] * list_size
          @mode = [0] * list_size
        end
      else
        self.destroyInfo
      end

      return (if status then widest_item else 0 end)
    end

    # Determine how many characters we can shift to the right
    # before all the items have been scrolled off the screen.
    def AvailableWidth
      @box_width - 2 * @border_size - @maxchoicelen
    end

    def updateViewWidth(widest)
      @max_left_char = if @box_width > widest
                       then 0
                       else widest - self.AvailableWidth
                       end
    end

    def WidestItem
      @max_left_char + self.AvailableWidth
    end

    def SCREENPOS(n, scrollbar_adj)
      @item_pos[n] - @left_char + scrollbar_adj
    end

    def position
      super(@win)
    end

    def object_type
      :SELECTION
    end
  end

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
      current_x = @win.getbegx
      current_y = @win.getbegy
      xpos = xplace
      ypos = yplace

      # If this is a relative move, then we will adjust where we want
      # to move to.
      if relative
        xpos = @win.getbegx + xplace
        ypos = @win.getbegy + yplace
      end

      # Adjust the window if we need to
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

      # Move the subwidgets.
      @entry_field.move(xplace, yplace, relative, false)
      @scroll_field.move(xplace, yplace, relative, false)

      # Touch the windows so they 'move'.
      CDK::SCREEN.refresh(@screen.window)

      # Redraw the window, if they asked for it.
      if refresh_flag
        self.draw(@box)
      end
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

  class SWINDOW < CDK::CDKOBJS
    def initialize(cdkscreen, xplace, yplace, height, width, title,
        save_lines, box, shadow)
      super()
      parent_width = cdkscreen.window.getmaxx
      parent_height = cdkscreen.window.getmaxy
      box_width = width
      box_height = height
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

      # If the height is a negative value, the height will be
      # ROWS-height, otherwise the height will be the given height.
      box_height = CDK.setWidgetDimension(parent_height, height, 0)

      # If the width is a negative value, the width will be
      # COLS-width, otherwise the widget will be the given width.
      box_width = CDK.setWidgetDimension(parent_width, width, 0)
      box_width = self.setTitle(title, box_width)

      # Set the box height.
      box_height += @title_lines + 1

      # Make sure we didn't extend beyond the dimensions of the window.
      box_width = [box_width, parent_width].min
      box_height = [box_height, parent_height].min

      # Set the rest of the variables.
      @title_adj = @title_lines + 1

      # Rejustify the x and y positions if we need to.
      xtmp = [xplace]
      ytmp = [yplace]
      CDK.alignxy(cdkscreen.window, xtmp, ytmp, box_width, box_height)
      xpos = xtmp[0]
      ypos = ytmp[0]

      # Make the scrolling window.
      @win = Ncurses::WINDOW.new(box_height, box_width, ypos, xpos)
      if @win.nil?
        self.destroy
        return nil
      end
      @win.keypad(true)

      # Make the field window
      @field_win = @win.subwin(box_height - @title_lines - 2, box_width - 2,
          ypos + @title_lines + 1, xpos + 1)
      @field_win.keypad(true)

      # Set the rest of the variables
      @screen = cdkscreen
      @parent = cdkscreen.window
      @shadow_win = nil
      @box_height = box_height
      @box_width = box_width
      @view_size = box_height - @title_lines - 2
      @current_top = 0
      @max_top_line = 0
      @left_char = 0
      @max_left_char = 0
      @list_size = 0
      @widest_line = -1
      @save_lines = save_lines
      @accepts_focus = true
      @input_window = @win
      @shadow = shadow

      if !self.createList(save_lines)
        self.destroy
        return nil
      end

      # Do we need to create a shadow?
      if shadow
        @shadow_win = Ncurses::WINDOW.new(box_height, box_width,
            ypos + 1, xpos + 1)
      end

      # Create the key bindings
      bindings.each do |from, to|
        self.bind(:SWINDOW, from, :getc, to)
      end

      # Register this baby.
      cdkscreen.register(:SWINDOW, self)
    end

    # This sets the lines and the box attribute of the scrolling window.
    def set(list, lines, box)
      self.setContents(list, lines)
      self.setBox(box)
    end

    def setupLine(list, x)
      list_len = []
      list_pos = []
      @list[x] = CDK.char2Chtype(list, list_len, list_pos)
      @list_len[x] = list_len[0]
      @list_pos[x] = CDK.justifyString(@box_width, list_len[0], list_pos[0])
      @widest_line = [@widest_line, @list_len[x]].max
    end

    # This sets all the lines inside the scrolling window.
    def setContents(list, list_size)
      # First let's clean all the lines in the window.
      self.clean
      self.createList(list_size)

      # Now let's set all the lines inside the window.
      (0...list_size).each do |x|
        self.setupLine(list[x], x)
      end

      # Set some more important members of the scrolling window.
      @list_size = list_size
      @max_top_line = @list_size - @view_size
      @max_top_line = [@max_top_line, 0].max
      @max_left_char = @widest_line - (@box_width - 2)
      @current_top = 0
      @left_char = 0
    end

    def getContents(size)
      size << @list_size
      return @list
    end

    def freeLine(x)
    #  if x < @list_size
    #    @list[x] = 0
    #  end
    end

    # This adds a line to the scrolling window.
    def add(list, insert_pos)
      # If we are at the maximum number of save lines erase the first
      # position and bump everything up one spot
      if @list_size == @save_lines and @list_size > 0
        @list = @list[1..-1]
        @list_pos = @list_pos[1..-1]
        @list_len = @list_len[1..-1]
        @list_size -= 1
      end

      # Determine where the line is being added.
      if insert_pos == CDK::TOP
        # We need to 'bump' everything down one line...
        @list = [@list[0]] + @list
        @list_pos = [@list_pos[0]] + @list_pos
        @list_len = [@list_len[0]] + @list_len

        # Add it into the scrolling window.
        self.setupLine(list, 0)

        # set some variables.
        @current_top = 0
        if @list_size < @save_lines
          @list_size += 1
        end

        # Set the maximum top line.
        @max_top_line = @list_size - @view_size
        @max_top_line = [@max_top_line, 0].max

        @max_left_char = @widest_line - (@box_width - 2)
      else
        # Add to the bottom.
        @list += ['']
        @list_pos += [0]
        @list_len += [0]
        self.setupLine(list, @list_size)
        
        @max_left_char = @widest_line - (@box_width - 2)

        # Increment the item count and zero out the next row.
        if @list_size < @save_lines
          @list_size += 1
          self.freeLine(@list_size)
        end

        # Set the maximum top line.
        if @list_size <= @view_size
          @max_top_line = 0
          @current_top = 0
        else
          @max_top_line = @list_size - @view_size
          @current_top = @max_top_line
        end
      end

      # Draw in the list.
      self.drawList(@box)
    end

    # This jumps to a given line.
    def jumpToLine(line)
      # Make sure the line is in bounds.
      if line == CDK::BOTTOM || line >= @list_size
        # We are moving to the last page.
        @current_top = @list_size - @view_size
      elsif line == TOP || line <= 0
        # We are moving to the top of the page.
        @current_top = 0
      else
        # We are moving in the middle somewhere.
        if @view_size + line < @list_size
          @current_top = line
        else
          @current_top = @list_size - @view_size
        end
      end

      # A little sanity check to make sure we don't do something silly
      if @current_top < 0
        @current_top = 0
      end

      # Redraw the window.
      self.draw(@box)
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

    # This trims lines from the scrolling window.
    def trim(begin_line, end_line)
      # Check the value of begin_line
      if begin_line < 0
        start = 0
      elsif begin_line >= @list_size
        start = @list_size - 1
      else
        start = begin_line
      end

      # Check the value of end_line
      if end_line < 0
        finish = 0
      elsif end_line >= @list_size
        finish = @list_size - 1
      else
        finish = end_line
      end

      # Make sure the start is lower than the end.
      if start > finish
        return
      end

      # Start nuking elements from the window
      (start..finish).each do |x|
        self.freeLine(x)

        if x < list_size - 1
          @list[x] = @list[x + 1]
          @list_pos[x] = @list_pos[x + 1]
          @list_len[x] = @list_len[x + 1]
        end
      end

      # Adjust the item count correctly.
      @list_size = @list_size - (end_line - begin_line) - 1

      # Redraw the window.
      self.draw(@box)
    end

    # This allows the user to play inside the scrolling window.
    def activate(actions)
      # Draw the scrolling list.
      self.draw(@box)

      if actions.nil? || actions.size == 0
        while true
          input = self.getch([])

          # inject the character into the widget.
          self.inject(input)
          if @exit_type != :EARLY_EXIT
            return
          end
        end
      else
        #Inject each character one at a time
        actions.each do |action|
          self.inject(action)
          if @exit_type != :EARLY_EXIT
            return
          end
        end
      end

      # Set the exit type and return.
      self.setExitType(0)
    end

    # This injects a single character into the widget.
    def inject(input)
      pp_return = 1
      ret = -1
      complete = false

      # Set the exit type.
      self.setExitType(0)

      # Draw the window....
      self.draw(@box)

      # Check if there is a pre-process function to be called.
      unless @pre_process_func.nil?
        # Call the pre-process function.
        pp_return = @pre_process_func.call(:SWINDOW, self,
            @pre_process_data, input)
      end

      # Should we continue?
      if pp_return != 0
        # Check for a key binding.
        if self.checkBind(:SWINDOW, input)
          complete = true
        else
          case input
          when Ncurses::KEY_UP
            if @current_top > 0
              @current_top -= 1
            else
              CDK.Beep
            end
          when Ncurses::KEY_DOWN
            if @current_top >= 0 && @current_top < @max_top_line
              @current_top += 1
            else
              CDK.Beep
            end
          when Ncurses::KEY_RIGHT
            if @left_char < @max_left_char
              @left_char += 1
            else
              CDK.Beep
            end
          when Ncurses::KEY_LEFT
            if @left_char > 0
              @left_char -= 1
            else
              CDK.Beep
            end
          when Ncurses::KEY_PPAGE
            if @current_top != 0
              if @current_top >= @view_size
                @current_top = @current_top - (@view_size - 1)
              else
                @current_top = 0
              end
            else
              CDK.Beep
            end
          when Ncurses::KEY_NPAGE
            if @current_top != @max_top_line
              if @current_top + @view_size < @max_top_line
                @current_top = @current_top + (@view_size - 1)
              else
                @current_top = @max_top_line
              end
            else
              CDK.Beep
            end
          when Ncurses::KEY_HOME
            @left_char = 0
          when Ncurses::KEY_END
            @left_char = @max_left_char + 1
          when 'g'.ord, '1'.ord, '<'.ord
            @current_top = 0
          when 'G'.ord, '>'.ord
            @current_top = @max_top_line
          when 'l'.ord, 'L'.ord
            self.loadInformation
          when 's'.ord, 'S'.ord
            self.saveInformation
          when CDK::KEY_TAB, CDK::KEY_RETURN, Ncurses::KEY_ENTER
            self.setExitType(input)
            ret = 1
            complete = true
          when CDK::KEY_ESC
            self.setExitType(input)
            complete = true
          when Ncurses::ERR
            self.setExitType(input)
            complete = true
          when CDK::REFRESH
            @screen.erase
            @screen.refresh
          end
        end

        # Should we call a post-process?
        if !complete && !(@post_process_func.nil?)
          @post_process_func.call(:SWINDOW, self, @post_process_data, input)
        end
      end

      if !complete
        self.drawList(@box)
        self.setExitType(0)
      end

      @return_data = ret
      return ret
    end

    # This moves the window field to the given location.
    def move(xplace, yplace, relative, refresh_flag)
      current_x = @win.getbegx
      current_y = @win.getbegy
      xpos = xplace
      ypos = yplace

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

      # Get the difference
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

    # This function draws the swindow window widget.
    def draw(box)
      # Do we need to draw in the shadow.
      unless @shadow_win.nil?
        Draw.drawShadow(@shadow_win)
      end

      # Box the widget if needed
      if box
        Draw.drawObjBox(@win, self)
      end

      self.drawTitle(@win)

      @win.wrefresh

      # Draw in the list.
      self.drawList(box)
    end

    # This draws in the contents of the scrolling window
    def drawList(box)
      # Determine the last line to draw.
      if @list_size < @view_size
        last_line = @list_size
      else
        last_line = @view_size
      end

      # Erase the scrolling window.
      @field_win.werase

      # Start drawing in each line.
      (0...last_line).each do |x|
        screen_pos = @list_pos[x + @current_top] - @left_char

        # Write in the correct line.
        if screen_pos >= 0
          Draw.writeChtype(@field_win, screen_pos, x,
              @list[x + @current_top], CDK::HORIZONTAL, 0,
              @list_len[x + @current_top])
        else
          Draw.writeChtype(@field_win, 0, x, @list[x + @current_top],
              CDK::HORIZONTAL, @left_char - @list_pos[x + @current_top],
              @list_len[x + @current_top])
        end
      end

      @field_win.wrefresh
    end

    # This sets the background attribute of the widget.
    def setBKattr(attrib)
      @win.wbkgd(attrib)
      @field_win.wbkgd(attrib)
    end

    # Free any storage associated with the info-list.
    def destroyInfo
      @list = []
      @list_pos = []
      @list_len = []
    end

    # This function destroys the scrolling window widget.
    def destroy
      self.destroyInfo

      self.cleanTitle

      # Delete the windows.
      CDK.deleteCursesWindow(@shadow_win)
      CDK.deleteCursesWindow(@field_win)
      CDK.deleteCursesWindow(@win)

      # Clean the key bindings.
      self.cleanBindings(:SWINDOW)

      # Unregister this object.
      CDK::SCREEN.unregister(:SWINDOW, self)
    end

    # This function erases the scrolling window widget.
    def erase
      if self.validCDKObject
        CDK.eraseCursesWindow(@win)
        CDK.eraseCursesWindow(@shadow_win)
      end
    end

    # This execs a command and redirects the output to the scrolling window.
    def exec(command, insert_pos)
      count = -1
      Ncurses.endwin

      # Try to open the command.
      # XXX This especially needs exception handling given how Ruby
      # implements popen
      unless (ps = IO.popen(command.split, 'r')).nil?
        # Start reading.
        until (temp = ps.gets).nil?
          if temp.size != 0 && temp[-1] == '\n'
            temp = temp[0...-1]
          end
          # Add the line to the scrolling window.
          self.add(temp, insert_pos)
          count += 1
        end

        # Close the pipe
        ps.close
      end
      return count
    end

    def showMessage2(msg, msg2, filename)
      mesg = [
          msg,
          msg2,
          "<C>(%s)" % [filename],
          ' ',
          '<C> Press any key to continue.',
      ]
      @screen.popupLabel(mesg, mesg.size)
    end

    # This function allows the user to dump the information from the
    # scrolling window to a file.
    def saveInformation
      # Create the entry field to get the filename.
      entry = CDK::ENTRY.new(@screen, CDK::CENTER, CDK::CENTER,
          '<C></B/5>Enter the filename of the save file.',
          'Filename: ', Ncurses::A_NORMAL, '_'.ord, :MIXED,
          20, 1, 256, true, false)

      # Get the filename.
      filename = entry.activate([])

      # Did they hit escape?
      if entry.exit_type == :ESCAPE_HIT
        # Popup a message.
        mesg = [
            '<C></B/5>Save Canceled.',
            '<C>Escape hit. Scrolling window information not saved.',
            ' ',
            '<C>Press any key to continue.'
        ]
        @screen.popupLabel(mesg, 4)

        # Clean up and exit.
        entry.destroy
      end

      # Write the contents of the scrolling window to the file.
      lines_saved = self.dump(filename)

      # Was the save successful?
      if lines_saved == -1
        # Nope, tell 'em
        self.showMessage2('<C></B/16>Error', '<C>Could not save to the file.',
            filename)
      else
        # Yep, let them know how many lines were saved.
        self.showMessage2('<C></B/5>Save Successful',
            '<C>There were %d lines saved to the file' % [lines_saved],
            filename)
      end

      # Clean up and exit.
      entry.destroy
      @screen.erase
      @screen.draw
    end

    # This function allows the user to load new information into the scrolling
    # window.
    def loadInformation
      # Create the file selector to choose the file.
      fselect = CDK::FSELECT.new(@screen, CDK::CENTER, CDK::CENTER, 20, 55,
          '<C>Load Which File', 'FIlename', Ncurses::A_NORMAL, '.',
          Ncurses::A_REVERSE, '</5>', '</48>', '</N>', '</N>', true, false)

      # Get the filename to load.
      filename = fselect.activate([])

      # Make sure they selected a file.
      if fselect.exit_type == :ESCAPE_HIT
        # Popup a message.
        mesg = [
            '<C></B/5>Load Canceled.',
            ' ',
            '<C>Press any key to continue.',
        ]
        @screen.popupLabel(mesg, 3)

        # Clean up and exit
        fselect.destroy
        return
      end

      # Copy the filename and destroy the file selector.
      filename = fselect.pathname
      fselect.destroy

      # Maybe we should check before nuking all the information in the
      # scrolling window...
      if @list_size > 0
        # Create the dialog message.
        mesg = [
            '<C></B/5>Save Information First',
            '<C>There is information in the scrolling window.',
            '<C>Do you want to save it to a file first?',
        ]
        button = ['(Yes)', '(No)']

        # Create the dialog widget.
        dialog = CDK::DIALOG.new(@screen, CDK::CENTER, CDK::CENTER,
            mesg, 3, button, 2, Ncurses.COLOR_PAIR(2) | Ncurses::A_REVERSE,
            true, true, false)

        # Activate the widet.
        answer = dialog.activate([])
        dialog.destroy

        # Check the answer.
        if (answer == -1 || answer == 0)
          # Save the information.
          self.saveInformation
        end
      end

      # Open the file and read it in.
      f = File.open(filename)
      file_info = f.readlines.map do |line|
        if line.size > 0 && line[-1] == "\n"
          line[0...-1]
        else
          line
        end
      end.compact

      # TODO error handling
      # if (lines == -1)
      # {
      #   /* The file read didn't work. */
      #   showMessage2 (swindow,
      #                 "<C></B/16>Error",
      #                 "<C>Could not read the file",
      #                 filename);
      #   freeChar (filename);
      #   return;
      # }

      # Clean out the scrolling window.
      self.clean

      # Set the new information in the scrolling window.
      self.set(file_info, file_info.size, @box)
    end

    # This actually dumps the information from the scrolling window to a file.
    def dump(filename)
      # Try to open the file.
      #if ((outputFile = fopen (filename, "w")) == 0)
      #{
      #  return -1;
      #}
      output_file = File.new(filename, 'w')

      # Start writing out the file.
      @list.each do |item|
        raw_line = CDK.chtype2Char(item)
        output_file << "%s\n" % raw_line
      end

      # Close the file and return the number of lines written.
      output_file.close
      return @list_size
    end

    def focus
      self.draw(@box)
    end

    def unfocus
      self.draw(@box)
    end

    def createList(list_size)
      status = false

      if list_size >= 0
        new_list = []
        new_pos = []
        new_len = []

        status = true
        self.destroyInfo

        @list = new_list
        @list_pos = new_pos
        @list_len = new_len
      else
        self.destroyInfo
        status = false
      end
      return status
    end

    def position
      super(@win)
    end

    def object_type
      :SWINDOW
    end
  end

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
      return Time.mktime(CDK::CALENDAR.YEAR2INDEX(year), month,
          1, 10, 0, 0).wday
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
      return Time.mktime(CDK::CALENDAR.YEAR2INDEX(@year), @month,
          @day, 0, 0, 0).gmtime
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

  class FSELECT < CDK::CDKOBJS
    attr_reader :scroll_field, :entry_field
    attr_reader :dir_attribute, :file_attribute, :link_attribute, :highlight
    attr_reader :sock_attribute, :field_attribute, :filler_character
    attr_reader :dir_contents, :file_counter, :pwd, :pathname

    def initialize(cdkscreen, xplace, yplace, height, width, title, label,
        field_attribute, filler_char, highlight, d_attribute, f_attribute,
        l_attribute, s_attribute, box, shadow)
      super()
      parent_width = cdkscreen.window.getmaxx
      parent_height = cdkscreen.window.getmaxy
      bindings = {
          CDK::BACKCHAR => Ncurses::KEY_PPAGE,
          CDK::FORCHAR  => Ncurses::KEY_NPAGE,
      }

      self.setBox(box)

      # If the height is a negative value the height will be ROWS-height,
      # otherwise the height will be the given height
      box_height = CDK.setWidgetDimension(parent_height, height, 0)

      # If the width is a negative value, the width will be COLS-width,
      # otherwise the width will be the given width.
      box_width = CDK.setWidgetDimension(parent_width, width, 0)

      # Rejustify the x and y positions if we need to.
      xtmp = [xplace]
      ytmp = [yplace]
      CDK.alignxy(cdkscreen.window, xtmp, ytmp, box_width, box_height)
      xpos = xtmp[0]
      ypos = ytmp[0]

      # Make sure the box isn't too small.
      box_width = [box_width, 15].max
      box_height = [box_height, 6].max

      # Make the file selector window.
      @win = Ncurses::WINDOW.new(box_height, box_width, ypos, xpos)

      # is the window nil?
      if @win.nil?
        fselect.destroy
        return nil
      end
      @win.keypad(true)

      # Set some variables.
      @screen = cdkscreen
      @parent = cdkscreen.window
      @dir_attribute = d_attribute.clone
      @file_attribute = f_attribute.clone
      @link_attribute = l_attribute.clone
      @sock_attribute = s_attribute.clone
      @highlight = highlight
      @filler_character = filler_char
      @field_attribute = field_attribute
      @box_height = box_height
      @box_width = box_width
      @file_counter = 0
      @pwd = ''
      @input_window = @win
      @shadow = shadow
      @shadow_win = nil

      # Get the present working directory.
      # XXX need error handling (set to '.' on error)
      @pwd = Dir.getwd

      # Get the contents of the current directory
      self.setDirContents

      # Create the entry field in the selector
      label_len = []
      CDK.char2Chtype(label, label_len, [])
      label_len = label_len[0]

      temp_width = if CDK::FSELECT.isFullWidth(width)
                   then CDK::FULL
                   else box_width - 2 - label_len
                   end
      @entry_field = CDK::ENTRY.new(cdkscreen, @win.getbegx, @win.getbegy,
          title, label, field_attribute, filler_char, :MIXED, temp_width,
          0, 512, box, false)

      # Make sure the widget was created.
      if @entry_field.nil?
        self.destroy
        return nil
      end

      # Set the lower left/right characters of the entry field.
      @entry_field.setLLchar(Ncurses::ACS_LTEE)
      @entry_field.setLRchar(Ncurses::ACS_RTEE)

      # This is a callback to the scrolling list which displays information
      # about the current file.  (and the whole directory as well)
      display_file_info_cb = lambda do |object_type, entry, fselect, key|
        # Get the file name.
        filename = fselect.entry_field.info

        # Get specific information about the files.
        # lstat (filename, &fileStat);
        file_stat = File.stat(filename)

        # Determine the file type
        filetype = case
                   when file_stat.symlink?
                     'Symbolic Link'
                   when file_stat.socket?
                     'Socket'
                   when file_stat.file?
                     'Regular File'
                   when file_stat.directory?
                     'Directory'
                   when file_stat.chardev?
                     'Character Device'
                   when file_stat.blockdev?
                     'Block Device'
                   when file_stat.ftype == 'fif'
                     'FIFO Device'
                   else
                     'Unknown'
                   end

        # Get the user name and group name.
        pw_ent = Etc.getpwuid(file_stat.uid)
        gr_ent = Etc.getgrgid(file_stat.gid)

        # Convert the mode to both string and int
        # intMode = mode2Char (stringMode, fileStat.st_mode);

        # Create the message.
        mesg = [
            'Directory  : </U>%s' % [fselect.pwd],
            'Filename   : </U>%s' % [filename],
            'Owner      : </U>%s<!U> (%d)' % [pw_ent.name, file_stat.uid],
            'Group      : </U>%s<!U> (%d)' % [gr_ent.name, file_stat.gid],
            'Permissions: </U>%s<!U> (%o)' % [string_mode, int_mode],
            'Size       : </U>%ld<!U> bytes' % [file_stat.size],
            'Last Access: </U>%s' % [file_stat.atime],
            'Last Change: </U>%s' % [file_stat.ctime],
            'File Type  : </U>%s' % [filetype]
        ]

        # Create the pop up label.
        info_label = CDK::LABEL.new(entry.screen, CDK::CENTER, CDK::CENTER,
            mesg, 9, true, false)
        info_label.draw(true)
        info_label.getch([])

        info_label.destroy

        # Redraw the file selector.
        fselect.draw(fselect.box)
        return true
      end

      # This tries to complete the filename
      complete_filename_cb = lambda do |object_type, object, fselect, key|
        scrollp = fselect.scroll_field
        entry = fselect.entry_field
        filename = entry.info.clone
        mydirname = CDK.dirName(filename)
        current_index = 0
        
        # Make sure the filename is not nil/empty.
        if filename.nil? || filename.size == 0
          CDK.Beep
          return true
        end

        # Try to expand the filename if it starts with a ~
        unless (new_filename = CDK::FSELECT.expandTilde(filename)).nil?
          filename = new_filename
          entry.setValue(filename)
          entry.draw(entry.box)
        end

        # Make sure we can change into the directory.
        is_directory = Dir.exists?(filename)
        # if (chdir (fselect->pwd) != 0)
        #    return FALSE;
        #Dir.chdir(fselect.pwd)

        # XXX original: isDirectory ? mydirname : filename
        fselect.set(if is_directory then filename else mydirname end,
            fselect.field_attribute, fselect.filler_character,
            fselect.highlight, fselect.dir_attribute, fselect.file_attribute,
            fselect.link_attribute, fselect.sock_attribute, fselect.box)

        # If we can, change into the directory.
        # XXX original: if isDirectory (with 0 as success result)
        if is_directory
          entry.setValue(filename)
          entry.draw(entry.box)
        end

        # Create the file list.
        list = []
        (0...fselect.file_counter).each do |x|
          list << fselect.contentToPath(fselect.dir_contents[x])
        end

        # Look for a unique filename match.
        index = CDK.searchList(list, fselect.file_counter, filename)

        # If the index is less than zero, return we didn't find a match.
        if index < 0
          CDK.Beep
        else
          # Move to the current item in the scrolling list.
          # difference = Index - scrollp->currentItem;
          # absoluteDifference = abs (difference);
          # if (difference < 0)
          # {
          #    for (x = 0; x < absoluteDifference; x++)
          #    {
          #       injectMyScroller (fselect, KEY_UP);
          #    }
          # }
          # else if (difference > 0)
          # {
          #    for (x = 0; x < absoluteDifferene; x++)
          #    {
          #       injectMyScroller (fselect, KEY_DOWN);
          #    }
          # }
          scrollp.setPosition(index)
          fselect.drawMyScroller

          # Ok, we found a match, is the next item similar?
          if index + 1 < fselect.file_counter && index + 1 < list.size &&
              list[index + 1][0..([filename.size, list[index + 1].size].min)] ==
              filename
            current_index = index
            base_chars = filename.size
            matches = 0

            # Determine the number of files which match.
            while current_index < fselect.file_counter
              if current_index + 1 < list.size
                if list[current_index][0..(
                    [filename.size, list[current_index].size].max)] == filename
                  matches += 1
                end
              end
              current_index += 1
            end

            # Start looking for the common base characters.
            while true
              secondary_matches = 0
              (index...index + matches).each do |x|
                if list[index][base_chars] == list[x][base_chars]
                  secondary_matches += 1
                end
              end

              if secondary_matches != matches
                CDK.Beep
                break
              end

              # Inject the character into the entry field.
              fselect.entry_field.inject(list[index][base_chars])
              base_chars += 1
            end
          else
            # Set the entry field with the found item.
            entry.setValue(list[index])
            entry.draw(entry.box)
          end
        end

        return true
      end

      # This allows the user to delete a file.
      delete_file_cb = lambda do |object_type, fscroll, fselect|
        buttons = ['No', 'Yes']

        # Get the filename which is to be deleted.
        filename = CDK.chtype2Char(fscroll.item[fscroll.current_item])
        filename = filename[0...-1]

        # Create the dialog message.
        mesg = [
            '<C>Are you sure you want to delete the file:',
            '<C></U>"%s"?' % [filename]
        ]

        # Create the dialog box.
        question = CDK::DIALOG.new(fselect.screen, CDK::CENTER, CDK::CENTER,
            mesg, 2, buttons, 2, Ncurses::A_REVERSE, true, true, false)

        # If the said yes then try to nuke it.
        if question.activate([]) == 1
          # If we were successful, reload the scrolling list.
          if File.unlink(filename) == 0
            # Set the file selector information.
            fselect.set(fselect.pwd, fselect.field_attribute,
                fselect.filler_character, fselect.highlight,
                fselect.dir_attribute, fselect.file_attribute,
                fselect.link_attribute, fselect.sock_attribute, fselect.box)
          else
            # Pop up a message.
            # mesg[0] = copyChar (errorMessage ("<C>Cannot delete file: %s"));
            # mesg[1] = copyChar (" ");
            # mesg[2] = copyChar("<C>Press any key to continue.");
            # popupLabel(ScreenOf (fselect), (CDK_CSTRING2) mesg, 3);
            # freeCharList (mesg, 3);
          end
        end

        # Clean up.
        question.destroy

        # Redraw the file seoector.
        fselect.draw(fselect.box)
      end

      # Start of callback functions.
      adjust_scroll_cb = lambda do |object_type, object, fselect, key|
        scrollp = fselect.scroll_field
        entry = fselect.entry_field

        if scrollp.list_size > 0
          # Move the scrolling list.
          fselect.injectMyScroller(key)

          # Get the currently highlighted filename.
          current = CDK.chtype2Char(scrollp.item[scrollp.current_item])
          #current = CDK.chtype2String(scrollp.item[scrollp.current_item])
          current = current[0...-1]

          temp = CDK::FSELECT.make_pathname(fselect.pwd, current)

          # Set the value in the entry field.
          entry.setValue(temp)
          entry.draw(entry.box)

          return true
        end
        CDK.Beep
        return false
      end

      # Define the callbacks for the entry field.
      @entry_field.bind(:ENTRY, Ncurses::KEY_UP, adjust_scroll_cb, self)
      @entry_field.bind(:ENTRY, Ncurses::KEY_PPAGE, adjust_scroll_cb, self)
      @entry_field.bind(:ENTRY, Ncurses::KEY_DOWN, adjust_scroll_cb, self)
      @entry_field.bind(:ENTRY, Ncurses::KEY_NPAGE, adjust_scroll_cb, self)
      @entry_field.bind(:ENTRY, CDK::KEY_TAB, complete_filename_cb, self)
      @entry_field.bind(:ENTRY, CDK.CTRL('^'), display_file_info_cb, self)

      # Put the current working directory in the entry field.
      @entry_field.setValue(@pwd)

      # Create the scrolling list in the selector.
      temp_height = @entry_field.win.getmaxy - @border_size
      temp_width = if CDK::FSELECT.isFullWidth(width)
                   then CDK::FULL
                   else box_width - 1
                   end
      @scroll_field = CDK::SCROLL.new(cdkscreen,
          @win.getbegx, @win.getbegy + temp_height, CDK::RIGHT,
          box_height - temp_height, temp_width, '', @dir_contents,
          @file_counter, false, @highlight, box, false)

      # Set the lower left/right characters of the entry field.
      @scroll_field.setULchar(Ncurses::ACS_LTEE)
      @scroll_field.setURchar(Ncurses::ACS_RTEE)

      # Do we want a shadow?
      if shadow
        @shadow_win = Ncurses::WINDOW.new(box_height, box_width,
            ypos + 1, xpos + 1)
      end

      # Setup the key bindings
      bindings.each do |from, to|
        self.bind(:FSELECT, from, :getc, to)
      end

      cdkscreen.register(:FSELECT, self)
    end

    # This erases the file selector from the screen.
    def erase
      if self.validCDKObject
        @scroll_field.erase
        @entry_field.erase
        CDK.eraseCursesWindow(@win)
      end
    end

    # This moves the fselect field to the given location.
    def move(xplace, yplace, relative, refresh_flag)
      current_x = @win.getbegx
      current_y = @win.getbegy
      xpos = xplace
      ypos = yplace

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

      # Move the sub-widgets.
      @entry_field.move(xplace, yplace, relative, false)
      @scroll_field.move(xplace, yplace, relative, false)

      # Redraw the widget if they asked for it.
      if refresh_flag
        self.draw(@box)
      end
    end

    # The fselect's focus resides in the entry widget. But the scroll widget
    # will not draw items highlighted unless it has focus.  Temporarily adjust
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

    # This draws the file selector widget.
    def draw(box)
      # Draw in the shadow if we need to.
      unless @shadow_win.nil?
        Draw.drawShadow(@shadow_win)
      end

      # Draw in the entry field.
      @entry_field.draw(@entry_field.box)

      # Draw in the scroll field.
      self.drawMyScroller
    end

    # This means you want to use the given file selector. It takes input
    # from the keyboard and when it's done it fills the entry info element
    # of the structure with what was typed.
    def activate(actions)
      input = 0
      ret = 0

      # Draw the widget.
      self.draw(@box)

      if actions.nil? || actions.size == 0
        while true
          input = @entry_field.getch([])

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

      # Set the exit type and exit.
      self.setExitType(0)
      return 0
    end

    # This injects a single character into the file selector.
    def inject(input)
      ret = -1
      complete = false

      # Let the user play.
      filename = @entry_field.inject(input)

      # Copy the entry field exit_type to the file selector.
      @exit_type = @entry_field.exit_type

      # If we exited early, make sure we don't interpret it as a file.
      if @exit_type == :EARLY_EXIT
        return 0
      end

      # Can we change into the directory
      #file = Dir.chdir(filename)
      #if Dir.chdir(@pwd) != 0
      #  return 0
      #end

      # If it's not a directory, return the filename.
      if !Dir.exists?(filename)
        # It's a regular file, create the full path
        @pathname = filename.clone

        # Return the complete pathname.
        ret = @pathname
        complete = true
      else
        # Set the file selector information.
        self.set(filename, @field_attribute, @filler_character, @highlight,
            @dir_attribute, @file_attribute, @link_attribute, @sock_attribute,
            @box)

        # Redraw the scrolling list.
        self.drawMyScroller
      end

      if !complete
        self.setExitType(0)
      end

      @result_data = ret
      return ret
    end

    # This function sets the information inside the file selector.
    def set(directory, field_attrib, filler, highlight, dir_attribute,
        file_attribute, link_attribute, sock_attribute, box)
      fscroll = @scroll_field
      fentry = @entry_field
      new_directory = ''

      # keep the info sent to us.
      @field_attribute = field_attrib
      @filler_character = filler
      @highlight = highlight

      # Set the attributes of the entry field/scrolling list.
      self.setFillerChar(filler)
      self.setHighlight(highlight)

      # Only do the directory stuff if the directory is not nil.
      if !(directory.nil?) && directory.size > 0
        # Try to expand the directory if it starts with a ~
        if (temp_dir = CDK::FSELECT.expandTilde(directory)).size > 0
          new_directory = temp_dir
        else
          new_directory = directory.clone
        end

        # Change directories.
        if Dir.chdir(new_directory) != 0
          CDK.Beep

          # Could not get into the directory, pop up a little message.
          mesg = [
              '<C>Could not change into %s' % [new_directory],
              '<C></U>%s' % ['Unknown reason.'],  # errorMessage(format)
              ' ',
              '<C>Press Any Key To Continue.'
          ]

          # Pop up a message.
          @screen.popupLabel(mesg, 4)

          # Get out of here.
          self.erase
          self.draw(@box)
          return
        end
      end

      # if the information coming in is the same as the information
      # that is already there, there is no need to destroy it.
      if @pwd != directory
        @pwd = Dir.getwd
      end

      @file_attribute = file_attribute.clone
      @dir_attribute = dir_attribute.clone
      @link_attribute = link_attribute.clone
      @sock_attribute = sock_attribute.clone

      # Set the contents of the entry field.
      fentry.setValue(@pwd)
      fentry.draw(fentry.box)

      # Get the directory contents.
      unless self.setDirContents
        CDK.Beep
        return
      end

      # Set the values in the scrolling list.
      fscroll.setItems(@dir_contents, @file_counter, false)
    end

    # This creates a list of the files in the current directory.
    def setDirContents
      dir_list = []

      # Get the directory contents
      file_count = CDK.getDirectoryContents(@pwd, dir_list)
      if file_count <= 0
        # We couldn't read the directory. Return.
        return false
      end

      @dir_contents = dir_list
      @file_counter = file_count

      # Set the properties of the files.
      (0...@file_counter).each do |x|
        attr = ''
        mode = '?'

        # FIXME(original): access() would give a more correct answer
        # TODO: add error handling
        file_stat = File.stat(dir_list[x])
        if file_stat.executable?
          mode = '*'
        else
          mode = ' '
        end

        case
        when file_stat.symlink?
          attr = @link_attribute
          mode = '@'
        when file_stat.socket?
          attr = @sock_attribute
          mode = '&'
        when file_stat.file?
          attr = @file_attribute
        when file_stat.directory?
          attr = @dir_attribute
          mode = '/'
        end
        @dir_contents[x] = '%s%s%s' % [attr, dir_list[x], mode]
      end
      return true
    end

    def getDirContents(count)
      count << @file_counter
      return @dir_contents
    end

    # This sets the current directory of the file selector.
    def setDirectory(directory)
      fentry = @entry_field
      fscroll = @scroll_field
      result = 1

      # If the directory supplied is the same as what is already there, return.
      if @pwd != directory
        # Try to chdir into the given directory.
        if Dir.chdir(directory) != 0
          result = 0
        else
          @pwd = Dir.getwd

          # Set the contents of the entry field.
          fentry.setValue(@pwd)
          fentry.draw(fentry.box)

          # Get the directory contents.
          if self.setDirContents
            # Set the values in the scrolling list.
            fscroll.setItems(@dir_contents, @file_counter, false)
          else
            result = 0
          end
        end
      end
      return result
    end

    def getDirectory
      return @pwd
    end

    # This sets the filler character of the entry field.
    def setFillerChar(filler)
      @filler_character = filler
      @entry_field.setFillerChar(filler)
    end

    def getFillerChar
      return @filler_character
    end

    # This sets the highlight bar of the scrolling list.
    def setHighlight(highlight)
      @highlight = highlight
      @scroll_field.setHighlight(highlight)
    end

    def getHighlight
      return @highlight
    end

    # This sets the attribute of the directory attribute in the
    # scrolling list.
    def setDirAttribute(attribute)
      # Make sure they are not the same.
      if @dir_attribute != attribute
        @dir_attribute = attribute
        self.setDirContents
      end
    end

    def getDirAttribute
      return @dir_attribute
    end

    # This sets the attribute of the link attribute in the scrolling list.
    def setLinkAttribute(attribute)
      # Make sure they are not the same.
      if @link_attribute != attribute
        @link_attribute = attribute
        self.setDirContents
      end
    end

    def getLinkAttribute
      return @link_attribute
    end

    # This sets the attribute of the socket attribute in the scrolling list.
    def setSocketAttribute(attribute)
      # Make sure they are not the same.
      if @sock_attribute != attribute
        @sock_attribute = attribute
        self.setDirContents
      end
    end

    def getSocketAttribute
      return @sock_attribute
    end

    # This sets the attribute of the file attribute in the scrolling list.
    def setFileAttribute(attribute)
      # Make sure they are not the same.
      if @file_attribute != attribute
        @file_attribute = attribute
        self.setDirContents
      end
    end

    def getFileAttribute
      return @file_attribute
    end

    # this sets the contents of the widget
    def setContents(list, list_size)
      scrollp = @scroll_field
      entry = @entry_field

      if !self.createList(list, list_size)
        return
      end

      # Set the information in the scrolling list.
      scrollp.set(@dir_contents, @file_counter, false, scrollp.highlight,
          scrollp.box)

      # Clean out the entry field.
      self.setCurrentItem(0)
      entry.clean

      # Redraw the widget.
      self.erase
      self.draw(@box)
    end

    def getContents(size)
      size << @file_counter
      return @dir_contents
    end

    # Get/set the current position in the scroll wiget.
    def getCurrentItem
      return @scroll_field.getCurrent
    end

    def setCurrentItem(item)
      if @file_counter != 0
        @scroll_field.setCurrent(item)

        data = self.contentToPath(@dir_contents[@scroll_field.getCurrentItem])
        @entry_field.setValue(data)
      end
    end

    # These functions set the draw characters of the widget.
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

    # This destroys the file selector.
    def destroy
      self.cleanBindings(:FSELECT)

      # Destroy the other CDK objects
      @scroll_field.destroy
      @entry_field.destroy

      # Free up the windows
      CDK.deleteCursesWindow(@shadow_win)
      CDK.deleteCursesWindow(@win)

      # Clean the key bindings.
      # Unregister the object.
      CDK::SCREEN.unregister(:FSELECT, self)
    end

    # Currently a wrapper for File.expand_path
    def self.make_pathname(directory, filename)
      if filename == '..'
        return File.expand_path(directory) + '/..'
      else
        return File.expand_path(filename, directory)
      end
    end

    # Return the plain string that corresponds to an item in dir_contents
    def contentToPath(content)
      # XXX direct translation of original but might be redundant
      temp_chtype = CDK.char2Chtype(content, [], [])
      temp_char = CDK.chtype2Char(temp_chtype)
      temp_char = temp_char[0..-1]

      # Create the pathname.
      result = CDK::FSELECT.make_pathname(@pwd, temp_char)

      return result
    end

    # Currently a wrapper for File.expand_path
    def self.expandTilde(filename)
      return File.expand_path(filename)
    end

    def destroyInfo
      @dir_contents = []
      @file_counter = 0
    end

    def createList(list, list_size)
      status = false

      if list_size >= 0
        newlist = []

        # Copy in the new information
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
          @file_counter = list_size
          @dir_contents = newlist
        end
      else
        self.destroyInfo
        status = true
      end
      return status
    end

    def focus
      @entry_field.focus
    end

    def unfocus
      @entry_field.unfocus
    end

    def self.isFullWidth(width)
      width == CDK::FULL || (Ncurses.COLS != 0 && width >= Ncurses.COLS)
    end

    def position
      super(@win)
    end

    def object_type
      :FSELECT
    end
  end

  class SLIDER < CDK::CDKOBJS
    def initialize(cdkscreen, xplace, yplace, title, label, filler,
        field_width, start, low, high, inc, fast_inc, box, shadow)
      super()
      parent_width = cdkscreen.window.getmaxx
      parent_height = cdkscreen.window.getmaxy
      bindings = {
          'u'           => Ncurses::KEY_UP,
          'U'           => Ncurses::KEY_PPAGE,
          CDK::BACKCHAR => Ncurses::KEY_PPAGE,
          CDK::FORCHAR  => Ncurses::KEY_NPAGE,
          'g'           => Ncurses::KEY_HOME,
          '^'           => Ncurses::KEY_HOME,
          'G'           => Ncurses::KEY_END,
          '$'           => Ncurses::KEY_END,
      }
      self.setBox(box)
      box_height = @border_size * 2 + 1

      # Set some basic values of the widget's data field.
      @label = []
      @label_len = 0
      @label_win = nil
      high_value_len = self.formattedSize(high)

      # If the field_width is a negative will be COLS-field_width,
      # otherwise field_width will be the given width.
      field_width = CDK.setWidgetDimension(parent_width, field_width, 0)

      # Translate the label string to a chtype array.
      if !(label.nil?) && label.size > 0
        label_len = []
        @label = CDK.char2Chtype(label, label_len, [])
        @label_len = label_len[0]
        box_width = @label_len + field_width +
            high_value_len + 2 * @border_size
      else
        box_width = field_width + high_value_len + 2 * @border_size
      end

      old_width = box_width
      box_width = self.setTitle(title, box_width)
      horizontal_adjust = (box_width - old_width) / 2

      box_height += @title_lines

      # Make sure we didn't extend beyond the dimensions of the window.
      box_width = [box_width, parent_width].min
      box_height = [box_height, parent_height].min
      field_width = [field_width,
          box_width - @label_len - high_value_len - 1].min

      # Rejustify the x and y positions if we need to.
      xtmp = [xplace]
      ytmp = [yplace]
      CDK.alignxy(cdkscreen.window, xtmp, ytmp, box_width, box_height)
      xpos = xtmp[0]
      ypos = ytmp[0]

      # Make the widget's window.
      @win = Ncurses::WINDOW.new(box_height, box_width, ypos, xpos)

      # Is the main window nil?
      if @win.nil?
        self.destroy
        return nil
      end

      # Create the widget's label window.
      if @label.size > 0
        @label_win = @win.subwin(1, @label_len,
            ypos + @title_lines + @border_size,
            xpos + horizontal_adjust + @border_size)
        if @label_win.nil?
          self.destroy
          return nil
        end
      end

      # Create the widget's data field window.
      @field_win = @win.subwin(1, field_width + high_value_len - 1,
          ypos + @title_lines + @border_size,
          xpos + @label_len + horizontal_adjust + @border_size)

      if @field_win.nil?
        self.destroy
        return nil
      end
      @field_win.keypad(true)
      @win.keypad(true)

      # Create the widget's data field.
      @screen = cdkscreen
      @window = cdkscreen.window
      @shadow_win = nil
      @box_width = box_width
      @box_height = box_height
      @field_width = field_width - 1
      @filler = filler
      @low = low
      @high = high
      @current = start
      @inc = inc
      @fastinc = fast_inc
      @accepts_focus = true
      @input_window = @win
      @shadow = shadow
      @field_edit = 0

      # Set the start value.
      if start < low
        @current = low
      end

      # Do we want a shadow?
      if shadow
        @shadow_win = Ncurses::WINDOW.new(box_height, box_width,
            ypos + 1, xpos + 1)
        if @shadow_win.nil?
          self.destroy
          return nil
        end
      end

      # Setup the key bindings.
      bindings.each do |from, to|
        self.bind(:SLIDER, from, :getc, to)
      end

      cdkscreen.register(:SLIDER, self)
    end

    # This allows the person to use the widget's data field.
    def activate(actions)
      # Draw the widget.
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

      # Set the exit type and return.
      self.setExitType(0)
      return -1
    end

    # Check if the value lies outside the low/high range. If so, force it in.
    def limitCurrentValue
      if @current < @low
        @current = @low
        CDK.Beep
      elsif @current > @high
        @current = @high
        CDK.Beep
      end
    end

    # Move the cursor to the given edit-position.
    def moveToEditPosition(new_position)
      return @field_win.wmove(0,
          @field_width + self.formattedSize(@current) - new_position)
    end

    # Check if the cursor is on a valid edit-position. This must be one of
    # the non-blank cells in the field.
    def validEditPosition(new_position)
      if new_position <= 0 || new_position >= @field_width
        return false
      end
      if self.moveToEditPosition(new_position) == Ncurses::ERR
        return false
      end
      ch = @field_win.winch
      if CDK.CharOf(ch) != ' '
        return true
      end
      if new_position > 1
        # Don't use recursion - only one level is wanted
        if self.moveToEditPosition(new_position - 1) == Ncurses::ERR
          return false
        end
        ch = @field_win.winch
        return CDK.CharOf(ch) != ' '
      end
      return false
    end

    # Set the edit position.  Normally the cursor is one cell to the right of
    # the editable field.  Moving it left, over the field, allows the user to
    # modify cells by typing in replacement characters for the field's value.
    def setEditPosition(new_position)
      if new_position < 0
        CDK.Beep
      elsif new_position == 0
        @field_edit = new_position
      elsif self.validEditPosition(new_position)
        @field_edit = new_position
      else
        CDK.Beep
      end
    end

    # Remove the character from the string at the given column, if it is blank.
    # Returns true if a change was made.
    def self.removeChar(string, col)
      result = false
      if col >= 0 && string[col] != ' '
        while col < string.size - 1
          string[col] = string[col + 1]
          col += 1
        end
        string.chop!
        result = true
      end
      return result
    end

    # Perform an editing function for the field.
    def performEdit(input)
      result = false
      modify = true
      base = @field_width
      need = self.formattedSize(@current)
      temp = ''
      col = need - @field_edit

      adj = if col < 0 then -col else 0 end
      if adj != 0
        temp  = ' ' * adj
      end
      @field_win.wmove(0, base)
      @field_win.winnstr(temp, need)
      temp << ' '
      if CDK.isChar(input)  # Replace the char at the cursor
        temp[col] = input.chr
      elsif input == Ncurses::KEY_BACKSPACE
        # delete the char before the cursor
        modify = CDK::SLIDER.removeChar(temp, col - 1)
      elsif input == Ncurses::KEY_DC
        # delete the char at the cursor
        modify = CDK::SLIDER.removeChar(temp, col)
      else
        modify = false
      end
      if modify &&
          ((value, test) = temp.scanf(self.SCAN_FMT)).size == 2 &&
          test == ' ' && value >= @low && value <= @high
        self.setValue(value)
        result = true
      end
      return result
    end

    def self.Decrement(value, by)
      if value - by < value
        value - by
      else
        value
      end
    end

    def self.Increment(value, by)
      if value + by > value
        value + by
      else
        value
      end
    end

    # This function injects a single character into the widget.
    def inject(input)
      pp_return = 1
      ret = -1
      complete = false

      # Set the exit type.
      self.setExitType(0)

      # Draw the field.
      self.drawField

      # Check if there is a pre-process function to be called.
      unless @pre_process_func.nil?
        # Call the pre-process function.
        pp_return = @pre_process_func.call(:SLIDER, self,
            @pre_process_data, input)
      end

      # Should we continue?
      if pp_return != 0
        # Check for a key binding.
        if self.checkBind(:SLIDER, input)
          complete = true
        else
          case input
          when Ncurses::KEY_LEFT
            self.setEditPosition(@field_edit + 1)
          when Ncurses::KEY_RIGHT
            self.setEditPosition(@field_edit - 1)
          when Ncurses::KEY_DOWN
            @current = CDK::SLIDER.Decrement(@current, @inc)
          when Ncurses::KEY_UP
            @current = CDK::SLIDER.Increment(@current, @inc)
          when Ncurses::KEY_PPAGE
            @current = CDK::SLIDER.Increment(@current, @fastinc)
          when Ncurses::KEY_NPAGE
            @current = CDK::SLIDER.Decrement(@current, @fastinc)
          when Ncurses::KEY_HOME
            @current = @low
          when Ncurses::KEY_END
            @current = @high
          when CDK::KEY_TAB, CDK::KEY_RETURN, Ncurses::KEY_ENTER
            self.setExitType(input)
            ret = @current
            complete = true
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
            if @field_edit != 0
              if !self.performEdit(input)
                CDK.Beep
              end
            else
              # The cursor is not within the editable text. Interpret
              # input as commands.
            case input
            when 'd'.ord, '-'.ord
              return self.inject(Ncurses::KEY_DOWN)
            when '+'.ord
              return self.inject(Ncurses::KEY_UP)
            when 'D'.ord
              return self.inject(Ncurses::KEY_NPAGE)
            when '0'.ord
              return self.inject(Ncurses::KEY_HOME)
            else
              CDK.Beep
            end
            end
          end
        end
        self.limitCurrentValue

        # Should we call a post-process?
        if !complete && !(@post_process_func.nil?)
          @post_process_func.call(:SLIDER, self, @post_process_data, input)
        end
      end

      if !complete
        self.drawField
        self.setExitType(0)
      end

      @return_data = 0
      return ret
    end

    # This moves the widget's data field to the given location.
    def move(xplace, yplace, relative, refresh_flag)
      current_x = @win.getbegx
      current_y = @win.getbegy
      xpos = xplace
      ypos = yplace

      # if this is a relative move, then we will adjust where we want
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

      # Move the window to the new location.
      self.moveCursesWindow(@win, -xdiff, -ydiff)
      self.moveCursesWindow(@label_win, -xdiff, -ydiff)
      self.moveCursesWindow(@field_win, -xdiff, -ydiff)
      self.moveCursesWindow(@shadow_win, -xdiff, -ydiff)

      # Touch the windows so they 'move'
      CDK::SCREEN.refreshCDKWindow(@screen.window)

      # Redraw the window, if they asked for it.
      if refresh_flag
        self.draw(@box)
      end
    end

    # This function draws the widget.
    def draw(box)
      # Draw the shadow.
      unless @shadow_win.nil?
        Draw.drawShadow(@shadow_win)
      end

      # Box the widget if asked.
      if box
        Draw.drawObjBox(@win, self)
      end

      self.drawTitle(@win)

      # Draw the label.
      unless @label_win.nil?
        Draw.writeChtype(@label_win, 0, 0, @label, CDK::HORIZONTAL,
            0, @label_len)
        @label_win.wrefresh
      end
      @win.wrefresh

      # Draw the field window.
      self.drawField
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
      Draw.writeCharAttrib(@field_win, @field_width, 0, @current.to_s,
          Ncurses::A_NORMAL, CDK::HORIZONTAL, 0, @current.to_s.size)

      self.moveToEditPosition(@field_edit)
      @field_win.wrefresh
    end

    # This sets the background attribute of the widget.
    def setBKattr(attrib)
      # Set the widget's background attribute.
      @win.wbkgd(attrib)
      @field_win.wbkgd(attrib)
      unless @label_win.nil?
        @label_win.wbkgd(attrib)
      end
    end

    # This function destroys the widget.
    def destroy
      self.cleanTitle
      @label = []

      # Clean up the windows.
      CDK.deleteCursesWindow(@field_win)
      CDK.deleteCursesWindow(@label_win)
      CDK.deleteCursesWindow(@shadow_win)
      CDK.deleteCursesWindow(@win)

      # Clean the key bindings.
      self.cleanBindings(:SLIDER)

      # Unregister this object.
      CDK::SCREEN.unregister(:SLIDER, self)
    end

    # This function erases the widget from the screen.
    def erase
      if self.validCDKObject
        CDK.eraseCursesWindow(@label_win)
        CDK.eraseCursesWindow(@field_win)
        CDK.eraseCursesWindow(@lwin)
        CDK.eraseCursesWindow(@shadow_win)
      end
    end

    def formattedSize(value)
      return value.to_s.size
    end

    # This function sets the low/high/current values of the widget.
    def set(low, high, value, box)
      self.setLowHigh(low, high)
      self.setValue(value)
      self.setBox(box)
    end

    # This sets the widget's value.
    def setValue(value)
      @current = value
      self.limitCurrentValue
    end

    def getValue
      return @current
    end

    # This function sets the low/high values of the widget.
    def setLowHigh(low, high)
      # Make sure the values aren't out of bounds.
      if low <= high
        @low = low
        @high = high
      elsif low > high
        @low = high
        @high = low
      end

      # Make sure the user hasn't done something silly.
      self.limitCurrentValue
    end

    def getLowValue
      return @low
    end

    def getHighValue
      return @high
    end

    def focus
      self.draw(@box)
    end

    def unfocus
      self.draw(@box)
    end

    def SCAN_FMT
      '%d%c'
    end

    def position
      super(@win)
    end

    def object_type
      :SLIDER
    end
  end

  class USLIDER < CDK::SLIDER
    # The original USlider handled unsigned values.
    # Since Ruby's typing is different this is really just SLIDER
    # but is nice it's nice to have this for compatibility/completeness
    # sake.

    def object_type
      :USLIDER
    end
  end

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

  class MATRIX < CDK::CDKOBJS
    attr_accessor :info
    attr_reader :colvalues, :row, :col, :colwidths, :filler
    attr_reader :crow, :ccol
    MAX_MATRIX_ROWS = 1000
    MAX_MATRIX_COLS = 1000

    @@g_paste_buffer = ''

    def initialize(cdkscreen, xplace, yplace, rows, cols, vrows, vcols,
        title, rowtitles, coltitles, colwidths, colvalues, rspace, cspace,
        filler, dominant, box, box_cell, shadow)
      super()
      parent_width = cdkscreen.window.getmaxx
      parent_height = cdkscreen.window.getmaxy
      box_height = 0
      box_width = 0
      max_row_title_width = 0
      row_space = [0, rspace].max
      col_space = [0, cspace].max
      begx = 0
      begy = 0
      cell_width = 0
      have_rowtitles = false
      have_coltitles = false
      bindings = {
          CDK::FORCHAR  => Ncurses::KEY_NPAGE,
          CDK::BACKCHAR => Ncurses::KEY_PPAGE,
      }

      self.setBox(box)
      borderw = if @box then 1 else 0 end

      # Make sure that the number of rows/cols/vrows/vcols is not zero.
      if rows <= 0 || cols <= 0 || vrows <= 0 || vcols <= 0
        self.destroy
        return nil
      end

      @cell = Array.new(rows + 1) { |i| Array.new(cols + 1)}
      @info = Array.new(rows + 1) { |i| Array.new(cols + 1) { |i| '' }}

      # Make sure the number of virtual cells is not larger than the
      # physical size.
      vrows = [vrows, rows].min
      vcols = [vcols, cols].min

      @rows = rows
      @cols = cols
      @colwidths = [0] * (cols + 1)
      @colvalues = [0] * (cols + 1)
      @coltitle = Array.new(cols + 1) {|i| []}
      @coltitle_len = [0] * (cols + 1)
      @coltitle_pos = [0] * (cols + 1)
      @rowtitle = Array.new(rows + 1) {|i| []}
      @rowtitle_len = [0] * (rows + 1)
      @rowtitle_pos = [0] * (rows + 1)

      # Count the number of lines in the title
      temp = title.split("\n")
      @title_lines = temp.size

      # Determine the height of the box.
      if vrows == 1
        box_height = 6 + @title_lines
      else
        if row_space == 0
          box_height = 6 + @title_lines + (vrows - 1) * 2
        else
          box_height = 3 + @title_lines + vrows * 3 +
              (vrows - 1) * (row_space - 1)
        end
      end

      # Determine the maximum row title width.
      (1..rows).each do |x|
        if !(rowtitles.nil?) && x < rowtitles.size && rowtitles[x].size > 0
          have_rowtitles = true
        end
        rowtitle_len = []
        rowtitle_pos = []
        @rowtitle[x] = CDK.char2Chtype((rowtitles[x] || ''),
            rowtitle_len, rowtitle_pos)
        @rowtitle_len[x] = rowtitle_len[0]
        @rowtitle_pos[x] = rowtitle_pos[0]
        max_row_title_width = [max_row_title_width, @rowtitle_len[x]].max
      end

      if have_rowtitles
        @maxrt = max_row_title_width + 2

        # We need to rejustify the row title cell info.
        (1..rows).each do |x|
          @rowtitle_pos[x] = CDK.justifyString(@maxrt,
              @rowtitle_len[x], @rowtitle_pos[x])
        end
      else
        @maxrt = 0
      end

      # Determine the width of the matrix.
      max_width = 2 + @maxrt
      (1..vcols).each do |x|
        max_width += colwidths[x] + 2 + col_space
      end
      max_width -= (col_space - 1)
      box_width = [max_width, box_width].max
      box_width = self.setTitle(title, box_width)

      # Make sure the dimensions of the window didn't extend
      # beyond the dimensions of the parent window
      box_width = [box_width, parent_width].min
      box_height = [box_height, parent_height].min

      # Rejustify the x and y positions if we need to.
      xtmp = [xplace]
      ytmp = [yplace]
      CDK.alignxy(cdkscreen.window, xtmp, ytmp, box_width, box_height)
      xpos = xtmp[0]
      ypos = ytmp[0]

      # Make the pop-up window.
      @win = Ncurses::WINDOW.new(box_height, box_width, ypos, xpos)

      if @win.nil?
        self.destroy
        return nil
      end

      # Make the subwindows in the pop-up.
      begx = xpos
      begy = ypos + borderw + @title_lines

      # Make the 'empty' 0x0 cell.
      @cell[0][0] = @win.subwin(3, @maxrt, begy, begx)

      begx += @maxrt + 1

      # Copy the titles into the structrue.
      (1..cols).each do |x|
        if !(coltitles.nil?) && x < coltitles.size && coltitles[x].size > 0
          have_coltitles = true
        end
        coltitle_len = []
        coltitle_pos = []
        @coltitle[x] = CDK.char2Chtype(coltitles[x] || '',
            coltitle_len, coltitle_pos)
        @coltitle_len[x] = coltitle_len[0]
        @coltitle_pos[x] = @border_size + CDK.justifyString(
            colwidths[x], @coltitle_len[x], coltitle_pos[0])
        @colwidths[x] = colwidths[x]
      end

      if have_coltitles
        # Make the column titles.
        (1..vcols).each do |x|
          cell_width = colwidths[x] + 3
          @cell[0][x] = @win.subwin(borderw, cell_width, begy, begx)
          if @cell[0][x].nil?
            self.destroy
            return nil
          end
          begx += cell_width + col_space - 1
        end
        begy += 1
      end

      # Make the main cell body
      (1..vrows).each do |x|
        if have_rowtitles
          # Make the row titles
          @cell[x][0] = @win.subwin(3, @maxrt, begy, xpos + borderw)

          if @cell[x][0].nil?
            self.destroy
            return nil
          end
        end

        # Set the start of the x position.
        begx = xpos + @maxrt + borderw

        # Make the cells
        (1..vcols).each do |y|
          cell_width = colwidths[y] + 3
          @cell[x][y] = @win.subwin(3, cell_width, begy, begx)

          if @cell[x][y].nil?
            self.destroy
            return nil
          end
          begx += cell_width + col_space - 1
          @cell[x][y].keypad(true)
        end
        begy += row_space + 2
      end
      @win.keypad(true)

      # Keep the rest of the info.
      @screen = cdkscreen
      @accepts_focus = true
      @input_window = @win
      @parent = cdkscreen.window
      @vrows = vrows
      @vcols = vcols
      @box_width = box_width
      @box_height = box_height
      @row_space = row_space
      @col_space = col_space
      @filler = filler.ord
      @dominant = dominant
      @row = 1
      @col = 1
      @crow = 1
      @ccol = 1
      @trow = 1
      @lcol = 1
      @oldcrow = 1
      @oldccol = 1
      @oldvrow = 1
      @oldvcol = 1
      @box_cell = box_cell
      @shadow = shadow
      @highlight = Ncurses::A_REVERSE
      @shadow_win = nil
      @callbackfn = lambda do |matrix, input|
        disptype = matrix.colvalues[matrix.col]
        plainchar = Display.filterByDisplayType(disptype, input)
        charcount = matrix.info[matrix.row][matrix.col].size

        if plainchar == Ncurses::ERR
          CDK.Beep
        elsif charcount == matrix.colwidths[matrix.col]
          CDK.Beep
        else
          # Update the screen.
          matrix.CurMatrixCell.wmove(1,
              matrix.info[matrix.row][matrix.col].size + 1)
          matrix.CurMatrixCell.waddch(
              if Display.isHiddenDisplayType(disptype)
              then matrix.filler
              else plainchar
              end)
          matrix.CurMatrixCell.wrefresh

          # Update the info string
          matrix.info[matrix.row][matrix.col] =
              matrix.info[matrix.row][matrix.col][0...charcount] +
              plainchar.chr
        end
      end

      # Make room for the cell information.
      (1..rows).each do |x|
        (1..cols).each do |y|
          @colvalues[y] = colvalues[y]
          @colwidths[y] = colwidths[y]
        end
      end

      @colvalues = colvalues.clone
      @colwidths = colwidths.clone

      # Do we want a shadow?
      if shadow
        @shadow_win = Ncurses::WINDOW.new(box_height, box_width,
            ypos + 1, xpos + 1)
      end

      # Set up the key bindings.
      bindings.each do |from, to|
        self.bind(:MATRIX, from, :getc, to)
      end

      # Register this baby.
      cdkscreen.register(:MATRIX, self)
    end

    # This activates the matrix.
    def activate(actions)
      self.draw(@box)

      if actions.nil? || actions.size == 0
        while true
          @input_window = self.CurMatrixCell
          @input_window.keypad(true)
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

      # Set the exit type and exit.
      self.setExitType(0)
      return -1
    end

    # This injects a single character into the matrix widget.
    def inject(input)
      refresh_cells = false
      moved_cell = false
      charcount = @info[@row][@col].size
      pp_return = 1
      ret = -1
      complete = false

      # Set the exit type.
      self.setExitType(0)

      # Move the cursor to the correct position within the cell.
      if @colwidths[@ccol] == 1
        self.CurMatrixCell.wmove(1, 1)
      else
        self.CurMatrixCell.wmove(1, @info[@row][@col].size + 1)
      end

      # Put the focus on the current cell.
      Draw.attrbox(self.CurMatrixCell, Ncurses::ACS_ULCORNER,
          Ncurses::ACS_URCORNER, Ncurses::ACS_LLCORNER,
          Ncurses::ACS_LRCORNER, Ncurses::ACS_HLINE,
          Ncurses::ACS_VLINE, Ncurses::A_BOLD)
      self.CurMatrixCell.wrefresh
      self.highlightCell

      # Check if there is a pre-process function to be called.
      unless @pre_process_func.nil?
        # Call the pre-process function.
        pp_return = @pre_process_func.call(:MATRIX, self,
            @pre_process_data, input)
      end

      # Should we continue?
      if pp_return != 0
        # Check the key bindings.
        if self.checkBind(:MATRIX, input)
          complete = true
        else
          case input
          when CDK::TRANSPOSE
          when Ncurses::KEY_HOME
          when Ncurses::KEY_END
          when Ncurses::KEY_BACKSPACE, Ncurses::KEY_DC
            if @colvalues[@col] == :VIEWONLY || charcount <= 0
              CDK.Beep
            else
              charcount -= 1
              self.CurMatrixCell.mvwdelch(1, charcount + 1)
              self.CurMatrixCell.mvwinsch(1, charcount + 1, @filler)

              self.CurMatrixCell.wrefresh
              @info[@row][@col] = @info[@row][@col][0...charcount]
            end
          when Ncurses::KEY_RIGHT, CDK::KEY_TAB
            if @ccol != @vcols
              # We are moving to the right...
              @col += 1
              @ccol += 1
              moved_cell = true
            else
              # We have to shift the columns to the right.
              if @col != @cols
                @lcol += 1
                @col += 1

                # Redraw the column titles.
                if @rows > @vrows
                  self.redrawTitles(false, true)
                end
                refresh_cells = true
                moved_cell = true
              else
                # We are at the far right column, we need to shift
                # down one row, if we can.
                if @row == @rows
                  CDK.Beep
                else
                  # Set up the columns info.
                  @col = 1
                  @lcol = 1
                  @ccol = 1

                  # Shift the rows...
                  if @crow != @vrows
                    @row += 1
                    @crow += 1
                  else
                    @row += 1
                    @trow += 1
                  end
                  self.redrawTitles(true, true)
                  refresh_cells = true
                  moved_cell = true
                end
              end
            end
          when Ncurses::KEY_LEFT, Ncurses::KEY_BTAB
            if @ccol != 1
              # We are moving to the left...
              @col -= 1
              @ccol -= 1
              moved_cell = true
            else
              # Are we at the far left?
              if @lcol != 1
                @lcol -= 1
                @col -= 1

                # Redraw the column titles.
                if @cols > @vcols
                  self.redrawTitles(false, true)
                end
                refresh_cells = true
                moved_cell = true
              else
                # Shift up one line if we can...
                if @row == 1
                  CDK.Beep
                else
                  # Set up the columns info.
                  @col = @cols
                  @lcol = @cols - @vcols + 1
                  @ccol = @vcols

                  # Shift the rows...
                  if @crow != 1
                    @row -= 1
                    @crow -= 1
                  else
                    @row -= 1
                    @trow -= 1
                  end
                  self.redrawTitles(true, true)
                  refresh_cells = true
                  moved_cell = true
                end
              end
            end
          when Ncurses::KEY_UP
            if @crow != 1
              @row -= 1
              @crow -= 1
              moved_cell = true
            else
              if @trow != 1
                @trow -= 1
                @row -= 1

                # Redraw the row titles.
                if @rows > @vrows
                  self.redrawTitles(true, false)
                end
                refresh_cells = true
                moved_cell = true
              else
                CDK.Beep
              end
            end
          when Ncurses::KEY_DOWN
            if @crow != @vrows
              @row += 1
              @crow += 1
              moved_cell = true
            else
              if @trow + @vrows - 1 != @rows
                @trow += 1
                @row += 1

                # Redraw the titles.
                if @rows > @vrows
                  self.redrawTitles(true, false)
                end
                refresh_cells = true
                moved_cell = true
              else
                CDK.Beep
              end
            end
          when Ncurses::KEY_NPAGE
            if @rows > @vrows
              if @trow + (@vrows - 1) * 2 <= @rows
                @trow += @vrows - 1
                @row += @vrows - 1
                self.redrawTitles(true, false)
                refresh_cells = true
                moved_cell = true
              else
                CDK.Beep
              end
            else
              CDK.Beep
            end
          when Ncurses::KEY_PPAGE
            if @rows > @vrows
              if @trow - (@vrows - 1) * 2 >= 1
                @trow -= @vrows - 1
                @row -= @vrows - 1
                self.redrawTitles(true, false)
                refresh_cells = true
                moved_cell = true
              else
                CDK.Beep
              end
            else
              CDK.Beep
            end
          when CDK.CTRL('G')
            self.jumpToCell(-1, -1)
            self.draw(@box)
          when CDK::PASTE
            if @@g_paste_buffer.size == 0 ||
                @@g_paste_buffer.size > @colwidths[@ccol]
              CDK.Beep
            else
              self.CurMatrixInfo = @@g_paste_buffer.clone
              self.drawCurCell
            end
          when CDK::COPY
            @@g_paste_buffer = self.CurMatrixInfo.clone
          when CDK::CUT
            @@g_paste_buffer = self.CurMatrixInfo.clone
            self.cleanCell(@trow + @crow - 1, @lcol + @ccol - 1)
            self.drawCurCell
          when CDK::ERASE
            self.cleanCell(@trow + @crow - 1, @lcol + @ccol - 1)
            self.drawCurCell
          when Ncurses::KEY_ENTER, CDK::KEY_RETURN
            if !@box_cell
              Draw.attrbox(@cell[@oldcrow][@oldccol], ' '.ord, ' '.ord,
                  ' '.ord, ' '.ord, ' '.ord, ' '.ord, Ncurses::A_NORMAL)
            else
              self.drawOldCell
            end
            self.CurMatrixCell.wrefresh
            self.setExitType(input)
            ret = 1
            complete = true
          when Ncurses::ERR
            self.setExitType(input)
            complete = true
          when CDK::KEY_ESC
            if !@box_cell
              Draw.attrbox(@cell[@oldcrow][@oldccol], ' '.ord, ' '.ord,
                  ' '.ord, ' '.ord, ' '.ord, ' '.ord, Ncurses::A_NORMAL)
            else
              self.drawOldCell
            end
            self.CurMatrixCell.wrefresh
            self.setExitType(input)
            complete = true
          when CDK::REFRESH
            @screen.erase
            @screen.refresh
          else
            @callbackfn.call(self, input)
          end
        end

        if !complete
          # Did we change cells?
          if moved_cell
            # un-highlight the old box
            if !@box_cell
              Draw.attrbox(@cell[@oldcrow][@oldccol], ' '.ord, ' '.ord,
                  ' '.ord, ' '.ord, ' '.ord, ' '.ord, Ncurses::A_NORMAL)
            else
              self.drawOldCell
            end
            @cell[@oldcrow][@oldccol].wrefresh

            # Highlight the new cell.
            Draw.attrbox(self.CurMatrixCell, Ncurses::ACS_ULCORNER,
                Ncurses::ACS_URCORNER, Ncurses::ACS_LLCORNER,
                Ncurses::ACS_LRCORNER, Ncurses::ACS_HLINE,
                Ncurses::ACS_VLINE, Ncurses::A_BOLD)
            self.CurMatrixCell.wrefresh
            self.highlightCell
          end

          # Redraw each cell
          if refresh_cells
            self.drawEachCell

            # Highlight the current cell.
            Draw.attrbox(self.CurMatrixCell, Ncurses::ACS_ULCORNER,
                Ncurses::ACS_URCORNER, Ncurses::ACS_LLCORNER,
                Ncurses::ACS_LRCORNER, Ncurses::ACS_HLINE,
                Ncurses::ACS_VLINE, Ncurses::A_BOLD)
            self.CurMatrixCell.wrefresh
            self.highlightCell
          end

          # Move to the correct position in the cell.
          if refresh_cells || moved_cell
            if @colwidths[@ccol] == 1
              self.CurMatrixCell.wmove(1, 1)
            else
              self.CurMatrixCell.wmove(1, self.CurMatrixInfo.size + 1)
            end
            self.CurMatrixCell.wrefresh
          end

          # Should we call a post-process?
          unless @post_process_func.nil?
            @post_process_func.call(:MATRIX, self, @post_process_data, input)
          end
        end
      end

      if !complete
        # Set the variables we need.
        @oldcrow = @crow
        @oldccol = @ccol
        @oldvrow = @row
        @oldvcol = @col

        # Set the exit type and exit.
        self.setExitType(0)
      end

      @result_data = ret
      return ret
    end

    # Highlight the new field.
    def highlightCell
      disptype = @colvalues[@col]
      highlight = @highlight
      infolen = @info[@row][@col].size
      
      # Given the dominance of the color/attributes, we need to set the
      # current cell attribute.
      if @dominant == CDK::ROW
        highlight = (@rowtitle[@crow][0] || 0) & Ncurses::A_ATTRIBUTES
      elsif @dominant == CDK::COL
        highlight = (@coltitle[@ccol][0] || 0) & Ncurses::A_ATTRIBUTES
      end

      # If the column is only one char.
      (1..@colwidths[@ccol]).each do |x|
        ch = if x <= infolen && !Display.isHiddenDisplayType(disptype)
             then CDK.CharOf(@info[@row][@col][x - 1])
             else @filler
             end
        self.CurMatrixCell.mvwaddch(1, x, ch.ord | highlight)
      end
      self.CurMatrixCell.wmove(1, infolen + 1)
      self.CurMatrixCell.wrefresh
    end

    # This moves the matrix field to the given location.
    def move(xplace, yplace, relative, refresh_flag)
      current_x = @win.getbegx
      current_y = @win.getbegy
      xpos = xplace
      ypos = yplace

      # if this is a relative move, then we will adjust where we want
      # to move to.
      if relative
        xpos = @win.getbegx + xplace
        ypos = @win.getbegy + yplace
      end

      # Adjust the window if we need to
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

      (0..@vrows).each do |x|
        (0..@vcols).each do |y|
          CDK.moveCursesWindow(@cell[x][y], -xdiff, -ydiff)
        end
      end

      CDK.moveCursesWindow(@shadow_win, -xdiff, -ydiff)

      # Touch the windows so they 'move'
      @screen.window.refresh

      # Redraw the window, if they asked for it.
      if refresh_flag
        self.draw(@box)
      end
    end

    # This draws a cell within a matrix.
    def drawCell(row, col, vrow, vcol, attr, box)
      disptype = @colvalues[@col]
      highlight = @filler & Ncurses::A_ATTRIBUTES
      rows = @vrows
      cols = @vcols
      infolen = @info[vrow][vcol].size

      # Given the dominance of the colors/attributes, we need to set the
      # current cell attribute.
      if @dominant == CDK::ROW
        highlight = (@rowtitle[row][0] || 0) & Ncurses::A_ATTRIBUTES
      elsif @dominant == CDK::COL
        highlight = (@coltitle[col][0] || 0) & Ncurses::A_ATTRIBUTES
      end

      # Draw in the cell info.
      (1..@colwidths[col]).each do |x|
        ch = if x <= infolen && !Display.isHiddenDisplayType(disptype)
             then CDK.CharOf(@info[vrow][vcol][x-1]).ord | highlight
             else @filler
             end
        @cell[row][col].mvwaddch(1, x, ch.ord | highlight)
      end

      @cell[row][col].wmove(1, infolen + 1)
      @cell[row][col].wrefresh

      # Only draw the box iff the user asked for a box.
      if !box
        return
      end

      # If the value of the column spacing is greater than 0 then these
      # are independent boxes
      if @col_space != 0 && @row_space != 0
        Draw.attrbox(@cell[row][col], Ncurses::ACS_ULCORNER,
            Ncurses::ACS_URCORNER, Ncurses::ACS_LLCORNER,
            Ncurses::ACS_LRCORNER, Ncurses::ACS_HLINE,
            Ncurses::ACS_VLINE, attr)
        return
      end
      if @col_space != 0 && @row_space == 0
        if row == 1
          Draw.attrbox(@cell[row][col], Ncurses::ACS_ULCORNER,
              Ncurses::ACS_URCORNER, Ncurses::ACS_LTEE,
              Ncurses::ACS_RTEE, Ncurses::ACS_HLINE,
              Ncurses::ACS_VLINE, attr)
          return
        elsif row > 1 && row < rows
          Draw.attrbox(@cell[row][col], Ncurses::ACS_LTEE, Ncurses::ACS_RTEE,
              Ncurses::ACS_LTEE, Ncurses::ACS_RTEE, Ncurses::ACS_HLINE,
              Ncurses::ACS_VLINE, attr)
          return
        elsif row == rows
          Draw.attrbox(@cell[row][col], Ncurses::ACS_LTEE, Ncurses::ACS_RTEE,
              Ncurses::ACS_LLCORNER, Ncurses::ACS_LRCORNER, Ncurses::ACS_HLINE,
              Ncurses::ACS_VLINE, attr)
          return
        end
      end
      if @col_space == 0 && @row_space != 0
        if col == 1
          Draw.attrbox(@cell[row][col], Ncurses::ACS_ULCORNER,
              Ncurses::ACS_TTEE, Ncurses::ACS_LLCORNER, Ncurses::ACS_BTEE,
              Ncurses::ACS_HLINE, Ncurses::ACS_VLINE, attr)
          return
        elsif col > 1 && col < cols
          Draw.attrbox(@cell[row][col], Ncurses::ACS_TTEE, Ncurses::ACS_TTEE,
              Ncurses::ACS_BTEE, Ncurses::ACS_BTEE, Ncurses::ACS_HLINE,
              Ncurses::ACS_VLINE, attr)
          return
        elsif col == cols
          Draw.attrbox(@cell[row][col], Ncurses::ACS_TTEE,
              Ncurses::ACS_URCORNER,Ncurses::ACS_BTEE, Ncurses::ACS_LRCORNER,
              Ncurses::ACS_HLINE, Ncurses::ACS_VLINE, attr)
          return
        end
      end

      # Start drawing the matrix.
      if row == 1
        if col == 1
          # Draw the top left corner
          Draw.attrbox(@cell[row][col], Ncurses::ACS_ULCORNER,
              Ncurses::ACS_TTEE, Ncurses::ACS_LTEE, Ncurses::ACS_PLUS,
              Ncurses::ACS_HLINE, Ncurses::ACS_VLINE, attr)
        elsif col > 1 && col < cols
          # Draw the top middle box
          Draw.attrbox(@cell[row][col], Ncurses::ACS_TTEE, Ncurses::ACS_TTEE,
              Ncurses::ACS_PLUS, Ncurses::ACS_PLUS, Ncurses::ACS_HLINE,
              Ncurses::ACS_VLINE, attr)
        elsif col == cols
          # Draw the top right corner
          Draw.attrbox(@cell[row][col], Ncurses::ACS_TTEE,
              Ncurses::ACS_URCORNER, Ncurses::ACS_PLUS, Ncurses::ACS_RTEE,
              Ncurses::ACS_HLINE, Ncurses::ACS_VLINE, attr)
        end
      elsif row > 1 && row < rows
        if col == 1
          # Draw the middle left box
          Draw.attrbox(@cell[row][col], Ncurses::ACS_LTEE, Ncurses::ACS_PLUS,
              Ncurses::ACS_LTEE, Ncurses::ACS_PLUS, Ncurses::ACS_HLINE,
              Ncurses::ACS_VLINE, attr)
        elsif col > 1 && col < cols
          # Draw the middle box
          Draw.attrbox(@cell[row][col], Ncurses::ACS_PLUS, Ncurses::ACS_PLUS,
              Ncurses::ACS_PLUS, Ncurses::ACS_PLUS, Ncurses::ACS_HLINE,
              Ncurses::ACS_VLINE, attr)
        elsif col == cols
          # Draw the middle right box
          Draw.attrbox(@cell[row][col], Ncurses::ACS_PLUS, Ncurses::ACS_RTEE,
              Ncurses::ACS_PLUS, Ncurses::ACS_RTEE, Ncurses::ACS_HLINE,
              Ncurses::ACS_VLINE, attr)
        end
      elsif row == rows
        if col == 1
          # Draw the bottom left corner
          Draw.attrbox(@cell[row][col], Ncurses::ACS_LTEE, Ncurses::ACS_PLUS,
              Ncurses::ACS_LLCORNER, Ncurses::ACS_BTEE, Ncurses::ACS_HLINE,
              Ncurses::ACS_VLINE, attr)
        elsif col > 1 && col < cols
          # Draw the bottom middle box
          Draw.attrbox(@cell[row][col], Ncurses::ACS_PLUS, Ncurses::ACS_PLUS,
              Ncurses::ACS_BTEE, Ncurses::ACS_BTEE, Ncurses::ACS_HLINE,
              Ncurses::ACS_VLINE, attr)
        elsif col == cols
          # Draw the bottom right corner
          Draw.attrbox(@cell[row][col], Ncurses::ACS_PLUS, Ncurses::ACS_RTEE,
              Ncurses::ACS_BTEE, Ncurses::ACS_LRCORNER, Ncurses::ACS_HLINE,
              Ncurses::ACS_VLINE, attr)
        end
      end

      # Highlight the current cell.
      Draw.attrbox(self.CurMatrixCell, Ncurses::ACS_ULCORNER,
          Ncurses::ACS_URCORNER, Ncurses::ACS_LLCORNER,
          Ncurses::ACS_LRCORNER, Ncurses::ACS_HLINE,
          Ncurses::ACS_VLINE, Ncurses::A_BOLD)
      self.CurMatrixCell.wrefresh
      self.highlightCell
    end

    def drawEachColTitle
      (1..@vcols).each do |x|
        unless @cell[0][x].nil?
          @cell[0][x].werase
          Draw.writeChtype(@cell[0][x],
              @coltitle_pos[@lcol + x - 1], 0,
              @coltitle[@lcol + x - 1], CDK::HORIZONTAL, 0,
              @coltitle_len[@lcol + x - 1])
          @cell[0][x].wrefresh
        end
      end
    end

    def drawEachRowTitle
      (1..@vrows).each do |x|
        unless @cell[x][0].nil?
          @cell[x][0].werase
          Draw.writeChtype(@cell[x][0],
              @rowtitle_pos[@trow + x - 1], 1,
              @rowtitle[@trow + x - 1], CDK::HORIZONTAL, 0,
              @rowtitle_len[@trow + x - 1])
          @cell[x][0].wrefresh
        end
      end
    end

    def drawEachCell
      # Fill in the cells.
      (1..@vrows).each do |x|
        (1..@vcols).each do |y|
          self.drawCell(x, y, @trow + x - 1, @lcol + y - 1,
              Ncurses::A_NORMAL, @box_cell)
        end
      end
    end

    def drawCurCell
      self.drawCell(@crow, @ccol, @row, @col, Ncurses::A_NORMAL, @box_cell)
    end

    def drawOldCell
      self.drawCell(@oldcrow, @oldccol, @oldvrow, @oldvcol,
          Ncurses::A_NORMAL, @box_cell)
    end

    # This function draws the matrix widget.
    def draw(box)
      # Did we ask for a shadow?
      unless @shadow_win.nil?
        Draw.drawShadow(@shadow_win)
      end

      # Should we box the matrix?
      if box
        Draw.drawObjBox(@win, self)
      end

      self.drawTitle(@win)

      @win.wrefresh

      self.drawEachColTitle
      self.drawEachRowTitle
      self.drawEachCell

      # Highlight the current cell.
      Draw.attrbox(self.CurMatrixCell, Ncurses::ACS_ULCORNER,
          Ncurses::ACS_URCORNER, Ncurses::ACS_LLCORNER, Ncurses::ACS_LRCORNER,
          Ncurses::ACS_HLINE, Ncurses::ACS_VLINE, Ncurses::A_BOLD)
      self.CurMatrixCell.wrefresh
      self.highlightCell
    end

    # This function destroys the matrix widget.
    def destroy
      self.cleanTitle

      # Clear the matrix windows.
      CDK.deleteCursesWindow(@cell[0][0])
      (1..@vrows).each do |x|
        CDK.deleteCursesWindow(@cell[x][0])
      end
      (1..@vcols).each do |x|
        CDK.deleteCursesWindow(@cell[0][x])
      end
      (1..@vrows).each do |x|
        (1..@vcols).each do |y|
          CDK.deleteCursesWindow(@cell[x][y])
        end
      end

      CDK.deleteCursesWindow(@shadow_win)
      CDK.deleteCursesWindow(@win)

      # Clean the key bindings.
      self.cleanBindings(:MATRIX)

      # Unregister this object.
      CDK::SCREEN.unregister(:MATRIX, self)
    end

    # This function erases the matrix widget from the screen.
    def erase
      if self.validCDKObject
        # Clear the matrix cells.
        CDK.eraseCursesWindow(@cell[0][0])
        (1..@vrows).each do |x|
          CDK.eraseCursesWindow(@cell[x][0])
        end
        (1..@vcols).each do |x|
          CDK.eraseCursesWindow(@cell[0][x])
        end
        (1..@vrows).each do |x|
          (1..@vcols).each do |y|
            CDK.eraseCursesWindow(@cell[x][y])
          end
        end
        CDK.eraseCursesWindow(@shadow_win)
        CDK.eraseCursesWindow(@win)
      end
    end

    # Set the callback function
    def setCB(callback)
      @callbackfn = callback
    end

    # This function sets the values of the matrix widget.
    def setCells(info, rows, maxcols, sub_size)
      if rows > @rows
        rows = @rows
      end

      # Copy in the new info.
      (1..rows).each do |x|
        (1..@cols).each do |y|
          if x <= rows && y <= sub_size[x]
            @info[x][y] = @info[x][y][0..[@colwidths[y], @info[x][y].size].min]
          else
            self.cleanCell(x, y)
          end
        end
      end
    end

    # This cleans out the information cells in the matrix widget.
    def clean
      (1..@rows).each do |x|
        (1..@cols).each do |y|
          self.cleanCell(x, y)
        end
      end
    end

    # This cleans one cell in the matrix widget.
    def cleanCell(row, col)
      if row > 0 && row <= @rows && col > col <= @cols
        @info[row][col] = ''
      end
    end

    # This allows us to hyper-warp to a cell
    def jumpToCell(row, col)
      new_row = row
      new_col = col

      # Only create the row scale if needed.
      if (row == -1) || (row > @rows)
        # Create the row scale widget.
        scale = CDK::SCALE.new(@screen, CDK::CENTER, CDK::CENTER,
            '<C>Jump to which row.', '</5/B>Row: ', Ncurses::A_NORMAL,
            5, 1, 1, @rows, 1, 1, true, false)

        # Activate the scale and get the row.
        new_row = scale.activate([])
        scale.destroy
      end

      # Only create the column scale if needed.
      if (col == -1) || (col > @cols)
        # Create the column scale widget.
        scale = CDK::SCALE.new(@screen, CDK::CENTER, CDK::CENTER,
            '<C>Jump to which column', '</5/B>Col: ', Ncurses::A_NORMAL,
            5, 1, 1, @cols, 1, 1, true, false)

        # Activate the scale and get the column.
        new_col = scale.activate([])
        scale.destroy
      end

      # Hyper-warp....
      if new_row != @row || @new_col != @col
        return self.moveToCell(new_row, new_col)
      else
        return 1
      end
    end

    # This allows us to move to a given cell.
    def moveToCell(newrow, newcol)
      row_shift = newrow - @row
      col_shift = newcol - @col

      # Make sure we aren't asking to move out of the matrix.
      if newrow > @rows || newcol > @cols || newrow <= 0 || newcol <= 0
        return 0
      end

      # Did we move up/down?
      if row_shift > 0
        # We are moving down
        if @vrows == @cols
          @trow = 1
          @crow = newrow
          @row = newrow
        else
          if row_shift + @vrows < @rows
            # Just shift down by row_shift
            @trow += row_shift
            @crow = 1
            @row += row_shift
          else
            # We need to munge the values
            @trow = @rows - @vrows + 1
            @crow = row_shift + @vrows - @rows + 1
            @row = newrow
          end
        end
      elsif row_shift < 0
        # We are moving up.
        if @vrows == @rows
          @trow = 1
          @row = newrow
          @crow = newrow
        else
          if row_shift + @vrows > 1
            # Just shift up by row_shift...
            @trow += row_shift
            @row += row_shift
            @crow = 1
          else
            # We need to munge the values
            @trow = 1
            @crow = 1
            @row = 1
          end
        end
      end

      # Did we move left/right?
      if col_shift > 0
        # We are moving right.
        if @vcols == @cols
          @lcol = 1
          @ccol = newcol
          @col = newcol
        else
          if col_shift + @vcols < @cols
            @lcol += col_shift
            @ccol = 1
            @col += col_shift
          else
            # We need to munge with the values
            @lcol = @cols - @vcols + 1
            @ccol = col_shift + @vcols - @cols + 1
            @col = newcol
          end
        end
      elsif col_shift < 0
        # We are moving left.
        if @vcols == @cols
          @lcol = 1
          @col = newcol
          @ccol = newcol
        else
          if col_shift + @vcols > 1
            # Just shift left by col_shift
            @lcol += col_shift
            @col += col_shift
            @ccol = 1
          else
            @lcol = 1
            @col = 1
            @ccol = 1
          end
        end
      end

      # Keep the 'old' values around for redrawing sake.
      @oldcrow = @crow
      @oldccol = @ccol
      @oldvrow = @row
      @oldvcol = @col

      return 1
    end

    # This redraws the titles indicated...
    def redrawTitles(row_titles, col_titles)
      # Redraw the row titles.
      if row_titles
        self.drawEachRowTitle
      end

      # Redraw the column titles.
      if col_titles
        self.drawEachColTitle
      end
    end

    # This sets the value of a matrix cell.
    def setCell(row, col, value)
      # Make sure the row/col combination is within the matrix.
      if row > @rows || cols > @cols || row <= 0 || col <= 0
        return -1
      end

      self.cleanCell(row, col)
      @info[row][col] = value[0...[@colwidths[col], value.size].min]
      return 1
    end

    # This gets the value of a matrix cell.
    def getCell(row, col)
      # Make sure the row/col combination is within the matrix.
      if row > @rows || col > @cols || row <= 0 || col <= 0
        return 0
      end
      return @info[row][col]
    end

    def CurMatrixCell
      return @cell[@crow][@ccol]
    end

    def CurMatrixInfo
      return @info[@trow + @crow - 1][@lcol + @ccol - 1]
    end

    # This returns the current row/col cell
    def getCol
      return @col
    end

    def getRow
      return @row
    end

    # This sets the background attribute of the widget.
    def setBKattr(attrib)
      @win.wbkgd(attrib)
      (0..@vrows).each do |x|
        (0..@vcols).each do |y|
          # wbkgd (MATRIX_CELL (widget, x, y), attrib);
        end
      end
    end

    def focus
      self.draw(@box)
    end

    def unfocus
      self.draw(@box)
    end

    def position
      super(@win)
    end

    def object_type
      :MATRIX
    end
  end

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
      current_x = @win.getbegx
      current_y = @win.getbegy
      xpos = xplace
      ypos = yplace

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

      # Move the window to the new location.
      CDK.moveCursesWindow(@win, -xdiff, -ydiff)
      CDK.moveCursesWindow(@label_win, -xdiff, -ydiff)
      CDK.moveCursesWindow(@field_win, -xdiff, -ydiff)
      CDK.moveCursesWindow(@shadow_win, -xdiff, -ydiff)

      # Touch the windows so they 'move'.
      CDK::SCREEN.refreshCDKWindow(@screen.window)

      # Redraw the window, if they asked for it.
      if refresh_flag
        self.draw(@box)
      end
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

  class SCALE < CDK::CDKOBJS
    def initialize(cdkscreen, xplace, yplace, title, label, field_attr,
        field_width, start, low, high, inc, fast_inc, box, shadow)
      super()
      parent_width = cdkscreen.window.getmaxx
      parent_height = cdkscreen.window.getmaxy
      bindings = {
          'u'           => Ncurses::KEY_UP,
          'U'           => Ncurses::KEY_PPAGE,
          CDK::BACKCHAR => Ncurses::KEY_PPAGE,
          CDK::FORCHAR  => Ncurses::KEY_NPAGE,
          'g'           => Ncurses::KEY_HOME,
          '^'           => Ncurses::KEY_HOME,
          'G'           => Ncurses::KEY_END,
          '$'           => Ncurses::KEY_END,
      }

      self.setBox(box)

      box_height = @border_size * 2 + 1
      box_width = field_width + 2 * @border_size

      # Set some basic values of the widget's data field.
      @label = []
      @label_len = 0
      @label_win = nil

      # If the field_width is a negative value, the field_width will
      # be COLS-field_width, otherwise the field_width will be the
      # given width.
      field_width = CDK.setWidgetDimension(parent_width, field_width, 0)
      box_width = field_width + 2 * @border_size

      # Translate the label string to a chtype array
      unless label.nil?
        label_len = []
        @label = CDK.char2Chtype(label, label_len, [])
        @label_len = label_len[0]
        box_width = @label_len + field_width + 2
      end

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

      # Make the widget's window.
      @win = Ncurses::WINDOW.new(box_height, box_width, ypos, xpos)

      # Is the main window nil?
      if @win.nil?
        self.destroy
        return nil
      end

      # Create the widget's label window.
      if @label.size > 0
        @label_win = @win.subwin(1, @label_len,
            ypos + @title_lines + @border_size,
            xpos + horizontal_adjust + @border_size)
        if @label_win.nil?
          self.destroy
          return nil
        end
      end

      # Create the widget's data field window.
      @field_win = @win.subwin(1, field_width,
          ypos + @title_lines + @border_size,
          xpos + @label_len + horizontal_adjust + @border_size)

      if @field_win.nil?
        self.destroy
        return nil
      end
      @field_win.keypad(true)
      @win.keypad(true)

      # Create the widget's data field.
      @screen = cdkscreen
      @parent = cdkscreen.window
      @shadow_win = nil
      @box_width = box_width
      @box_height = box_height
      @field_width = field_width
      @field_attr = field_attr
      @current = low
      @low = low
      @high = high
      @current = start
      @inc = inc
      @fastinc = fast_inc
      @accepts_focus = true
      @input_window = @win
      @shadow = shadow
      @field_edit = 0

      # Do we want a shadow?
      if shadow
        @shadow_win = Ncurses::WINDOW.new(box_height, box_width,
            ypos + 1, xpos + 1)
        if @shadow_win.nil?
          self.destroy
          return nil
        end
      end

      # Setup the key bindings.
      bindings.each do |from, to|
        self.bind(self.object_type, from, :getc, to)
      end

      cdkscreen.register(self.object_type, self)
    end

    # This allows the person to use the widget's data field.
    def activate(actions)
      ret = -1
      # Draw the widget.
      self.draw(@box)

      if actions.nil? || actions.size == 0
        input = 0
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
        end
        if @exit_type != :EARLY_EXIT
          return ret
        end
      end

      # Set the exit type and return.
      self.setExitType(0)
      return ret
    end

    # Check if the value lies outsid the low/high range. If so, force it in.
    def limitCurrentValue
      if @current < @low
        @current = @low
        CDK.Beep
      elsif @current > @high
        @current = @high
        CDK.Beep
      end
    end

    # Move the cursor to the given edit-position
    def moveToEditPosition(new_position)
      return @field_win.wmove(0, @field_width - new_position - 1)
    end

    # Check if the cursor is on a valid edit-position. This must be one of
    # the non-blank cells in the field.
    def validEditPosition(new_position)
      if new_position <= 0 || new_position >= @field_width
        return false
      end
      if self.moveToEditPosition(new_position) == Ncurses::ERR
        return false
      end
      ch = @field_win.winch
      if ch.chr != ' '
        return true
      end
      if new_position > 1
        # Don't use recursion - only one level is wanted
        if self.moveToEditPosition(new_position - 1) == Ncurses::ERR
          return false
        end
        ch = @field_win.winch
        return ch.chr != ' '
      end
      return false
    end

    # Set the edit position. Normally the cursor is one cell to the right of
    # the editable field.  Moving it left over the field allows the user to
    # modify cells by typing in replacement characters for the field's value.
    def setEditPosition(new_position)
      if new_position < 0
        CDK.Beep
      elsif new_position == 0
        @field_edit = new_position
      elsif self.validEditPosition(new_position)
        @field_edit = new_position
      else
        CDK.Beep
      end
    end

    # Remove the character from the string at the given column, if it is blank.
    # Returns true if a change was made.
    def self.removeChar(string, col)
      result = false
      if col >= 0 && string[col] != ' '
        while col < string.size - 1
          string[col] = string[col + 1]
          col += 1
        end
        string.chop!
        result = true
      end
      return result
    end

    # Perform an editing function for the field.
    def performEdit(input)
      result = false
      modify = true
      base = 0
      need = @field_width
      temp = ''
      col = need - @field_edit - 1

      @field_win.wmove(0, base)
      @field_win.winnstr(temp, need)
      temp << ' '
      if CDK.isChar(input)  # Replace the char at the cursor
        temp[col] = input.chr
      elsif input == Ncurses::KEY_BACKSPACE
        # delete the char before the cursor
        modify = CDK::SCALE.removeChar(temp, col - 1)
      elsif input == Ncurses::KEY_DC
        # delete the char at the cursor
        modify = CDK::SCALE.removeChar(temp, col)
      else
        modify = false
      end
      if modify &&
          ((value, test) = temp.scanf(self.SCAN_FMT)).size == 2 &&
          test == ' ' &&
          value >= @low && value <= @high
        self.setValue(value)
        result = true
      end

      return result
    end

    def self.Decrement(value, by)
      if value - by < value
        value - by
      else
        value
      end
    end

    def self.Increment(value, by)
      if value + by > value
        value + by
      else
        value
      end
    end

    # This function injects a single character into the widget.
    def inject(input)
      pp_return = 1
      ret = -1
      complete = false

      # Set the exit type.
      self.setExitType(0)

      # Draw the field.
      self.drawField

      # Check if there is a pre-process function to be called.
      unless @pre_process_func.nil?
        # Call the pre-process function.
        pp_return = @pre_process_func.call(self.object_type, self,
            @pre_process_data, input)
      end

      # Should we continue?
      if pp_return != 0
        # Check for a key bindings.
        if self.checkBind(self.object_type, input)
          complete = true
        else
          case input
          when Ncurses::KEY_LEFT
            self.setEditPosition(@field_edit + 1)
          when Ncurses::KEY_RIGHT
            self.setEditPosition(@field_edit - 1)
          when Ncurses::KEY_DOWN
            @current = CDK::SCALE.Decrement(@current, @inc)
          when Ncurses::KEY_UP
            @current = CDK::SCALE.Increment(@current, @inc)
          when Ncurses::KEY_PPAGE
            @current = CDK::SCALE.Increment(@current, @fastinc)
          when Ncurses::KEY_NPAGE
            @current = CDK::SCALE.Decrement(@current, @fastinc)
          when Ncurses::KEY_HOME
            @current = @low
          when Ncurses::KEY_END
            @current = @high
          when CDK::KEY_TAB, CDK::KEY_RETURN, Ncurses::KEY_ENTER
            self.setExitType(input)
            ret = @current
            complete = true
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
            if @field_edit != 0
              if !self.performEdit(input)
                CDK.Beep
              end
            else
              # The cursor is not within the editable text. Interpret
              # input as commands.
              case input
              when 'd'.ord, '-'.ord
                return self.inject(Ncurses::KEY_DOWN)
              when '+'.ord
                return self.inject(Ncurses::KEY_UP)
              when 'D'.ord
                return self.inject(Ncurses::KEY_NPAGE)
              when '0'.ord
                return self.inject(Ncurses::KEY_HOME)
              else
                CDK.Beep
              end
            end
          end
        end
        self.limitCurrentValue

        # Should we call a post-process?
        if !complete && !(@post_process_func).nil?
          @post_process_func.call(self.object_type, self,
              @post_process_data, input)
        end
      end

      if !complete
        self.drawField
        self.setExitType(0)
      end

      @result_data = ret
      return ret
    end

    # This moves the widget's data field to the given location.
    def move(xplace, yplace, relative, refresh_flag)
      current_x = @win.getbegx
      current_y = @win.getbegy
      xpos = xplace
      ypos = yplace

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

      # Get the difference
      xdiff = current_x - xpos
      ydiff = current_y - ypos

      # Move the window to the new location.
      CDK.moveCursesWindow(@win, -xdiff, -ydiff)
      CDK.moveCursesWindow(@label_win, -xdiff, -ydiff)
      CDK.moveCursesWindow(@field_win, -xdiff, -ydiff)
      CDK.moveCursesWindow(@shadow_win, -xdiff, -ydiff)

      # Touch the windows so they 'move'.
      CDK::SCREEN.refreshCDKWindow(@screen.window)

      # Redraw the window, if they asked for it.
      if refresh_flag
        self.draw(@box)
      end
    end

    # This function draws the widget.
    def draw(box)
      # Draw the shadow.
      unless @shadow_win.nil?
        Draw.drawShadow(@shadow_win)
      end

      # Box the widget if asked.
      if box
        Draw.drawObjBox(@win, self)
      end

      self.drawTitle(@win)

      # Draw the label.
      unless @label_win.nil?
        Draw.writeChtype(@label_win, 0, 0, @label, CDK::HORIZONTAL,
            0, @label_len)
        @label_win.wrefresh
      end
      @win.wrefresh

      # Draw the field window.
      self.drawField
    end

    # This draws the widget.
    def drawField
      @field_win.werase

      # Draw the value in the field.
      temp = @current.to_s
      Draw.writeCharAttrib(@field_win,
          @field_width - temp.size - 1, 0, temp, @field_attr,
          CDK::HORIZONTAL, 0, temp.size)

      self.moveToEditPosition(@field_edit)
      @field_win.wrefresh
    end

    # This sets the background attribute of teh widget.
    def setBKattr(attrib)
      @win.wbkgd(attrib)
      @field_win.wbkgd(attrib)
      unless @label_win.nil?
        @label_win.wbkgd(attrib)
      end
    end

    # This function destroys the widget.
    def destroy
      self.cleanTitle
      @label = []
      
      # Clean up the windows.
      CDK.deleteCursesWindow(@field_win)
      CDK.deleteCursesWindow(@label_win)
      CDK.deleteCursesWindow(@shadow_win)
      CDK.deleteCursesWindow(@win)

      # Clean the key bindings.
      self.cleanBindings(self.object_type)

      # Unregister this object
      CDK::SCREEN.unregister(self.object_type, self)
    end

    # This function erases the widget from the screen.
    def erase
      if self.validCDKObject
        CDK.eraseCursesWindow(@label_win)
        CDK.eraseCursesWindow(@field_win)
        CDK.eraseCursesWindow(@win)
        CDK.eraseCursesWindow(@shadow_win)
      end
    end

    # This function sets the low/high/current values of the widget.
    def set(low, high, value, box)
      self.setLowHigh(low, high)
      self.setValue(value)
      self.setBox(box)
    end

    # This sets the widget's value
    def setValue(value)
      @current = value
      self.limitCurrentValue
    end

    def getValue
      return @current
    end

    # This function sets the low/high values of the widget.
    def setLowHigh(low, high)
      # Make sure the values aren't out of bounds.
      if low <= high
        @low = low
        @high = high
      elsif low > high
        @low = high
        @high = low
      end

      # Make sure the user hasn't done something silly.
      self.limitCurrentValue
    end

    def getLowValue
      return @low
    end

    def getHighValue
      return @high
    end

    def focus
      self.draw(@box)
    end

    def unfocus
      self.draw(@box)
    end

    def position
      super(@win)
    end

    def SCAN_FMT
      '%d%c'
    end

    def object_type
      :SCALE
    end
  end

  class USCALE < CDK::SCALE
    # The original UScale handled unsigned values.
    # Since Ruby's typing is different this is really just SCALE
    # but is nice it's nice to have this for compatibility/completeness
    # sake.

    def object_type
      :USCALE
    end
  end

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

  class DSCALE < CDK::FSCALE
    # The original DScale handled unsigned values.
    # Since Ruby's typing is different this is really just FSCALE
    # but is nice it's nice to have this for compatibility/completeness
    # sake.
    def object_type
      :DSCALE
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
          window.mvwvline(starty, startx, line, ydiff)
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
      when :CHAR, :INT, :INVALID, :LCHAR, :LMIXED, :MIXED, :UCHAR,
          :UMIXED, :VIEWONLY
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

  module Traverse
    def Traverse.resetCDKScreen(screen)
      refreshDataCDKScreen(screen)
    end

    def Traverse.exitOKCDKScreen(screen)
      screen.exit_status = CDK::SCREEN::EXITOK
    end

    def Traverse.exitCancelCDKScreen(screen)
      screen.exit_status = CDK::SCREEN::EXITCANCEL
    end

    def Traverse.exitOKCDKScreenOf(obj)
      exitOKCDKScreen(obj.screen)
    end

    def Traverse.exitCancelCDKScreenOf(obj)
      exitCancelCDKScreen(obj.screen)
    end

    def Traverse.resetCDKScreenOf(obj)
      resetCDKScreen(obj.screen)
    end

    # Returns the object on which the focus lies.
    def Traverse.getCDKFocusCurrent(screen)
      result = nil
      n = screen.object_focus

      if n >= 0 && n < screen.object_count
        result = screen.object[n]
      end

      return result
    end

    # Set focus to the next object, returning it.
    def Traverse.setCDKFocusNext(screen)
      result = nil
      curobj = nil
      n = getFocusIndex(screen)
      first = n
      
      while true
        n+= 1
        if n >= screen.object_count
          n = 0
        end
        curobj = screen.object[n]
        if !(curobj.nil?) && curobj.accepts_focus
          result = curobj
          break
        else
          if n == first
            break
          end
        end
      end

      setFocusIndex(screen, if !(result.nil?) then n else -1 end)
      return result
    end

    # Set focus to the previous object, returning it.
    def Traverse.setCDKFocusPrevious(screen)
      result = nil
      curobj = nil
      n = getFocusIndex(screen)
      first = n

      while true
        n -= 1
        if n < 0
          n = screen.object_count - 1
        end
        curobj = screen.object[n]
        if !(curobj.nil?) && curobj.accepts_focus
          result = curobj
          break
        elsif n == first
          break
        end
      end

      setFocusIndex(screen, if !(result.nil?) then n else -1 end)
      return result
    end

    # Set focus to a specific object, returning it.
    # If the object cannot be found, return nil.
    def Traverse.setCDKFocusCurrent(screen, newobj)
      result = nil
      curobj = nil
      n = getFocusIndex(screen)
      first = n

      while true
        n += 1
        if n >= screen.object_count
          n = 0
        end

        curobj = screen.object[n]
        if curobj == newobj
          result = curobj
          break
        elsif n == first
          break
        end
      end

      setFocusIndex(screen, if !(result.nil?) then n else -1 end)
      return result
    end

    # Set focus to the first object in the screen.
    def Traverse.setCDKFocusFirst(screen)
      setFocusIndex(screen, screen.object_count - 1)
      return switchFocus(setCDKFocusNext(screen), nil)
    end

    # Set focus to the last object in the screen.
    def Traverse.setCDKFocusLast(screen)
      setFocusIndex(screen, 0)
      return switchFocus(setCDKFocusPrevious(screen), nil)
    end

    def Traverse.traverseCDKOnce(screen, curobj, key_code,
        function_key, func_menu_key)
      case key_code
      when Ncurses::KEY_BTAB
        switchFocus(setCDKFocusPrevious(screen), curobj)
      when CDK::KEY_TAB
        switchFocus(setCDKFocusNext(screen), curobj)
      when CDK.KEY_F(10)
        # save data and exit
        exitOKCDKScreen(screen)
      when CDK.CTRL('X')
        exitCancelCDKScreen(screen)
      when CDK.CTRL('R')
        # reset data to defaults
        resetCDKScreen(screen)
        setFocus(curobj)
      when CDK::REFRESH
        # redraw screen
        refreshCDKScreen(screen)
        setFocus(curobj)
      else
        # not everyone wants menus, so we make them optional here
        if !(func_menu_key.nil?) &&
            (func_menu_key.call(key_code, function_key) != 0)
          # find and enable drop down menu
          screen.object.each do |object|
            if !(object.nil?) && object.object_type == :MENU
              Traverse.handleMenu(screen, object, curobj)
            end
          end
        else
          curobj.inject(key_code)
        end
      end
    end

    # Traverse the widgets on a screen.
    def Traverse.traverseCDKScreen(screen)
      result = 0
      curobj = setCDKFocusFirst(screen)

      unless curobj.nil?
        refreshDataCDKScreen(screen)

        screen.exit_status = CDK::SCREEN::NOEXIT

        while !((curobj = getCDKFocusCurrent(screen)).nil?) &&
            screen.exit_status == CDK::SCREEN::NOEXIT
          function = []
          key = curobj.getch(function)

          screen.popupLabel([key.to_s], 1)

          # TODO look at more direct way to do this
          check_menu_key = lambda do |key_code, function_key|
            Traverse.checkMenuKey(key_code, function_key)
          end

          Traverse.traverseCDKOnce(screen, curobj, key,
              function[0], check_menu_key)
        end

        if screen.exit_status == CDK::SCREEN::EXITOK
          saveDataCDKScreen(screen)
          result = 1
        end
      end
      return result
    end

    private

    def Traverse.limitFocusIndex(screen, value)
      if value >= screen.object_count || value < 0
        0
      else
        value
      end
    end

    def Traverse.getFocusIndex(screen)
      return limitFocusIndex(screen, screen.object_focus)
    end

    def Traverse.setFocusIndex(screen, value)
      screen.object_focus = limitFocusIndex(screen, value)
    end

    def Traverse.unsetFocus(obj)
      Ncurses.curs_set(0)
      unless obj.nil?
        obj.has_focus = false
        obj.unfocus
      end
    end

    def Traverse.setFocus(obj)
      unless obj.nil?
        obj.has_focus = true
        obj.focus
      end
      Ncurses.curs_set(1)
    end

    def Traverse.switchFocus(newobj, oldobj)
      if oldobj != newobj
        Traverse.unsetFocus(oldobj)
        Traverse.setFocus(newobj)
      end
      return newobj
    end

    def Traverse.checkMenuKey(key_code, function_key)
      key_code == CDK::KEY_ESC && !function_key
    end

    def Traverse.handleMenu(screen, menu, oldobj)
      done = false

      switchFocus(menu, oldobj)
      while !done
        key = menu.getch([])

        case key
        when CDK::KEY_TAB
          done = true
        when CDK::KEY_ESC
          # cleanup the menu
          menu.inject(key)
          done = true
        else
          done = menu.inject(key)
        end
      end

      if (newobj = Traverse.getCDKFocusCurrent(screen)).nil?
        newobj = Traverse.setCDKFocusNext(screen);
      end

      return switchFocus(newobj, menu)
    end

    # Save data in widgets on a screen
    def Traverse.saveDataCDKScreen(screen)
      screen.object.each do |object|
        unless object.nil?
          object.saveData
        end
      end
    end

    # Refresh data in widgets on a screen
    def Traverse.refreshDataCDKScreen(screen)
      screen.object.each do |object|
        unless object.nil?
          object.refreshData
        end
      end
    end
  end
end
