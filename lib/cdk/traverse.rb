module CDK
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
        screen.refresh
        setFocus(curobj)
      else
        # not everyone wants menus, so we make them optional here
        if !(func_menu_key.nil?) &&
            (func_menu_key.call(key_code, function_key))
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
          done = (menu.inject(key) >= 0)
        end
      end

      if (newobj = Traverse.getCDKFocusCurrent(screen)).nil?
        newobj = Traverse.setCDKFocusNext(screen)
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
