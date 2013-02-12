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
  
  # This beeps then flushes the stdout stream
  def CDK.Beep
    Ncurses.beep
    $stdout.flush
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
        pair = string[from + 1..form + 2].to_i
        mask[0] = Ncurses.COLOR_PAIR(pair)
      else
        mask[0] = Ncurses.A_BOLD
      end

      from += 2
    elsif CDK.digit?(string[from + 1])
      if Ncurses.has_colors?
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

    # We make two passes because we may have indents and tabs to expand and do
    # not know in advance how large the result will be.
    if string.size > 0
      used = 0
      [0, 1].each do |pass|
        adjust = 0
        attrib = Ncurses::A_NORMAL
        last_char = 0
        start = 0
        used = 0
        x = 3

        # Look for an alignment marker.
        if string[0] == Ncurses::L_MARKER
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
            result = [' ', ' ', ' ']

            # Pull out the bullet marker.
            while x < string.size and string[x] != R_MARKER
              result << string[x] | Ncurses::A_BOLD
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
              result << (string[from] | attrib)
              used += 1
              from += 1
            elsif string[from] == "\t"
              begin
                result << ' '
                used += 1
              end while (used & 7).nonzero?
            else
              result << (string[from] || attrib)
              used += 1
            end
          else
            case string[from]
            when R_MARKER
              inside_marker = 0
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
        end

        if result.size = 0
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
  def checkForLink (line, filename)
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
  def baseName (pathname)
    File.basename(pathname)
  end

  # Returns the directory for the given pathname, i.e. the part before the
  # last slash
  # For now this function is just a wrapper for File.dirname kept for ease of
  # porting and will be completely replaced in the future
  def dirName (pathname)
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
    '0'.ord <= character.ord and character.ord <= '9'.ord
  end

end
