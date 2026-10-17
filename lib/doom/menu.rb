# DOOM generic portado do python_doom para Ruby.
#
# Por Wagner Nunes da Silva
#
# vagucs@bol.com.br
# vagucs@vagucs.com.br
# vagucs@gmail.com
#
# www.vagucs.com.br
#
# Menu do titulo: jogo novo, habilidade, episodio, opcoes e som.

module Doom
  class MenuGame
    attr_accessor :show_messages, :detail_level, :screen_size, :mouse_sensitivity,
                  :sound, :player, :running, :in_level, :use_mouse,
                  :on_new_game, :on_title, :on_view, :on_save, :on_load, :iwad_path

    def initialize
      @show_messages = true
      @detail_level = 0
      @screen_size = 7
      @mouse_sensitivity = 5
      @running = true
      @in_level = false
      @use_mouse = true
    end

    def gamestate
      @in_level ? Defs::GS_LEVEL : Defs::GS_TITLE
    end

    def apply_view_size
      @on_view&.call
    end

    def start_new_game(skill, episode, mapn)
      @on_new_game&.call(skill, episode, mapn)
    end

    def return_to_title
      @on_title&.call
    end

    def save_game(slot, description)
      @on_save&.call(slot, description) ? true : false
    end

    def load_game(slot)
      @on_load&.call(slot) ? true : false
    end
  end

  class MenuItem
    attr_accessor :status, :name, :action

    def initialize(status, name, action)
      @status = status
      @name = name
      @action = action
    end
  end

  class MenuDef
    attr_accessor :items, :routine, :x, :y, :last_on, :prev

    def initialize(items, routine, x, y, last_on: 0, prev: nil)
      @items = items
      @routine = routine
      @x = x
      @y = y
      @last_on = last_on
      @prev = prev
    end
  end

  class Menu
    LINEHEIGHT = 16
    SKULLXOFF = -32
    KEY_ESCAPE = 27
    KEY_RETURN = 13
    KEY_KP_ENTER = 1_073_741_912
    KEY_BACKSPACE = 8
    KEY_UP = 1_073_741_906
    KEY_DOWN = 1_073_741_905
    KEY_LEFT = 1_073_741_904
    KEY_RIGHT = 1_073_741_903
    KEY_F1 = 1_073_741_882
    KEY_F2 = 1_073_741_883
    KEY_F3 = 1_073_741_884
    KEY_Y = 121
    KEY_N = 110

    attr_reader :active, :screen

    def initialize(wad, sound, game)
      @wad = wad
      @sound = sound
      @game = game
      @active = false
      @screen = 'main'
      @item_on = 0
      @which_skull = 0
      @skull_tics = 8
      @epi = 0
      @message = nil
      @message_confirm = false
      @message_action = nil
      @save_strings = [Defs::LOADSAVEEMPTY] * 6
      @save_slot_ok = [false] * 6
      @save_string_enter = false
      @save_slot = 0
      @save_old_string = ''
      @save_char_index = 0
      @menus = {
        'main' => MenuDef.new(
          [
            MenuItem.new(1, 'M_NGAME', 'newgame'),
            MenuItem.new(1, 'M_OPTION', 'options'),
            MenuItem.new(1, 'M_LOADG', 'loadgame'),
            MenuItem.new(1, 'M_SAVEG', 'savegame'),
            MenuItem.new(1, 'M_RDTHIS', 'readthis'),
            MenuItem.new(1, 'M_QUITG', 'quit')
          ],
          'main', 97, 64
        ),
        'episode' => MenuDef.new(
          [
            MenuItem.new(1, 'M_EPI1', 'episode'),
            MenuItem.new(1, 'M_EPI2', 'episode'),
            MenuItem.new(1, 'M_EPI3', 'episode'),
            MenuItem.new(1, 'M_EPI4', 'episode')
          ],
          'episode', 48, 63, prev: 'main'
        ),
        'skill' => MenuDef.new(
          [
            MenuItem.new(1, 'M_JKILL', 'skill'),
            MenuItem.new(1, 'M_ROUGH', 'skill'),
            MenuItem.new(1, 'M_HURT', 'skill'),
            MenuItem.new(1, 'M_ULTRA', 'skill'),
            MenuItem.new(1, 'M_NMARE', 'skill')
          ],
          'skill', 48, 63, last_on: 2, prev: 'episode'
        ),
        'options' => MenuDef.new(
          [
            MenuItem.new(1, 'M_ENDGAM', 'endgame'),
            MenuItem.new(1, 'M_MESSG', 'messages'),
            MenuItem.new(1, 'M_DETAIL', 'detail'),
            MenuItem.new(2, 'M_SCRNSZ', 'scrnsize'),
            MenuItem.new(-1, '', ''),
            MenuItem.new(2, 'M_MSENS', 'mousesens'),
            MenuItem.new(-1, '', ''),
            MenuItem.new(1, 'M_SVOL', 'sound')
          ],
          'options', 60, 37, prev: 'main'
        ),
        'sound' => MenuDef.new(
          [
            MenuItem.new(2, 'M_SFXVOL', 'sfxvol'),
            MenuItem.new(-1, '', ''),
            MenuItem.new(2, 'M_MUSVOL', 'musvol'),
            MenuItem.new(-1, '', '')
          ],
          'sound', 80, 64, prev: 'options'
        ),
        'load' => MenuDef.new(Array.new(6) { MenuItem.new(1, '', 'loadslot') }, 'load', 80, 54, prev: 'main'),
        'save' => MenuDef.new(Array.new(6) { MenuItem.new(1, '', 'saveslot') }, 'save', 80, 54, prev: 'main'),
        'read1' => MenuDef.new([MenuItem.new(1, '', 'read2')], 'read1', 280, 185, prev: 'main'),
        'read2' => MenuDef.new([MenuItem.new(1, '', 'finishread')], 'read2', 330, 175, prev: 'read1')
      }
      @menus['skill'].prev = 'main' unless episodes?
    end

    def ticker
      return unless @active

      @skull_tics -= 1
      return if @skull_tics.positive?

      @which_skull ^= 1
      @skull_tics = 8
    end

    def start
      return if @active

      @active = true
      @screen = 'main'
      @item_on = @menus['main'].last_on
      @message = nil
      @save_string_enter = false
      @sound.play('swtchn')
    end

    def clear
      @active = false
      @message = nil
      @save_string_enter = false
    end

    def responder(key, char = '')
      return save_string_key(key, char) if @save_string_enter

      if @message
        if @message_confirm
          if [KEY_Y, KEY_RETURN, KEY_KP_ENTER].include?(key)
            action = @message_action
            @message = nil
            @game.running = false if action == 'quit'
            @game.return_to_title if action == 'endgame'
            return true
          end
          if [KEY_N, KEY_ESCAPE].include?(key)
            @message = nil
            return true
          end
          return true
        end
        if key != 0
          @message = nil
          return true
        end
      end
      if key == KEY_F2
        do_action('savegame', 0)
        return true
      end
      if key == KEY_F3
        do_action('loadgame', 0)
        return true
      end
      if key == KEY_F1
        open_help
        return true
      end
      unless @active
        if key == KEY_ESCAPE
          start
          return true
        end
        return false
      end

      menu = @menus[@screen]
      if key == KEY_ESCAPE
        menu.last_on = @item_on
        clear
        @sound.play('swtchx')
        return true
      end
      if key == KEY_BACKSPACE
        menu.last_on = @item_on
        if menu.prev
          @screen = menu.prev
          @item_on = @menus[@screen].last_on
          @sound.play('swtchx')
        else
          clear
          @sound.play('swtchx')
        end
        return true
      end
      if key == KEY_DOWN
        move_item(1)
        return true
      end
      if key == KEY_UP
        move_item(-1)
        return true
      end
      if [KEY_LEFT, KEY_RIGHT].include?(key)
        item = menu.items[@item_on]
        if item.status == 2 && !item.action.empty?
          @sound.play('stnmov')
          do_action(item.action, key == KEY_LEFT ? 0 : 1)
        end
        return true
      end
      if [KEY_RETURN, KEY_KP_ENTER].include?(key)
        item = menu.items[@item_on]
        if item.status != 0
          menu.last_on = @item_on
          @sound.play('pistol')
          do_action(item.action, item.status == 2 ? 1 : @item_on)
        end
        return true
      end
      true
    end

    def draw(fb)
      return unless @active

      if @message
        draw_message(fb)
        return
      end
      menu = @menus[@screen]
      draw_routine(fb, menu)
      unless %w[read1 read2 load save].include?(menu.routine)
        y = menu.y
        menu.items.each do |item|
          unless item.name.empty?
            patch = lump(item.name)
            VVideo.draw_patch(fb, menu.x, y, patch) if patch
          end
          y += LINEHEIGHT
        end
      end
      if menu.routine == 'options'
        draw_thermo(fb, menu.x, menu.y + (LINEHEIGHT * 4), 9, @game.screen_size)
        draw_thermo(fb, menu.x, menu.y + (LINEHEIGHT * 6), 10, @game.mouse_sensitivity)
      elsif menu.routine == 'sound'
        draw_thermo(fb, menu.x, menu.y + LINEHEIGHT, 16, @game.sound.sfx_volume)
        draw_thermo(fb, menu.x, menu.y + (LINEHEIGHT * 3), 16, @game.sound.music_volume)
      end
      skull = lump(@which_skull == 1 ? 'M_SKULL2' : 'M_SKULL1')
      return unless skull && !%w[read1 read2].include?(menu.routine)

      VVideo.draw_patch(fb, menu.x + SKULLXOFF, menu.y - 5 + (@item_on * LINEHEIGHT), skull)
    end

    private

    def episodes?
      return false if @wad.check_num_for_name('MAP01') >= 0

      @wad.check_num_for_name('E2M1') >= 0
    end

    def lump(name)
      number = @wad.check_num_for_name(name)
      return nil if number.negative?

      @wad.cache_lump_num(number)
    end

    def move_item(step)
      menu = @menus[@screen]
      n = menu.items.length
      loop do
        @item_on = (@item_on + step) % n
        @sound.play('pstop')
        break if menu.items[@item_on].status != -1
      end
    end

    def do_action(action, choice)
      case action
      when 'newgame'
        if @wad.check_num_for_name('MAP01') >= 0 || !episodes?
          @epi = 0
          goto('skill')
        else
          goto('episode')
        end
      when 'options'
        goto('options')
      when 'loadgame'
        open_load
      when 'savegame'
        if @game.gamestate != Defs::GS_LEVEL || @game.player.nil?
          @sound.play('oof')
        else
          open_save
        end
      when 'loadslot'
        if !@save_slot_ok[choice] || !@game.load_game(choice)
          @sound.play('oof')
        else
          clear
        end
      when 'saveslot'
        begin_save_name(choice)
      when 'readthis'
        goto('read1')
      when 'read2'
        if has?('HELP1') && @screen == 'read1'
          goto('read2')
        else
          goto('main')
        end
      when 'finishread'
        goto('main')
      when 'quit'
        @message = 'ARE YOU SURE YOU WANT TO QUIT?'
        @message_confirm = true
        @message_action = 'quit'
      when 'endgame'
        if @game.gamestate != Defs::GS_LEVEL
          @sound.play('oof')
        else
          @message = 'END GAME?'
          @message_confirm = true
          @message_action = 'endgame'
        end
      when 'sound'
        goto('sound')
      when 'messages'
        @game.show_messages = !@game.show_messages
        @game.player&.set_message(@game.show_messages ? 'Messages On' : 'Messages Off')
      when 'detail'
        @game.detail_level = @game.detail_level.zero? ? 1 : 0
        @game.apply_view_size
        @game.player&.set_message(@game.detail_level.zero? ? 'High detail' : 'Low detail')
      when 'scrnsize'
        if choice != 0
          @game.screen_size += 1 if @game.screen_size < 8
        elsif @game.screen_size.positive?
          @game.screen_size -= 1
        end
        @game.apply_view_size
      when 'mousesens'
        if choice != 0
          @game.mouse_sensitivity += 1 if @game.mouse_sensitivity < 9
        elsif @game.mouse_sensitivity.positive?
          @game.mouse_sensitivity -= 1
        end
      when 'sfxvol'
        vol = @game.sound.sfx_volume
        @game.sound.set_sfx_volume(choice != 0 ? [15, vol + 1].min : [0, vol - 1].max)
      when 'musvol'
        vol = @game.sound.music_volume
        @game.sound.set_music_volume(choice != 0 ? [15, vol + 1].min : [0, vol - 1].max)
      when 'episode'
        if !has?('E2M1') && choice != 0
          @message = 'ONLY AVAILABLE IN THE REGISTERED VERSION.'
          @message_confirm = false
          @message_action = nil
          goto('read1')
          return
        end
        @epi = choice
        goto('skill')
      when 'skill'
        @game.start_new_game(choice, @epi + 1, 1)
        clear
      end
    end

    def open_help
      @active = true
      @message = nil
      @save_string_enter = false
      @menus['read1'].last_on = 0
      @screen = 'read1'
      @item_on = 0
      @sound.play('swtchn')
    end

    def goto(name)
      @menus[@screen].last_on = @item_on
      @screen = name
      @item_on = @menus[name].last_on
    end

    def read_save_strings
      6.times do |i|
        desc, ok = Saveg.read_slot_description(@game, i)
        @save_strings[i] = desc
        @save_slot_ok[i] = ok
        @menus['load'].items[i].status = ok ? 1 : 0
        @menus['save'].items[i].status = 1
      end
    end

    def open_load
      read_save_strings
      @save_string_enter = false
      @message = nil
      if @active
        goto('load')
      else
        @active = true
        @screen = 'load'
        @item_on = @menus['load'].last_on
      end
      @sound.play('swtchn')
    end

    def open_save
      read_save_strings
      @save_string_enter = false
      @message = nil
      if @active
        goto('save')
      else
        @active = true
        @screen = 'save'
        @item_on = @menus['save'].last_on
      end
      @sound.play('swtchn')
    end

    def begin_save_name(slot)
      @save_string_enter = true
      @save_slot = slot
      @save_old_string = @save_strings[slot]
      @save_strings[slot] = '' if @save_strings[slot] == Defs::LOADSAVEEMPTY
      @save_char_index = @save_strings[slot].length
    end

    def save_string_key(key, char)
      slot = @save_slot
      if key == KEY_BACKSPACE
        if @save_char_index.positive?
          @save_char_index -= 1
          @save_strings[slot] = @save_strings[slot].byteslice(0, @save_char_index)
        end
        return true
      end
      if key == KEY_ESCAPE
        @save_string_enter = false
        @save_strings[slot] = @save_old_string
        return true
      end
      if [KEY_RETURN, KEY_KP_ENTER].include?(key)
        @save_string_enter = false
        if @save_strings[slot].empty?
          @save_strings[slot] = @save_old_string
        elsif @game.save_game(slot, @save_strings[slot])
          clear
        else
          @sound.play('oof')
        end
        return true
      end
      ch = char.to_s.upcase
      return true if ch.length != 1

      code = ch.ord
      if ch != ' '
        idx = code - Defs::HU_FONTSTART
        return true if idx.negative? || idx >= Defs::HU_FONTSIZE
      end
      name = @save_strings[slot]
      if code.between?(32, 127) && @save_char_index < Defs::SAVESTRINGSIZE - 1 && string_width(name) < (Defs::SAVESTRINGSIZE - 2) * 8
        @save_strings[slot] = name + ch
        @save_char_index += 1
      end
      true
    end

    def string_width(text)
      text.upcase.each_char.sum do |ch|
        c = ch.ord - Defs::HU_FONTSTART
        next 4 if c.negative? || c >= Defs::HU_FONTSIZE

        patch = lump(format('STCFN%03d', ch.ord))
        next 8 unless patch

        [4, VVideo.patch_size(patch)[0]].max
      end
    end

    def write_text(fb, x, y, text)
      xx = x
      text.upcase.each_char do |ch|
        if ch == ' '
          xx += 4
          next
        end
        patch = lump(format('STCFN%03d', ch.ord))
        if patch
          VVideo.draw_patch(fb, xx, y, patch)
          xx += [4, VVideo.patch_size(patch)[0]].max
        else
          xx += 8
        end
      end
      xx
    end

    def draw_saveload_border(fb, x, y)
      left = lump('M_LSLEFT')
      mid = lump('M_LSCNTR')
      right = lump('M_LSRGHT')
      VVideo.draw_patch(fb, x - 8, y + 7, left) if left
      xx = x
      Defs::SAVESTRINGSIZE.times do
        VVideo.draw_patch(fb, xx, y + 7, mid) if mid
        xx += 8
      end
      VVideo.draw_patch(fb, xx, y + 7, right) if right
    end

    def draw_save_slots(fb, menu)
      6.times do |i|
        y = menu.y + (LINEHEIGHT * i)
        draw_saveload_border(fb, menu.x, y)
        xx = write_text(fb, menu.x, y, @save_strings[i])
        write_text(fb, xx, y, '_') if @save_string_enter && i == @save_slot
      end
    end

    def draw_routine(fb, menu)
      case menu.routine
      when 'main'
        patch = lump('M_DOOM')
        VVideo.draw_patch(fb, 94, 2, patch) if patch
      when 'skill'
        patch = lump('M_NEWG')
        VVideo.draw_patch(fb, 96, 14, patch) if patch
        patch = lump('M_SKILL')
        VVideo.draw_patch(fb, 54, 38, patch) if patch
      when 'episode'
        patch = lump('M_EPISOD')
        VVideo.draw_patch(fb, 54, 38, patch) if patch
      when 'options'
        patch = lump('M_OPTTTL')
        VVideo.draw_patch(fb, 108, 15, patch) if patch
        msg = lump(@game.show_messages ? 'M_MSGON' : 'M_MSGOFF')
        VVideo.draw_patch(fb, menu.x + 120, menu.y + LINEHEIGHT, msg) if msg
        det = lump(@game.detail_level.zero? ? 'M_GDHIGH' : 'M_GDLOW')
        VVideo.draw_patch(fb, menu.x + 175, menu.y + (LINEHEIGHT * 2), det) if det
      when 'sound'
        patch = lump('M_SVOL')
        VVideo.draw_patch(fb, 60, 38, patch) if patch
      when 'read1'
        name = if has?('HELP2')
                 'HELP2'
               elsif has?('HELP1')
                 'HELP1'
               elsif has?('HELP')
                 'HELP'
               else
                 'CREDIT'
               end
        patch = lump(name)
        VVideo.draw_patch(fb, 0, 0, patch) if patch
      when 'read2'
        patch = lump('HELP1') || lump('CREDIT')
        VVideo.draw_patch(fb, 0, 0, patch) if patch
      when 'load'
        patch = lump('M_LOADG')
        VVideo.draw_patch(fb, 72, 28, patch) if patch
        draw_save_slots(fb, menu)
      when 'save'
        patch = lump('M_SAVEG')
        VVideo.draw_patch(fb, 72, 28, patch) if patch
        draw_save_slots(fb, menu)
      end
    end

    def draw_thermo(fb, x, y, width, dot)
      left = lump('M_THERML')
      mid = lump('M_THERMM')
      right = lump('M_THERMR')
      knob = lump('M_THERMO')
      xx = x
      VVideo.draw_patch(fb, xx, y, left) if left
      xx += 8
      width.times do
        VVideo.draw_patch(fb, xx, y, mid) if mid
        xx += 8
      end
      VVideo.draw_patch(fb, xx, y, right) if right
      return unless knob

      VVideo.draw_patch(fb, x + 8 + (dot.clamp(0, width - 1) * 8), y, knob)
    end

    def draw_message(fb)
      text = @message.to_s
      text += '  (Y/N)' if @message_confirm
      x = 10
      y = 80
      text.each_char do |ch|
        if ch == ' '
          x += 8
          next
        end
        patch = lump(format('STCFN%03d', ch.ord))
        if patch
          VVideo.draw_patch(fb, x, y, patch)
          x += [4, VVideo.patch_size(patch)[0]].max
        else
          x += 8
        end
        next unless x > 300

        x = 10
        y += 10
      end
    end

    def has?(name)
      @wad.check_num_for_name(name) >= 0
    end
  end
end
