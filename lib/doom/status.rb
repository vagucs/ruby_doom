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
# Barra de status: vida, municao, armadura, rosto, chaves e mensagem.

module Doom
  class StatusBar
    ST_AMMOX = 44
    ST_AMMOY = 171
    ST_HEALTHX = 90
    ST_HEALTHY = 171
    ST_ARMORX = 221
    ST_ARMORY = 171
    ST_FACESX = 143
    ST_FACESY = 168
    ST_ARMSBGX = 104
    ST_ARMSBGY = 168
    ST_ARMSX = 111
    ST_ARMSY = 172
    ST_ARMSXSPACE = 12
    ST_ARMSYSPACE = 10
    ST_KEY0X = 239
    ST_KEY0Y = 171
    ST_AMMO_POS = [[288, 173], [288, 179], [288, 191], [288, 185]].freeze
    ST_MAX_POS = [[314, 173], [314, 179], [314, 191], [314, 185]].freeze
    ST_NUMPAINFACES = 5
    ST_NUMSTRAIGHTFACES = 3
    ST_NUMTURNFACES = 2
    ST_NUMSPECIALFACES = 3
    ST_FACESTRIDE = ST_NUMSTRAIGHTFACES + ST_NUMTURNFACES + ST_NUMSPECIALFACES
    ST_TURNOFFSET = ST_NUMSTRAIGHTFACES
    ST_OUCHOFFSET = ST_TURNOFFSET + ST_NUMTURNFACES
    ST_EVILGRINOFFSET = ST_OUCHOFFSET + 1
    ST_RAMPAGEOFFSET = ST_EVILGRINOFFSET + 1
    ST_GODFACE = ST_NUMPAINFACES * ST_FACESTRIDE
    ST_DEADFACE = ST_GODFACE + 1
    ST_EVILGRINCOUNT = 2 * Defs::TICRATE
    ST_STRAIGHTFACECOUNT = Defs::TICRATE / 2
    ST_TURNCOUNT = Defs::TICRATE
    ST_RAMPAGEDELAY = 2 * Defs::TICRATE
    ST_MUCHPAIN = 20

    def initialize(wad)
      @wad = wad
      @sbar = wad.cache_lump_name('STBAR')
      @tallnum = (0..9).map { |i| wad.cache_lump_name("STTNUM#{i}") }
      @shortnum = (0..9).map { |i| wad.cache_lump_name("STYSNUM#{i}") }
      @tallpercent = wad.cache_lump_name('STTPRCNT')
      @keys = (0..5).map { |i| optional("STKEYS#{i}") }
      @armsbg = wad.check_num_for_name('STARMS') >= 0 ? wad.cache_lump_name('STARMS') : nil
      @arms_off = (2..7).map { |i| wad.cache_lump_name("STGNUM#{i}") }
      @fallback_face = wad.cache_lump_name('STFST00')
      @faces = []
      ST_NUMPAINFACES.times do |pain|
        ST_NUMSTRAIGHTFACES.times { |look| @faces << optional("STFST#{pain}#{look}") }
        @faces << optional("STFTR#{pain}0")
        @faces << optional("STFTL#{pain}0")
        @faces << optional("STFOUCH#{pain}")
        @faces << optional("STFEVL#{pain}")
        @faces << optional("STFKILL#{pain}")
      end
      @faces << optional('STFGOD0')
      @faces << optional('STFDEAD0')
      @font = (Defs::HU_FONTSTART..Defs::HU_FONTEND).map { |ch| optional(format('STCFN%03d', ch)) }
      reset(nil)
    end

    def reset(player)
      @face_index = 0
      @face_count = 0
      @face_priority = 0
      @old_health = -1
      @pain_old_health = -1
      @last_calc = 0
      @last_attackdown = -1
      @old_weapons_owned = player ? player.weaponowned.dup : [false] * 9
      @rnd = 1
    end

    def ticker(player)
      return if player.nil?

      @rnd = (@rnd * 1_103_515_245 + 12_345) & 0xFFFFFFFF
      update_face(player, (@rnd >> 16) & 255)
      @old_health = player.health
    end

    def palette_index(player)
      return 0 if player.nil?

      cnt = player.damagecount
      if player.powers[Defs::PW_STRENGTH] != 0
        bzc = 12 - player.powers[Defs::PW_STRENGTH] / 64
        cnt = bzc if bzc > cnt
      end
      if cnt != 0
        pal = (cnt + 7) >> 3
        pal = 7 if pal >= 8
        pal + 1
      elsif player.bonuscount != 0
        pal = (player.bonuscount + 7) >> 3
        pal = 3 if pal >= 4
        pal + 9
      elsif player.powers[Defs::PW_IRONFEET] > 4 * 32 || (player.powers[Defs::PW_IRONFEET] & 8) != 0
        13
      else
        0
      end
    end

    def draw(fb, player, show_messages: true)
      VVideo.draw_patch(fb, 0, 168, @sbar)
      VVideo.draw_patch(fb, ST_ARMSBGX, ST_ARMSBGY, @armsbg) if @armsbg
      ammo_type = Actors::WEAPON_AMMO[player.readyweapon]
      ammo = ammo_type.nil? ? 0 : player.ammo[ammo_type]
      num(fb, ST_AMMOX, ST_AMMOY, ammo, 3, @tallnum)
      num(fb, ST_HEALTHX, ST_HEALTHY, player.health, 3, @tallnum)
      VVideo.draw_patch(fb, ST_HEALTHX, ST_HEALTHY, @tallpercent)
      num(fb, ST_ARMORX, ST_ARMORY, player.armorpoints, 3, @tallnum)
      VVideo.draw_patch(fb, ST_ARMORX, ST_ARMORY, @tallpercent)
      owned = [
        player.weaponowned[Defs::WP_SHOTGUN] || player.weaponowned[Defs::WP_SUPERSHOTGUN],
        player.weaponowned[Defs::WP_CHAINGUN],
        player.weaponowned[Defs::WP_MISSILE],
        player.weaponowned[Defs::WP_PLASMA],
        player.weaponowned[Defs::WP_BFG],
        false
      ]
      6.times do |i|
        x = ST_ARMSX + (i % 3) * ST_ARMSXSPACE
        y = ST_ARMSY + (i / 3) * ST_ARMSYSPACE
        if owned[i]
          digit(fb, x, y, i + 2, @shortnum)
        elsif i < @arms_off.length
          VVideo.draw_patch(fb, x, y, @arms_off[i])
        end
      end
      VVideo.draw_patch(fb, ST_FACESX, ST_FACESY, face_patch(@face_index))
      [[Defs::IT_BLUECARD, Defs::IT_BLUESKULL, 0],
       [Defs::IT_YELLOWCARD, Defs::IT_YELLOWSKULL, 1],
       [Defs::IT_REDCARD, Defs::IT_REDSKULL, 2]].each do |card, skull, slot|
        next unless player.cards[card] || player.cards[skull]

        idx = player.cards[skull] ? skull : card
        patch = @keys[idx]
        VVideo.draw_patch(fb, ST_KEY0X, ST_KEY0Y + slot * 10, patch) if patch
      end
      [Defs::AM_CLIP, Defs::AM_SHELL, Defs::AM_CELL, Defs::AM_MISL].each_with_index do |am, i|
        ax, ay = ST_AMMO_POS[i]
        mx, my = ST_MAX_POS[i]
        num(fb, ax, ay, player.ammo[am], 3, @shortnum)
        num(fb, mx, my, player.maxammo[am], 3, @shortnum)
      end
      draw_text(fb, 0, 0, player.message) if show_messages && !player.message.empty?
    end

    private

    def optional(name)
      n = @wad.check_num_for_name(name)
      n >= 0 ? @wad.cache_lump_num(n) : nil
    end

    def face_patch(index)
      return @faces[index] if index >= 0 && index < @faces.length && @faces[index]

      @fallback_face
    end

    def pain_offset(player)
      health = player.health.to_i.clamp(0, 100)
      if health != @pain_old_health
        @last_calc = ST_FACESTRIDE * ((100 - health) * ST_NUMPAINFACES) / 101
        @pain_old_health = health
      end
      @last_calc
    end

    def update_face(player, st_random)
      if @face_priority < 10 && player.health <= 0
        @face_priority = 9
        @face_index = ST_DEADFACE
        @face_count = 1
      end
      if @face_priority < 9 && player.bonuscount != 0
        grin = false
        n = [@old_weapons_owned.length, player.weaponowned.length].min
        n.times do |i|
          next if @old_weapons_owned[i] == player.weaponowned[i]

          grin = true
          @old_weapons_owned[i] = player.weaponowned[i]
        end
        if grin
          @face_priority = 8
          @face_count = ST_EVILGRINCOUNT
          @face_index = pain_offset(player) + ST_EVILGRINOFFSET
        end
      end
      if @face_priority < 8 && player.damagecount != 0 && player.attacker && player.mo && !player.attacker.equal?(player.mo)
        @face_priority = 7
        if player.health - @old_health > ST_MUCHPAIN
          @face_count = ST_TURNCOUNT
          @face_index = pain_offset(player) + ST_OUCHOFFSET
        else
          bad = Collision.angle_to(player.mo.x, player.mo.y, player.attacker.x, player.attacker.y)
          if Compat.as_u32(bad) > Compat.as_u32(player.mo.angle)
            diff = Compat.as_u32(bad - player.mo.angle)
            turn_right = diff > Compat.as_u32(Defs::ANG180)
          else
            diff = Compat.as_u32(player.mo.angle - bad)
            turn_right = diff <= Compat.as_u32(Defs::ANG180)
          end
          @face_count = ST_TURNCOUNT
          @face_index = pain_offset(player)
          if diff < Compat.as_u32(Defs::ANG45)
            @face_index += ST_RAMPAGEOFFSET
          elsif turn_right
            @face_index += ST_TURNOFFSET
          else
            @face_index += ST_TURNOFFSET + 1
          end
        end
      end
      if @face_priority < 7 && player.damagecount != 0
        if player.health - @old_health > ST_MUCHPAIN
          @face_priority = 7
          @face_count = ST_TURNCOUNT
          @face_index = pain_offset(player) + ST_OUCHOFFSET
        else
          @face_priority = 6
          @face_count = ST_TURNCOUNT
          @face_index = pain_offset(player) + ST_RAMPAGEOFFSET
        end
      end
      if @face_priority < 6
        if player.attackdown
          if @last_attackdown == -1
            @last_attackdown = ST_RAMPAGEDELAY
          else
            @last_attackdown -= 1
            if @last_attackdown.zero?
              @face_priority = 5
              @face_index = pain_offset(player) + ST_RAMPAGEOFFSET
              @face_count = 1
              @last_attackdown = 1
            end
          end
        else
          @last_attackdown = -1
        end
      end
      if @face_priority < 5 && ((player.cheats & Defs::CF_GODMODE) != 0 || player.powers[Defs::PW_INVULNERABILITY] != 0)
        @face_priority = 4
        @face_index = ST_GODFACE
        @face_count = 1
      end
      if @face_count.zero?
        @face_index = pain_offset(player) + (st_random % 3)
        @face_count = ST_STRAIGHTFACECOUNT
        @face_priority = 0
      end
      @face_count -= 1
    end

    def digit(fb, x, y, n, font)
      VVideo.draw_patch(fb, x, y, font[n.clamp(0, 9)])
    end

    def num(fb, x, y, value, digits, font)
      w, = VVideo.patch_size(font[0])
      x -= w
      value = value.to_i.abs
      digits.times do
        VVideo.draw_patch(fb, x, y, font[value % 10])
        x -= w
        value /= 10
        break if value.zero?
      end
    end

    def draw_text(fb, x, y, text)
      text.to_s.upcase.each_char do |ch|
        idx = ch.ord - Defs::HU_FONTSTART
        patch = idx >= 0 && idx < @font.length ? @font[idx] : nil
        if patch
          VVideo.draw_patch(fb, x, y, patch)
          w, = VVideo.patch_size(patch)
          x += w
        else
          x += 4
        end
      end
    end
  end
end
