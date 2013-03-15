module CDK
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
end
