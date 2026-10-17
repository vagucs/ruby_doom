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
# Texto do episodio, o coelho e o elenco do Doom 2.

module Doom
  module FinaleText
    def self.unindent(text)
      text.gsub(/^ {6}/, '').chomp
    end

    TEXTSPEED = 3
    TEXTWAIT = 250
    STAGE_TEXT = 0
    STAGE_ART = 1
    STAGE_CAST = 2
    E1 = unindent(<<~TEXT)
      Once you beat the big badasses and
      clean out the moon base you're supposed
      to win, aren't you? Aren't you? Where's
      your fat reward and ticket home? What
      the hell is this? It's not supposed to
      end this way!

      It stinks like rotten meat, but looks
      like the lost Deimos base.  Looks like
      you're stuck on The Shores of Hell.
      The only way out is through.

      To continue the DOOM experience, play
      The Shores of Hell and its amazing
      sequel, Inferno!
    TEXT
    E2 = unindent(<<~TEXT)
      You've done it! The hideous cyber-
      demon lord that ruled the lost Deimos
      moon base has been slain and you
      are triumphant! But ... where are
      you? You clamber to the edge of the
      moon and look down to see the awful
      truth.

      Deimos floats above Hell itself!
      You've never heard of anyone escaping
      from Hell, but you'll make the bastards
      sorry they ever heard of you! Quickly,
      you rappel down to  the surface of
      Hell.

      Now, it's on to the final chapter of
      DOOM! -- Inferno.
    TEXT
    E3 = unindent(<<~TEXT)
      The loathsome spiderdemon that
      masterminded the invasion of the moon
      bases and caused so much death has had
      its ass kicked for all time.

      A hidden doorway opens and you enter.
      You've proven too tough for Hell to
      contain, and now Hell at last plays
      fair -- for you emerge from the door
      to see the green fields of Earth!
      Home at last.

      You wonder what's been happening on
      Earth while you were battling evil
      unleashed. It's good that no Hell-
      spawn could have come through that
      door with you ...
    TEXT
    E4 = unindent(<<~TEXT)
      the spider mastermind must have sent forth
      its legions of hellspawn before your
      final confrontation with that terrible
      beast from hell.  but you stepped forward
      and brought forth eternal damnation and
      suffering upon the horde as a true hero
      would in the face of something so evil.

      besides, someone was gonna pay for what
      happened to daisy, your pet rabbit.

      but now, you see spread before you more
      potential pain and gibbitude as a nation
      of demons run amok among our cities.

      next stop, hell on earth!
    TEXT
    C1 = unindent(<<~TEXT)
      YOU HAVE ENTERED DEEPLY INTO THE INFESTED
      STARPORT. BUT SOMETHING IS WRONG. THE
      MONSTERS HAVE BROUGHT THEIR OWN REALITY
      WITH THEM, AND THE STARPORT'S TECHNOLOGY
      IS BEING SUBVERTED BY THEIR PRESENCE.

      AHEAD, YOU SEE AN OUTPOST OF HELL, A
      FORTIFIED ZONE. IF YOU CAN GET PAST IT,
      YOU CAN PENETRATE INTO THE HAUNTED HEART
      OF THE STARBASE AND FIND THE CONTROLLING
      SWITCH WHICH HOLDS EARTH'S POPULATION
      HOSTAGE.
    TEXT
    C2 = unindent(<<~TEXT)
      YOU HAVE WON! YOUR VICTORY HAS ENABLED
      HUMANKIND TO EVACUATE EARTH AND ESCAPE
      THE NIGHTMARE.  NOW YOU ARE THE ONLY
      HUMAN LEFT ON THE FACE OF THE PLANET.
      CANNIBAL MUTATIONS, CARNIVOROUS ALIENS,
      AND EVIL SPIRITS ARE YOUR ONLY NEIGHBORS.
      YOU SIT BACK AND WAIT FOR DEATH, CONTENT
      THAT YOU HAVE SAVED YOUR SPECIES.

      BUT THEN, EARTH CONTROL BEAMS DOWN A
      MESSAGE FROM SPACE: "SENSORS HAVE LOCATED
      THE SOURCE OF THE ALIEN INVASION. IF YOU
      GO THERE, YOU MAY BE ABLE TO BLOCK THEIR
      ENTRY.  THE ALIEN BASE IS IN THE HEART OF
      YOUR OWN HOME CITY, NOT FAR FROM THE
      STARPORT." SLOWLY AND PAINFULLY YOU GET
      UP AND RETURN TO THE FRAY.
    TEXT
    C3 = unindent(<<~TEXT)
      YOU ARE AT THE CORRUPT HEART OF THE CITY,
      SURROUNDED BY THE CORPSES OF YOUR ENEMIES.
      YOU SEE NO WAY TO DESTROY THE CREATURES'
      ENTRYWAY ON THIS SIDE, SO YOU CLENCH YOUR
      TEETH AND PLUNGE THROUGH IT.

      THERE MUST BE A WAY TO CLOSE IT ON THE
      OTHER SIDE. WHAT DO YOU CARE IF YOU'VE
      GOT TO GO THROUGH HELL TO GET TO IT?
    TEXT
    C4 = unindent(<<~TEXT)
      THE HORRENDOUS VISAGE OF THE BIGGEST
      DEMON YOU'VE EVER SEEN CRUMBLES BEFORE
      YOU, AFTER YOU PUMP YOUR ROCKETS INTO
      HIS EXPOSED BRAIN. THE MONSTER SHRIVELS
      UP AND DIES, ITS THRASHING LIMBS
      DEVASTATING UNTOLD MILES OF HELL'S
      SURFACE.

      YOU'VE DONE IT. THE INVASION IS OVER.
      EARTH IS SAVED. HELL IS A WRECK. YOU
      WONDER WHERE BAD FOLKS WILL GO WHEN THEY
      DIE, NOW. WIPING THE SWEAT FROM YOUR
      FOREHEAD YOU BEGIN THE LONG TREK BACK
      HOME. REBUILDING EARTH OUGHT TO BE A
      LOT MORE FUN THAN RUINING IT WAS.
    TEXT
    C5 = unindent(<<~TEXT)
      CONGRATULATIONS, YOU'VE FOUND THE SECRET
      LEVEL! LOOKS LIKE IT'S BEEN BUILT BY
      HUMANS, RATHER THAN DEMONS. YOU WONDER
      WHO THE INMATES OF THIS CORNER OF HELL
      WILL BE.
    TEXT
    C6 = unindent(<<~TEXT)
      CONGRATULATIONS, YOU'VE FOUND THE
      SUPER SECRET LEVEL!  YOU'D BETTER
      BLAZE THROUGH THIS ONE!
    TEXT
    DOOM2 = { 6 => ['SLIME16', C1], 11 => ['RROCK14', C2], 20 => ['RROCK07', C3], 30 => ['RROCK17', C4], 15 => ['RROCK13', C5], 31 => ['RROCK19', C6] }.freeze
    CAST = [
      ['ZOMBIEMAN', Info::MT_POSSESSED],
      ['SHOTGUN GUY', Info::MT_SHOTGUY],
      ['HEAVY WEAPON DUDE', Info::MT_CHAINGUY],
      ['IMP', Info::MT_TROOP],
      ['DEMON', Info::MT_SERGEANT],
      ['LOST SOUL', Info::MT_SKULL],
      ['CACODEMON', Info::MT_HEAD],
      ['HELL KNIGHT', Info::MT_KNIGHT],
      ['BARON OF HELL', Info::MT_BRUISER],
      ['ARACHNOTRON', Info::MT_BABY],
      ['PAIN ELEMENTAL', Info::MT_PAIN],
      ['REVENANT', Info::MT_UNDEAD],
      ['MANCUBUS', Info::MT_FATSO],
      ['ARCH-VILE', Info::MT_VILE],
      ['THE SPIDER MASTERMIND', Info::MT_SPIDER],
      ['THE CYBERDEMON', Info::MT_CYBORG],
      ['OUR HERO', Info::MT_PLAYER]
    ].freeze
    CAST_SFX = {
      Info::S_PLAY_ATK1 => 'dshtgn',
      Info::S_POSS_ATK2 => 'pistol',
      Info::S_SPOS_ATK2 => 'shotgn',
      Info::S_VILE_ATK2 => 'vilatk',
      Info::S_SKEL_FIST2 => 'skeswg',
      Info::S_SKEL_FIST4 => 'skepch',
      Info::S_SKEL_MISS2 => 'skeatk',
      Info::S_FATT_ATK8 => 'firsht',
      Info::S_FATT_ATK5 => 'firsht',
      Info::S_FATT_ATK2 => 'firsht',
      Info::S_CPOS_ATK2 => 'shotgn',
      Info::S_CPOS_ATK3 => 'shotgn',
      Info::S_CPOS_ATK4 => 'shotgn',
      Info::S_TROO_ATK3 => 'claw',
      Info::S_SARG_ATK2 => 'sgtatk',
      Info::S_BOSS_ATK2 => 'firsht',
      Info::S_BOS2_ATK2 => 'firsht',
      Info::S_HEAD_ATK2 => 'firsht',
      Info::S_SKULL_ATK2 => 'sklatk',
      Info::S_SPID_ATK2 => 'shotgn',
      Info::S_SPID_ATK3 => 'shotgn',
      Info::S_BSPI_ATK2 => 'plasma',
      Info::S_CYBER_ATK2 => 'rlaunc',
      Info::S_CYBER_ATK4 => 'rlaunc',
      Info::S_CYBER_ATK6 => 'rlaunc',
      Info::S_PAIN_ATK3 => 'sklatk'
    }.freeze

    module_function

    def commercial_finale?(mapn, secret)
      [6, 11, 20, 30].include?(mapn) || (secret && [15, 31].include?(mapn))
    end
  end

  class Finale
    attr_reader :done, :action
    attr_accessor :force_wipe

    def initialize(wad, sound, res, episode, mapn, iwad_path)
      @wad = wad
      @sound = sound
      @res = res
      @episode = episode
      @mapn = mapn
      @stage = FinaleText::STAGE_TEXT
      @count = 0
      @done = false
      @action = ''
      @force_wipe = false
      @commercial = wad.check_num_for_name('MAP01') >= 0
      if @commercial
        @flat, @text = FinaleText::DOOM2.fetch(mapn, ['SLIME16', FinaleText::C1])
        sound.change_music('read_m', true)
      else
        @text = { 1 => FinaleText::E1, 2 => FinaleText::E2, 3 => FinaleText::E3, 4 => FinaleText::E4 }.fetch(episode, FinaleText::E1)
        @flat = { 1 => 'FLOOR4_8', 2 => 'SFLR6_1', 3 => 'MFLR8_4', 4 => 'MFLR8_3' }.fetch(episode, 'FLOOR4_8')
        sound.change_music('victor', true)
      end
      @flat_lump = load_lump(@flat)
      @art = load_art
      @pfub1 = episode == 3 && !@commercial ? load_lump('PFUB1') : nil
      @pfub2 = episode == 3 && !@commercial ? load_lump('PFUB2') : nil
      @bossback = load_lump('BOSSBACK')
      @last_bunny = -1
      @castnum = 0
      @caststate = Info::S_NULL
      @casttics = 0
      @castdeath = false
      @castframes = 0
      @castonmelee = 0
      @castattacking = false
    end

    def ticker(skip)
      if @commercial && @stage == FinaleText::STAGE_TEXT && @count > 50 && skip
        if @mapn == 30
          start_cast
        else
          @action = 'worlddone'
          @done = true
          return
        end
      end
      @count += 1
      if @stage == FinaleText::STAGE_CAST
        cast_ticker
        return
      end
      return if @commercial

      if @stage == FinaleText::STAGE_TEXT
        return unless @count > (@text.length * FinaleText::TEXTSPEED) + FinaleText::TEXTWAIT

        @stage = FinaleText::STAGE_ART
        @count = 0
        @force_wipe = true
        @sound.change_music('bunny', true) if @episode == 3
      elsif @stage == FinaleText::STAGE_ART
        wait = @pfub1 && @pfub2 ? 1130 : 10
        return unless skip && @count > wait

        @done = true
        @action = 'title'
      end
    end

    def cast_hit
      return false if @stage != FinaleText::STAGE_CAST || @castdeath

      info = Info::MOBJINFO[FinaleText::CAST[@castnum][1]]
      @castdeath = true
      @caststate = info[Info::MI_DEATHSTATE]
      @casttics = Info::STATES[@caststate][2]
      @casttics = 15 if @casttics == -1
      @castframes = 0
      @castattacking = false
      true
    end

    def draw(fb)
      if @stage == FinaleText::STAGE_CAST
        draw_cast(fb)
      elsif @stage == FinaleText::STAGE_ART
        if @episode == 3 && @pfub1 && @pfub2
          draw_bunny(fb)
        elsif @art
          VVideo.fill(fb, 0)
          VVideo.draw_patch(fb, 0, 0, @art)
        end
      else
        draw_text(fb)
      end
    end

    private

    def load_lump(name)
      number = @wad.check_num_for_name(name)
      return nil if number.negative?

      @wad.cache_lump_num(number)
    end

    def load_art
      art = if @commercial
              @wad.check_num_for_name('CREDIT') >= 0 ? 'CREDIT' : 'HELP2'
            elsif @episode == 2
              'VICTORY2'
            elsif @episode == 4
              'ENDPIC'
            else
              @wad.check_num_for_name('CREDIT') >= 0 ? 'CREDIT' : 'HELP2'
            end
      load_lump(art) || load_lump('HELP1')
    end

    def start_cast
      @force_wipe = true
      @castnum = 0
      @caststate = Info::MOBJINFO[FinaleText::CAST[0][1]][Info::MI_SEESTATE]
      @casttics = Info::STATES[@caststate][2]
      @castdeath = false
      @stage = FinaleText::STAGE_CAST
      @castframes = 0
      @castonmelee = 0
      @castattacking = false
      @sound.change_music('evil', true)
    end

    def cast_info
      Info::MOBJINFO[FinaleText::CAST[@castnum][1]]
    end

    def stop_attack
      @castattacking = false
      @castframes = 0
      @caststate = cast_info[Info::MI_SEESTATE]
    end

    def cast_ticker
      @casttics -= 1
      return if @casttics.positive?

      state = Info::STATES[@caststate]
      if state[2] == -1 || state[4] == Info::S_NULL
        @castnum += 1
        @castdeath = false
        @castnum = 0 if @castnum >= FinaleText::CAST.length
        @caststate = cast_info[Info::MI_SEESTATE]
        @castframes = 0
      else
        if @caststate == Info::S_PLAY_ATK1
          stop_attack
        else
          @caststate = state[4]
          @castframes += 1
          sfx = FinaleText::CAST_SFX[@caststate]
          @sound.play(sfx) if sfx
        end
      end
      if @castframes == 12
        @castattacking = true
        info = cast_info
        @caststate = @castonmelee.zero? ? info[Info::MI_MISSILESTATE] : info[Info::MI_MELEESTATE]
        @castonmelee ^= 1
        @caststate = @castonmelee.zero? ? info[Info::MI_MISSILESTATE] : info[Info::MI_MELEESTATE] if @caststate == Info::S_NULL
      end
      stop_attack if @castattacking && (@castframes == 24 || @caststate == cast_info[Info::MI_SEESTATE])
      @casttics = Info::STATES[@caststate][2]
      @casttics = 15 if @casttics == -1
    end

    def draw_cast(fb)
      VVideo.fill(fb, 0)
      VVideo.draw_patch(fb, 0, 0, @bossback) if @bossback
      print_text(fb, FinaleText::CAST[@castnum][0], 180)
      state = Info::STATES[@caststate]
      sprite = Info::SPRNAMES[state[0]]
      found = Sprites.lookup(@res, sprite, 0, 0, state[1] & Info::FF_FRAMEMASK)
      return unless found

      lump, flip = found
      VVideo.draw_patch(fb, 160, 170, @wad.cache_lump_num(lump), flipped: flip != 0)
    end

    def print_text(fb, text, y)
      width = text.each_char.sum { |ch| glyph_width(ch) }
      x = 160 - (width / 2)
      text.each_char do |ch|
        patch = font(ch)
        if patch
          VVideo.draw_patch(fb, x, y, patch)
          x += VVideo.patch_size(patch)[0]
        else
          x += 4
        end
      end
    end

    def draw_bunny(fb)
      VVideo.fill(fb, 0)
      scroll = (320 - ((@count - 230) / 2)).clamp(0, 320)
      Defs::SCREENWIDTH.times do |x|
        column = x + scroll
        patch = column < 320 ? @pfub2 : @pfub1
        draw_column(fb, x, patch, column < 320 ? column : column - 320)
      end
      return if @count < 1130

      stage = @count < 1180 ? 0 : [6, (@count - 1180) / 5].min
      if stage > @last_bunny
        @sound.play('pistol')
        @last_bunny = stage
      end
      patch = load_lump("END#{stage}")
      VVideo.draw_patch(fb, (320 - 104) / 2, (200 - 64) / 2, patch) if patch
    end

    def draw_column(fb, x, patch, column)
      return if column.negative?

      offset_pos = 8 + (column * 4)
      return if offset_pos + 4 > patch.bytesize

      offset = patch.byteslice(offset_pos, 4).unpack1('L<')
      while offset < patch.bytesize && patch.getbyte(offset) != 255
        top = patch.getbyte(offset)
        length = patch.getbyte(offset + 1)
        source = offset + 3
        length.times do |i|
          break if top + i >= Defs::SCREENHEIGHT

          fb.setbyte(((top + i) * Defs::SCREENWIDTH) + x, patch.getbyte(source + i))
        end
        offset += length + 4
      end
    end

    def fill_flat(fb)
      lump = @flat_lump
      if lump.nil? || lump.bytesize < 4096
        VVideo.fill(fb, 0)
        return
      end
      200.times do |y|
        row = (y & 63) << 6
        dest = y * Defs::SCREENWIDTH
        x = 0
        while x < Defs::SCREENWIDTH
          n = [64, Defs::SCREENWIDTH - x].min
          fb[dest + x, n] = lump.byteslice(row, n)
          x += 64
        end
      end
    end

    def draw_text(fb)
      fill_flat(fb)
      shown = @count / FinaleText::TEXTSPEED
      x = 10
      y = 10
      @text.each_char.with_index do |ch, i|
        break if i >= shown
        if ch == "\n"
          x = 10
          y += 11
          next
        end
        patch = font(ch)
        if patch
          width = VVideo.patch_size(patch)[0]
          break if x + width > Defs::SCREENWIDTH

          VVideo.draw_patch(fb, x, y, patch)
          x += width
        else
          x += 4
        end
      end
    end

    def glyph_width(ch)
      patch = font(ch)
      patch ? VVideo.patch_size(patch)[0] : 4
    end

    def font(ch)
      code = ch.upcase.ord
      return nil if ch == ' ' || code < Defs::HU_FONTSTART || code > Defs::HU_FONTEND

      load_lump(format('STCFN%03d', code))
    end
  end
end
