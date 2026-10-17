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
# Portas, pisos, elevadores, escadas, esmagadores, luzes e teletransporte.

module Doom
  module Rng
    RNDTABLE = [
      0, 8, 109, 220, 222, 241, 149, 107, 75, 248, 254, 140, 16, 66,
      74, 21, 211, 47, 80, 242, 154, 27, 205, 128, 161, 89, 77, 36,
      95, 110, 85, 48, 212, 140, 211, 249, 22, 79, 200, 50, 28, 188,
      52, 140, 202, 120, 68, 145, 62, 70, 184, 190, 91, 197, 152, 224,
      149, 104, 25, 178, 252, 182, 202, 182, 141, 197, 4, 81, 181, 242,
      145, 42, 39, 227, 156, 198, 225, 193, 219, 93, 122, 175, 249, 0,
      175, 143, 70, 239, 46, 246, 163, 53, 163, 109, 168, 135, 2, 235,
      25, 92, 20, 145, 138, 77, 69, 166, 78, 176, 173, 212, 166, 113,
      94, 161, 41, 50, 239, 49, 111, 164, 70, 60, 2, 37, 171, 75,
      136, 156, 11, 56, 42, 146, 138, 229, 73, 146, 77, 61, 98, 196,
      135, 106, 63, 197, 195, 86, 96, 203, 113, 101, 170, 247, 181, 113,
      80, 250, 108, 7, 255, 237, 129, 226, 79, 107, 112, 166, 103, 241,
      24, 223, 239, 120, 198, 58, 60, 82, 128, 3, 184, 66, 143, 224,
      145, 224, 81, 206, 163, 45, 63, 90, 168, 114, 59, 33, 159, 95,
      28, 139, 123, 98, 125, 196, 15, 70, 194, 253, 54, 14, 109, 226,
      71, 17, 161, 93, 186, 87, 244, 138, 20, 52, 123, 251, 26, 36,
      17, 46, 52, 231, 232, 76, 31, 221, 84, 37, 216, 165, 212, 106,
      197, 242, 98, 43, 39, 175, 254, 145, 190, 84, 118, 222, 187, 136,
      120, 163, 236, 249
    ].freeze

    module_function

    def reset
      @index = 0
    end

    def p_random
      @index = ((@index || 0) + 1) & 255
      RNDTABLE[@index]
    end
  end

  class Quiet
    def play(_name); end
  end

  class VerticalDoor
    attr_accessor :sector, :type, :direction, :topheight, :speed, :topwait,
                  :topcountdown, :dead

    def initialize(sector:, type:, direction:, topheight:, speed:, topwait:, topcountdown: 0)
      @sector = sector
      @type = type
      @direction = direction
      @topheight = topheight
      @speed = speed
      @topwait = topwait
      @topcountdown = topcountdown
      @dead = false
    end
  end

  class Plat
    attr_accessor :sector, :type, :status, :speed, :low, :high, :wait, :count, :dead

    def initialize(sector:, type:, status:, speed:, low:, high:, wait:, count: 0)
      @sector = sector
      @type = type
      @status = status
      @speed = speed
      @low = low
      @high = high
      @wait = wait
      @count = count
      @dead = false
    end
  end

  class FloorMove
    attr_accessor :sector, :direction, :dest, :speed, :crush, :floorpic, :dead

    def initialize(sector:, direction:, dest:, speed:, crush: false, floorpic: nil)
      @sector = sector
      @direction = direction
      @dest = dest
      @speed = speed
      @crush = crush
      @floorpic = floorpic
      @dead = false
    end
  end

  class CeilingMove
    attr_accessor :sector, :direction, :dest, :speed, :crush, :ctype, :topheight, :bottomheight, :dead

    def initialize(sector:, direction:, dest:, speed:, crush: false, ctype: 0, topheight: 0, bottomheight: 0)
      @sector = sector
      @direction = direction
      @dest = dest
      @speed = speed
      @crush = crush
      @ctype = ctype
      @topheight = topheight
      @bottomheight = bottomheight
      @dead = false
    end
  end

  class LightThinker
    attr_accessor :sector, :kind, :count, :minlight, :maxlight, :darktime, :brighttime,
                  :maxtime, :mintime, :direction, :dead

    def initialize(sector:, kind:, count: 0, minlight: 0, maxlight: 0, darktime: 0, brighttime: 0,
                   maxtime: 64, mintime: 7, direction: -1)
      @sector = sector
      @kind = kind
      @count = count
      @minlight = minlight
      @maxlight = maxlight
      @darktime = darktime
      @brighttime = brighttime
      @maxtime = maxtime
      @mintime = mintime
      @direction = direction
      @dead = false
    end
  end

  class Button
    attr_accessor :line, :where, :texture, :timer

    def initialize(line, where, texture, timer)
      @line = line
      @where = where
      @texture = texture
      @timer = timer
    end
  end

  class Specials
    SWITCH_PAIRS = [
      %w[SW1BRCOM SW2BRCOM], %w[SW1BRN1 SW2BRN1], %w[SW1BRN2 SW2BRN2], %w[SW1BRNGN SW2BRNGN],
      %w[SW1BROWN SW2BROWN], %w[SW1COMM SW2COMM], %w[SW1COMP SW2COMP], %w[SW1DIRT SW2DIRT],
      %w[SW1EXIT SW2EXIT], %w[SW1GRAY SW2GRAY], %w[SW1GRAY1 SW2GRAY1], %w[SW1METAL SW2METAL],
      %w[SW1PIPE SW2PIPE], %w[SW1SLAD SW2SLAD], %w[SW1STARG SW2STARG], %w[SW1STON1 SW2STON1],
      %w[SW1STON2 SW2STON2], %w[SW1STONE SW2STONE], %w[SW1STRTN SW2STRTN], %w[SW1BLUE SW2BLUE],
      %w[SW1CMT SW2CMT], %w[SW1GARG SW2GARG], %w[SW1GSTON SW2GSTON], %w[SW1HOT SW2HOT],
      %w[SW1LION SW2LION], %w[SW1SATYR SW2SATYR], %w[SW1SKIN SW2SKIN], %w[SW1VINE SW2VINE],
      %w[SW1WOOD SW2WOOD], %w[SW1PANEL SW2PANEL], %w[SW1ROCK SW2ROCK], %w[SW1MET2 SW2MET2],
      %w[SW1WDMET SW2WDMET], %w[SW1BRIK SW2BRIK], %w[SW1MOD1 SW2MOD1], %w[SW1ZIM SW2ZIM],
      %w[SW1STON6 SW2STON6], %w[SW1TEK SW2TEK], %w[SW1MARB SW2MARB], %w[SW1SKULL SW2SKULL]
    ].freeze

    attr_accessor :exit_requested, :secret_exit, :thinkers, :buttons, :lights

    def initialize(world, res, sound = Quiet.new)
      @world = world
      @res = res
      @sound = sound
      @thinkers = []
      @lights = []
      @scroll_lines = []
      @buttons = []
      @exit_requested = false
      @secret_exit = false
      @switch_map = {}
      SWITCH_PAIRS.each do |a, b|
        ia = res.texture_num_for_name(a)
        ib = res.texture_num_for_name(b)
        next if ia.zero? && ib.zero?

        @switch_map[ia] = ib
        @switch_map[ib] = ia
      end
      spawn_specials
    end

    def spawn_specials
      @world.sectors.each do |sector|
        spec = sector.special
        case spec
        when 1 then spawn_light_flash(sector)
        when 2 then spawn_strobe(sector, Defs::FASTDARK, false)
        when 3 then spawn_strobe(sector, Defs::SLOWDARK, false)
        when 4
          spawn_strobe(sector, Defs::FASTDARK, false)
          sector.special = 4
        when 8 then spawn_glow(sector)
        when 10 then spawn_door_close_in_30(sector)
        when 12 then spawn_strobe(sector, Defs::SLOWDARK, true)
        when 13 then spawn_strobe(sector, Defs::FASTDARK, true)
        when 14 then spawn_door_raise_in_5(sector)
        when 17 then spawn_fire_flicker(sector)
        end
      end
      @world.lines.each { |ln| @scroll_lines << ln if ln.special == 48 }
    end

    def tick
      tick_lights
      @scroll_lines.each do |ln|
        side = ln.sides[0]
        side.textureoffset += Defs::FRACUNIT if side
      end
      alive = []
      @thinkers.each do |th|
        next if th.dead

        case th
        when VerticalDoor then tick_door(th)
        when Plat then tick_plat(th)
        when FloorMove then tick_floor(th)
        when CeilingMove then tick_ceiling(th)
        end
        alive << th unless th.dead
      end
      @thinkers = alive
      @buttons.dup.each do |btn|
        btn.timer -= 1
        next if btn.timer.positive?

        side = btn.line.sides[0]
        if side
          case btn.where
          when 'top' then side.toptexture = btn.texture
          when 'mid' then side.midtexture = btn.texture
          else side.bottomtexture = btn.texture
          end
        end
        @buttons.delete(btn)
      end
    end

    def move_plane(sector, speed, dest, floor_or_ceiling, direction, crush = false)
      last = floor_or_ceiling.zero? ? sector.floorheight : sector.ceilingheight
      past = false
      if direction == -1
        if last - speed < dest
          next_h = dest
          past = true
        else
          next_h = last - speed
        end
      elsif last + speed > dest
        next_h = dest
        past = true
      else
        next_h = last + speed
      end
      if floor_or_ceiling.zero?
        sector.floorheight = next_h
      else
        sector.ceilingheight = next_h
      end
      nofit = Collision.change_sector(@world, sector, crush)
      if nofit
        unless crush && !past
          if floor_or_ceiling.zero?
            sector.floorheight = last
          else
            sector.ceilingheight = last
          end
          Collision.change_sector(@world, sector, crush)
        end
        return past ? Defs::RESULT_PASTDEST : Defs::RESULT_CRUSHED
      end
      past ? Defs::RESULT_PASTDEST : 0
    end

    def surrounding(sector)
      seen = []
      sector.lines.each do |ln|
        other = ln.frontsector.equal?(sector) ? ln.backsector : ln.frontsector
        seen << other if other && !other.equal?(sector) && !seen.include?(other)
      end
      seen
    end

    def lowest_ceiling(sector)
      h = 0x7FFFFFFF
      surrounding(sector).each { |other| h = other.ceilingheight if other.ceilingheight < h }
      h == 0x7FFFFFFF ? sector.ceilingheight : h
    end

    def lowest_floor(sector)
      h = sector.floorheight
      surrounding(sector).each { |other| h = other.floorheight if other.floorheight < h }
      h
    end

    def highest_floor(sector)
      h = -500 * Defs::FRACUNIT
      surrounding(sector).each { |other| h = other.floorheight if other.floorheight > h }
      h
    end

    def next_highest_floor(sector, current)
      min_h = 0x7FFFFFFF
      found = false
      surrounding(sector).each do |other|
        next unless other.floorheight > current && other.floorheight < min_h

        min_h = other.floorheight
        found = true
      end
      found ? min_h : current
    end

    def highest_ceiling(sector)
      h = sector.ceilingheight
      surrounding(sector).each { |other| h = other.ceilingheight if other.ceilingheight > h }
      h
    end

    def raise_floor_dest(sector)
      dest = lowest_ceiling(sector)
      dest <= sector.ceilingheight ? dest : sector.ceilingheight
    end

    def raise_floor_crush_dest(sector)
      raise_floor_dest(sector) - 8 * Defs::FRACUNIT
    end

    def min_light(sector, maxlight)
      low = maxlight
      surrounding(sector).each { |other| low = other.lightlevel if other.lightlevel < low }
      low
    end

    def max_light(sector)
      high = sector.lightlevel
      surrounding(sector).each { |other| high = other.lightlevel if other.lightlevel > high }
      high
    end

    def sectors_from_tag(tag)
      return [] if tag.zero?

      @world.sectors.select { |s| s.tag == tag }
    end

    def tick_door(door)
      if door.direction.zero?
        door.topcountdown -= 1
        return if door.topcountdown.positive?

        if [Defs::VLD_NORMAL, Defs::VLD_BLAZERAISE, Defs::VLD_CLOSE].include?(door.type)
          door.direction = -1
          @sound.play(door.type == Defs::VLD_BLAZERAISE ? 'bdcls' : 'dorcls')
        elsif [Defs::VLD_CLOSE30, Defs::VLD_RAISEIN5].include?(door.type)
          door.direction = 1
          @sound.play('doropn')
        end
        return
      end
      dest = door.direction == 1 ? door.topheight : door.sector.floorheight
      return unless move_plane(door.sector, door.speed, dest, 1, door.direction) == Defs::RESULT_PASTDEST

      if door.direction == 1
        if [Defs::VLD_NORMAL, Defs::VLD_BLAZERAISE].include?(door.type)
          door.direction = 0
          door.topcountdown = door.topwait
        else
          door.sector.specialdata = nil
          door.dead = true
        end
      elsif door.type == Defs::VLD_CLOSE30
        door.direction = 0
        door.topcountdown = Defs::TICRATE * 30
      else
        door.sector.specialdata = nil
        door.dead = true
      end
    end

    def tick_plat(plat)
      if plat.status == Defs::PLAT_WAITING
        plat.count -= 1
        return if plat.count.positive?

        plat.status = plat.sector.floorheight <= plat.low ? Defs::PLAT_UP : Defs::PLAT_DOWN
        @sound.play('pstart')
        return
      end
      dest = plat.status == Defs::PLAT_UP ? plat.high : plat.low
      direction = plat.status == Defs::PLAT_UP ? 1 : -1
      return unless move_plane(plat.sector, plat.speed, dest, 0, direction) == Defs::RESULT_PASTDEST

      if plat.status == Defs::PLAT_DOWN || plat.type == Defs::PLAT_PERPETUAL
        plat.status = Defs::PLAT_WAITING
        plat.count = plat.wait
      else
        plat.sector.specialdata = nil
        plat.dead = true
      end
      @sound.play('pstop')
    end

    def tick_floor(floor)
      return unless move_plane(floor.sector, floor.speed, floor.dest, 0, floor.direction, floor.crush) == Defs::RESULT_PASTDEST

      floor.sector.floorpic = floor.floorpic unless floor.floorpic.nil?
      floor.sector.specialdata = nil
      floor.dead = true
    end

    def tick_ceiling(ceil)
      dest = ceil.ctype.zero? ? ceil.dest : (ceil.direction == 1 ? ceil.topheight : ceil.bottomheight)
      res = move_plane(ceil.sector, ceil.speed, dest, 1, ceil.direction, ceil.crush)
      bounce = [Defs::CEIL_CRUSHANDRAISE, Defs::CEIL_FASTCRUSH, Defs::CEIL_SILENTCRUSH].include?(ceil.ctype)
      if res == Defs::RESULT_PASTDEST
        if bounce
          if ceil.direction == -1
            ceil.direction = 1
            ceil.speed = Defs::CEILSPEED * (ceil.ctype == Defs::CEIL_FASTCRUSH ? 2 : 1)
            @sound.play('pstop') if ceil.ctype == Defs::CEIL_SILENTCRUSH
          else
            ceil.direction = -1
            @sound.play('pstop') if ceil.ctype == Defs::CEIL_SILENTCRUSH
          end
        else
          ceil.sector.specialdata = nil
          ceil.dead = true
        end
      elsif res == Defs::RESULT_CRUSHED && bounce
        slow = Defs::CEILSPEED / 8
        ceil.speed = slow < 1 ? 1 : slow
      end
    end

    def spawn_door(sector, dtype, reverse = false)
      if sector.specialdata
        door = sector.specialdata
        if door.is_a?(VerticalDoor) && [Defs::VLD_NORMAL, Defs::VLD_BLAZERAISE].include?(dtype)
          door.direction = door.direction == -1 ? 1 : -1
          return true
        end
        return false
      end
      closing = reverse || [Defs::VLD_CLOSE, Defs::VLD_BLAZECLOSE, Defs::VLD_CLOSE30].include?(dtype)
      door = VerticalDoor.new(
        sector: sector, type: dtype, direction: closing ? -1 : 1,
        topheight: lowest_ceiling(sector) - 4 * Defs::FRACUNIT,
        speed: Defs::VDOORSPEED * (dtype >= Defs::VLD_BLAZERAISE ? 4 : 1),
        topwait: Defs::VDOORWAIT
      )
      door.topheight = sector.ceilingheight if dtype == Defs::VLD_CLOSE30
      sector.specialdata = door
      @thinkers << door
      if door.direction == 1
        @sound.play(dtype < Defs::VLD_BLAZERAISE ? 'doropn' : 'bdopn')
      else
        @sound.play(dtype < Defs::VLD_BLAZERAISE ? 'dorcls' : 'bdcls')
      end
      true
    end

    def do_door(line, dtype, reverse = false)
      ok = false
      sectors_from_tag(line.tag).each { |sec| ok = true if spawn_door(sec, dtype, reverse) }
      ok
    end

    def locked_blaze_door(line, thing, spec)
      player = thing.player
      return unless player

      card, skull, name = if [99, 133].include?(spec)
                            [Defs::IT_BLUECARD, Defs::IT_BLUESKULL, 'azul']
                          elsif [134, 135].include?(spec)
                            [Defs::IT_REDCARD, Defs::IT_REDSKULL, 'vermelha']
                          else
                            [Defs::IT_YELLOWCARD, Defs::IT_YELLOWSKULL, 'amarela']
                          end
      unless player.cards[card] || player.cards[skull]
        player.set_message("Voce precisa da chave #{name}.")
        @sound.play('oof')
        return
      end
      change_switch(line, [99, 134, 136].include?(spec) ? 1 : 0) if do_door(line, Defs::VLD_BLAZEOPEN)
    end

    def vertical_door(line, thing)
      player = thing.player
      spec = line.special
      if [26, 32].include?(spec) && player && !(player.cards[Defs::IT_BLUECARD] || player.cards[Defs::IT_BLUESKULL])
        player.set_message('Voce precisa da chave azul.')
        @sound.play('oof')
        return
      end
      if [27, 34].include?(spec) && player && !(player.cards[Defs::IT_YELLOWCARD] || player.cards[Defs::IT_YELLOWSKULL])
        player.set_message('Voce precisa da chave amarela.')
        @sound.play('oof')
        return
      end
      if [28, 33].include?(spec) && player && !(player.cards[Defs::IT_REDCARD] || player.cards[Defs::IT_REDSKULL])
        player.set_message('Voce precisa da chave vermelha.')
        @sound.play('oof')
        return
      end
      side = line.sides[1]
      return if side.nil? || side.sector.nil?

      dtype = if [1, 26, 27, 28].include?(spec)
                Defs::VLD_NORMAL
              elsif [31, 32, 33, 34].include?(spec)
                line.special = 0
                Defs::VLD_OPEN
              elsif spec == 117
                Defs::VLD_BLAZERAISE
              elsif spec == 118
                line.special = 0
                Defs::VLD_BLAZEOPEN
              else
                Defs::VLD_NORMAL
              end
      spawn_door(side.sector, dtype)
    end

    def do_plat_dwus(line, blaze = false)
      ok = false
      speed = Defs::PLATSPEED * (blaze ? 8 : 1)
      sectors_from_tag(line.tag).each do |sec|
        next if sec.specialdata

        plat = Plat.new(
          sector: sec, type: blaze ? Defs::PLAT_BLAZEDWUS : Defs::PLAT_DWUS, status: Defs::PLAT_DOWN,
          speed: speed, low: lowest_floor(sec), high: sec.floorheight, wait: Defs::PLATWAIT * Defs::TICRATE
        )
        plat.low = plat.high - 8 * Defs::FRACUNIT if plat.low == plat.high
        sec.specialdata = plat
        @thinkers << plat
        @sound.play('pstart')
        ok = true
      end
      ok
    end

    def tag_line(tag)
      line = Line.new
      line.tag = tag
      line
    end

    def do_floor_tag(tag, dest_fn, direction, speed = nil, crush = false)
      do_floor(tag_line(tag), dest_fn, direction, speed, crush)
    end

    def do_door_tag(tag, dtype)
      do_door(tag_line(tag), dtype)
    end

    def raise_to_texture_tag(tag)
      raise_to_texture(tag_line(tag))
    end

    def shoot_special(line, thing)
      spec = line.special
      if spec == 24
        change_switch(line, 0) if do_floor(line, method(:raise_floor_dest), 1)
      elsif spec == 46
        do_door(line, Defs::VLD_OPEN)
        change_switch(line, 1)
      elsif spec == 47
        change_switch(line, 0) if do_plat_raise(line, 0)
      end
    end

    def do_floor(line, dest_fn, direction, speed = nil, crush = false)
      ok = false
      spd = speed || Defs::FLOORSPEED
      sectors_from_tag(line.tag).each do |sec|
        next if sec.specialdata

        floor = FloorMove.new(sector: sec, direction: direction, dest: dest_fn.call(sec), speed: spd, crush: crush)
        sec.specialdata = floor
        @thinkers << floor
        ok = true
      end
      ok
    end

    def do_stairs(line, step, speed)
      ok = false
      sectors_from_tag(line.tag).each do |sec|
        next if sec.specialdata

        height = sec.floorheight + step
        floor = FloorMove.new(sector: sec, direction: 1, dest: height, speed: speed)
        sec.specialdata = floor
        @thinkers << floor
        ok = true
        texture = sec.floorpic
        cur = sec
        loop do
          nxt = nil
          cur.lines.each do |ln|
            next if (ln.flags & Defs::ML_TWOSIDED).zero?

            other = ln.frontsector.equal?(cur) ? ln.backsector : ln.frontsector
            next if other.nil? || other.equal?(cur) || other.floorpic != texture || other.specialdata

            nxt = other
            break
          end
          break unless nxt

          height += step
          nxt.specialdata = FloorMove.new(sector: nxt, direction: 1, dest: height, speed: speed)
          @thinkers << nxt.specialdata
          cur = nxt
        end
      end
      ok
    end

    def start_floor(sec, dest, direction, speed, crush = false, floorpic = nil)
      return false if sec.specialdata

      floor = FloorMove.new(sector: sec, direction: direction, dest: dest, speed: speed, crush: crush, floorpic: floorpic)
      sec.specialdata = floor
      @thinkers << floor
      true
    end

    def do_crusher(line, ctype)
      ok = false
      sectors_from_tag(line.tag).each do |sec|
        next if sec.specialdata

        top = sec.ceilingheight
        bottom = sec.floorheight
        crush = ctype != Defs::CEIL_RAISETOHIGHEST
        speed = Defs::CEILSPEED * (ctype == Defs::CEIL_FASTCRUSH ? 2 : 1)
        direction = -1
        dest = bottom
        if ctype == Defs::CEIL_RAISETOHIGHEST
          dest = highest_ceiling(sec)
          direction = 1
          crush = false
        elsif ctype != Defs::CEIL_LOWERTOFLOOR
          bottom += 8 * Defs::FRACUNIT
          dest = bottom
        end
        ceil = CeilingMove.new(
          sector: sec, direction: direction, dest: dest, speed: speed,
          crush: crush, ctype: ctype, topheight: top, bottomheight: bottom
        )
        sec.specialdata = ceil
        @thinkers << ceil
        ok = true
      end
      ok
    end

    def do_donut(line)
      ok = false
      sectors_from_tag(line.tag).each do |s1|
        next if s1.specialdata || s1.lines.empty?

        edge = s1.lines[0]
        s2 = edge.frontsector.equal?(s1) ? edge.backsector : edge.frontsector
        next unless s2

        s3 = nil
        s2.lines.each do |ln|
          other = ln.backsector
          next if other.nil? || other.equal?(s1)

          s3 = other
          break
        end
        next unless s3

        ok = true if start_floor(s2, s3.floorheight, 1, Defs::FLOORSPEED / 2, false, s3.floorpic)
        ok = true if start_floor(s1, s3.floorheight, -1, Defs::FLOORSPEED / 2)
      end
      ok
    end

    def do_plat_perpetual(line)
      ok = false
      sectors_from_tag(line.tag).each do |sec|
        next if sec.specialdata

        low = lowest_floor(sec)
        high = highest_floor(sec)
        low = sec.floorheight if low > sec.floorheight
        high = sec.floorheight if high < sec.floorheight
        plat = Plat.new(
          sector: sec, type: Defs::PLAT_PERPETUAL, status: Rng.p_random & 1,
          speed: Defs::PLATSPEED, low: low, high: high, wait: Defs::PLATWAIT * Defs::TICRATE
        )
        sec.specialdata = plat
        @thinkers << plat
        @sound.play('pstart')
        ok = true
      end
      ok
    end

    def do_plat_raise(line, amount = 0)
      ok = false
      pic = nil
      front = line.sides[0]
      pic = front.sector.floorpic if front&.sector
      sectors_from_tag(line.tag).each do |sec|
        next if sec.specialdata

        high = amount.zero? ? next_highest_floor(sec, sec.floorheight) : sec.floorheight + amount
        sec.floorpic = pic unless pic.nil?
        plat = Plat.new(
          sector: sec, type: Defs::PLAT_DWUS, status: Defs::PLAT_UP, speed: Defs::PLATSPEED / 2,
          low: sec.floorheight, high: high, wait: 0
        )
        sec.specialdata = plat
        @thinkers << plat
        @sound.play('pstart')
        ok = true
      end
      ok
    end

    def stop_plat(line)
      ok = false
      @thinkers.each do |th|
        next unless th.is_a?(Plat) && !th.dead && th.sector.tag == line.tag

        th.status = Defs::PLAT_WAITING
        th.count = 0x7FFFFFFF
        ok = true
      end
      ok
    end

    def raise_to_texture(line)
      ok = false
      sectors_from_tag(line.tag).each do |sec|
        next if sec.specialdata

        minsize = 0x7FFFFFFF
        sec.lines.each do |ln|
          next if (ln.flags & Defs::ML_TWOSIDED).zero?

          ln.sides.each do |side|
            next if side.nil? || side.bottomtexture <= 0
            next if side.bottomtexture >= @res.textures.length

            h = @res.texture_height(side.bottomtexture)
            minsize = h if h.positive? && h < minsize
          end
        end
        minsize = 64 * Defs::FRACUNIT if minsize == 0x7FFFFFFF
        ok = true if start_floor(sec, sec.floorheight + minsize, 1, Defs::FLOORSPEED)
      end
      ok
    end

    def lower_and_change(line)
      ok = false
      sectors_from_tag(line.tag).each do |sec|
        next if sec.specialdata

        dest = lowest_floor(sec)
        pic = sec.floorpic
        surrounding(sec).each do |other|
          next unless other.floorheight == dest

          pic = other.floorpic
          break
        end
        ok = true if start_floor(sec, dest, -1, Defs::FLOORSPEED, false, pic)
      end
      ok
    end

    def light_turn_on(line, bright)
      ok = false
      sectors_from_tag(line.tag).each do |sec|
        sec.lightlevel = bright.zero? ? max_light(sec) : bright
        ok = true
      end
      ok
    end

    def turn_tag_lights_off(line)
      ok = false
      sectors_from_tag(line.tag).each do |sec|
        sec.lightlevel = min_light(sec, sec.lightlevel)
        ok = true
      end
      ok
    end

    def start_light_strobing(line)
      ok = false
      sectors_from_tag(line.tag).each do |sec|
        next if sec.specialdata

        spawn_strobe(sec, Defs::SLOWDARK, false)
        ok = true
      end
      ok
    end

    def spawn_light_flash(sector)
      sector.special = 0
      flash = LightThinker.new(
        sector: sector, kind: 'flash', maxlight: sector.lightlevel,
        minlight: min_light(sector, sector.lightlevel), maxtime: 64, mintime: 7
      )
      flash.count = (Rng.p_random & flash.maxtime) + 1
      @lights << flash
    end

    def spawn_strobe(sector, darktime, synced)
      sector.special = 0
      minl = min_light(sector, sector.lightlevel)
      minl = 0 if minl == sector.lightlevel
      @lights << LightThinker.new(
        sector: sector, kind: 'strobe', maxlight: sector.lightlevel, minlight: minl,
        darktime: darktime, brighttime: Defs::STROBEBRIGHT,
        count: synced ? 1 : (Rng.p_random & 7) + 1
      )
    end

    def spawn_glow(sector)
      sector.special = 0
      @lights << LightThinker.new(
        sector: sector, kind: 'glow', maxlight: sector.lightlevel,
        minlight: min_light(sector, sector.lightlevel), direction: -1
      )
    end

    def spawn_fire_flicker(sector)
      sector.special = 0
      @lights << LightThinker.new(
        sector: sector, kind: 'fire', maxlight: sector.lightlevel,
        minlight: min_light(sector, sector.lightlevel) + 16, count: 4
      )
    end

    def spawn_door_close_in_30(sector)
      return if sector.specialdata

      sector.special = 0
      door = VerticalDoor.new(
        sector: sector, type: Defs::VLD_CLOSE, direction: 0, topheight: sector.ceilingheight,
        speed: Defs::VDOORSPEED, topwait: Defs::VDOORWAIT, topcountdown: 30 * Defs::TICRATE
      )
      sector.specialdata = door
      @thinkers << door
    end

    def spawn_door_raise_in_5(sector)
      return if sector.specialdata

      sector.special = 0
      door = VerticalDoor.new(
        sector: sector, type: Defs::VLD_RAISEIN5, direction: 0,
        topheight: lowest_ceiling(sector) - 4 * Defs::FRACUNIT, speed: Defs::VDOORSPEED,
        topwait: Defs::VDOORWAIT, topcountdown: 5 * 60 * Defs::TICRATE
      )
      sector.specialdata = door
      @thinkers << door
    end

    def tick_lights
      @lights.each do |light|
        if light.kind == 'glow'
          if light.direction == -1
            light.sector.lightlevel -= Defs::GLOWSPEED
            if light.sector.lightlevel <= light.minlight
              light.sector.lightlevel += Defs::GLOWSPEED
              light.direction = 1
            end
          else
            light.sector.lightlevel += Defs::GLOWSPEED
            if light.sector.lightlevel >= light.maxlight
              light.sector.lightlevel -= Defs::GLOWSPEED
              light.direction = -1
            end
          end
          next
        end
        light.count -= 1
        next unless light.count.zero?

        case light.kind
        when 'flash'
          if light.sector.lightlevel == light.maxlight
            light.sector.lightlevel = light.minlight
            light.count = (Rng.p_random & light.mintime) + 1
          else
            light.sector.lightlevel = light.maxlight
            light.count = (Rng.p_random & light.maxtime) + 1
          end
        when 'strobe'
          if light.sector.lightlevel == light.minlight
            light.sector.lightlevel = light.maxlight
            light.count = light.brighttime
          else
            light.sector.lightlevel = light.minlight
            light.count = light.darktime
          end
        when 'fire'
          amount = (Rng.p_random & 3) * 16
          if light.sector.lightlevel - amount < light.minlight
            light.sector.lightlevel = light.minlight
          else
            light.sector.lightlevel = light.maxlight - amount
          end
          light.count = 4
        end
      end
    end

    def change_switch(line, use_again)
      side = line.sides[0]
      return unless side

      line.special = 0 if use_again.zero?
      sound = line.special == 11 ? 'swtchx' : 'swtchn'
      %w[top mid bottom].each do |where|
        tex = side.send("#{where}texture")
        next unless @switch_map.key?(tex)

        @buttons << Button.new(line, where, tex, Defs::BUTTONTIME) unless use_again.zero?
        side.send("#{where}texture=", @switch_map[tex])
        @sound.play(sound)
        return
      end
      @sound.play(sound)
    end

    def use_special(line, thing, side)
      return false unless side.zero?

      spec = line.special
      if [1, 26, 27, 28, 31, 32, 33, 34, 117, 118].include?(spec)
        vertical_door(line, thing)
        return true
      end
      if [99, 133, 134, 135, 136, 137].include?(spec)
        locked_blaze_door(line, thing, spec)
        return true
      end
      if spec == 11
        change_switch(line, 0)
        @exit_requested = true
        return true
      end
      if spec == 51
        change_switch(line, 0)
        @exit_requested = true
        @secret_exit = true
        return true
      end
      acted = use_tagged(spec, line)
      return false if acted.nil?

      change_switch(line, acted[1]) if acted[0]
      acted[0]
    end

    def use_tagged(spec, line)
      once = {
        29 => -> { do_door(line, Defs::VLD_NORMAL) },
        50 => -> { do_door(line, Defs::VLD_CLOSE) },
        103 => -> { do_door(line, Defs::VLD_OPEN) },
        111 => -> { do_door(line, Defs::VLD_BLAZERAISE) },
        112 => -> { do_door(line, Defs::VLD_BLAZEOPEN) },
        113 => -> { do_door(line, Defs::VLD_BLAZECLOSE) },
        21 => -> { do_plat_dwus(line) },
        122 => -> { do_plat_dwus(line, true) },
        18 => -> { do_floor(line, ->(s) { next_highest_floor(s, s.floorheight) }, 1) },
        23 => -> { do_floor(line, method(:lowest_floor), -1) },
        71 => -> { do_floor(line, method(:highest_floor), -1) },
        101 => -> { do_floor(line, method(:raise_floor_dest), 1) },
        102 => -> { do_floor(line, method(:highest_floor), -1) },
        7 => -> { do_stairs(line, 8 * Defs::FRACUNIT, Defs::FLOORSPEED / 4) },
        127 => -> { do_stairs(line, 16 * Defs::FRACUNIT, Defs::FLOORSPEED * 4) },
        41 => -> { do_crusher(line, Defs::CEIL_LOWERTOFLOOR) },
        49 => -> { do_crusher(line, Defs::CEIL_CRUSHANDRAISE) },
        9 => -> { do_donut(line) },
        14 => -> { do_plat_raise(line, 32 * Defs::FRACUNIT) },
        15 => -> { do_plat_raise(line, 24 * Defs::FRACUNIT) },
        20 => -> { do_plat_raise(line, 0) },
        55 => -> { do_floor(line, method(:raise_floor_crush_dest), 1, nil, true) },
        131 => -> { do_floor(line, ->(s) { next_highest_floor(s, s.floorheight) }, 1, Defs::FLOORSPEED * 4) },
        140 => -> { do_floor(line, ->(s) { s.floorheight + 512 * Defs::FRACUNIT }, 1) }
      }
      again = {
        42 => -> { do_door(line, Defs::VLD_CLOSE) },
        61 => -> { do_door(line, Defs::VLD_OPEN) },
        63 => -> { do_door(line, Defs::VLD_NORMAL) },
        62 => -> { do_plat_dwus(line) },
        114 => -> { do_door(line, Defs::VLD_BLAZERAISE) },
        115 => -> { do_door(line, Defs::VLD_BLAZEOPEN) },
        116 => -> { do_door(line, Defs::VLD_BLAZECLOSE) },
        120 => -> { do_plat_dwus(line, true) },
        123 => -> { do_plat_dwus(line, true) },
        45 => -> { do_floor(line, method(:highest_floor), -1) },
        60 => -> { do_floor(line, method(:lowest_floor), -1) },
        64 => -> { do_floor(line, method(:raise_floor_dest), 1) },
        70 => -> { do_floor(line, method(:highest_floor), -1, Defs::FLOORSPEED * 4) },
        43 => -> { do_crusher(line, Defs::CEIL_LOWERTOFLOOR) },
        65 => -> { do_floor(line, method(:raise_floor_crush_dest), 1, nil, true) },
        66 => -> { do_plat_raise(line, 24 * Defs::FRACUNIT) },
        67 => -> { do_plat_raise(line, 32 * Defs::FRACUNIT) },
        68 => -> { do_plat_raise(line, 0) },
        69 => -> { do_floor(line, ->(s) { next_highest_floor(s, s.floorheight) }, 1) },
        132 => -> { do_floor(line, ->(s) { next_highest_floor(s, s.floorheight) }, 1, Defs::FLOORSPEED * 4) },
        138 => -> { light_turn_on(line, 255) },
        139 => -> { light_turn_on(line, 35) }
      }
      return [once[spec].call, 0] if once.key?(spec)
      return [again[spec].call, 1] if again.key?(spec)

      nil
    end

    def cross_action(line, side, thing, spec)
      once = {
        2 => -> { do_door(line, Defs::VLD_OPEN) },
        3 => -> { do_door(line, Defs::VLD_CLOSE) },
        4 => -> { do_door(line, Defs::VLD_NORMAL) },
        5 => -> { do_floor(line, method(:raise_floor_dest), 1) },
        6 => -> { do_crusher(line, Defs::CEIL_FASTCRUSH) },
        8 => -> { do_stairs(line, 8 * Defs::FRACUNIT, Defs::FLOORSPEED / 4) },
        10 => -> { do_plat_dwus(line) },
        12 => -> { light_turn_on(line, 0) },
        13 => -> { light_turn_on(line, 255) },
        16 => -> { do_door(line, Defs::VLD_CLOSE30, true) },
        17 => -> { start_light_strobing(line) },
        19 => -> { do_floor(line, method(:highest_floor), -1) },
        22 => -> { do_plat_raise(line, 0) },
        25 => -> { do_crusher(line, Defs::CEIL_CRUSHANDRAISE) },
        30 => -> { raise_to_texture(line) },
        35 => -> { light_turn_on(line, 35) },
        36 => -> { do_floor(line, method(:highest_floor), -1, Defs::FLOORSPEED * 4) },
        37 => -> { lower_and_change(line) },
        38 => -> { do_floor(line, method(:lowest_floor), -1) },
        39 => -> { teleport(line, side, thing) || true },
        40 => -> { do_crusher(line, Defs::CEIL_RAISETOHIGHEST); do_floor(line, method(:lowest_floor), -1) },
        44 => -> { do_crusher(line, Defs::CEIL_LOWERANDCRUSH) },
        53 => -> { do_plat_perpetual(line) },
        54 => -> { stop_plat(line) },
        56 => -> { do_floor(line, method(:raise_floor_crush_dest), 1, nil, true) },
        57 => -> { stop_plat(line) },
        58 => -> { do_floor(line, ->(s) { s.floorheight + 24 * Defs::FRACUNIT }, 1) },
        59 => -> { do_floor(line, ->(s) { s.floorheight + 24 * Defs::FRACUNIT }, 1) },
        100 => -> { do_stairs(line, 16 * Defs::FRACUNIT, Defs::FLOORSPEED * 4) },
        104 => -> { turn_tag_lights_off(line) },
        108 => -> { do_door(line, Defs::VLD_BLAZERAISE) },
        109 => -> { do_door(line, Defs::VLD_BLAZEOPEN) },
        110 => -> { do_door(line, Defs::VLD_BLAZECLOSE) },
        119 => -> { do_floor(line, ->(s) { next_highest_floor(s, s.floorheight) }, 1) },
        121 => -> { do_plat_dwus(line, true) },
        125 => -> { teleport(line, side, thing) if thing.player.nil?; true },
        130 => -> { do_floor(line, ->(s) { next_highest_floor(s, s.floorheight) }, 1, Defs::FLOORSPEED * 4) },
        141 => -> { do_crusher(line, Defs::CEIL_SILENTCRUSH) }
      }
      again = {
        72 => -> { do_crusher(line, Defs::CEIL_LOWERANDCRUSH) },
        73 => -> { do_crusher(line, Defs::CEIL_CRUSHANDRAISE) },
        74 => -> { stop_plat(line) },
        75 => -> { do_door(line, Defs::VLD_CLOSE) },
        76 => -> { do_door(line, Defs::VLD_CLOSE30, true) },
        77 => -> { do_crusher(line, Defs::CEIL_FASTCRUSH) },
        79 => -> { light_turn_on(line, 35) },
        80 => -> { light_turn_on(line, 0) },
        81 => -> { light_turn_on(line, 255) },
        82 => -> { do_floor(line, method(:lowest_floor), -1) },
        83 => -> { do_floor(line, method(:highest_floor), -1) },
        84 => -> { lower_and_change(line) },
        86 => -> { do_door(line, Defs::VLD_OPEN) },
        87 => -> { do_plat_perpetual(line) },
        88 => -> { do_plat_dwus(line) },
        89 => -> { stop_plat(line) },
        90 => -> { do_door(line, Defs::VLD_NORMAL) },
        91 => -> { do_floor(line, method(:raise_floor_dest), 1) },
        92 => -> { do_floor(line, ->(s) { s.floorheight + 24 * Defs::FRACUNIT }, 1) },
        93 => -> { do_floor(line, ->(s) { s.floorheight + 24 * Defs::FRACUNIT }, 1) },
        94 => -> { do_floor(line, method(:raise_floor_crush_dest), 1, nil, true) },
        95 => -> { do_plat_raise(line, 0) },
        96 => -> { raise_to_texture(line) },
        97 => -> { teleport(line, side, thing) },
        98 => -> { do_floor(line, method(:highest_floor), -1, Defs::FLOORSPEED * 4) },
        105 => -> { do_door(line, Defs::VLD_BLAZERAISE) },
        106 => -> { do_door(line, Defs::VLD_BLAZEOPEN) },
        107 => -> { do_door(line, Defs::VLD_BLAZECLOSE) },
        120 => -> { do_plat_dwus(line, true) },
        126 => -> { thing.player.nil? && teleport(line, side, thing) },
        128 => -> { do_floor(line, ->(s) { next_highest_floor(s, s.floorheight) }, 1) },
        129 => -> { do_floor(line, ->(s) { next_highest_floor(s, s.floorheight) }, 1, Defs::FLOORSPEED * 4) }
      }
      if once.key?(spec)
        once[spec].call
        return :clear
      end
      if again.key?(spec)
        again[spec].call
        return :keep
      end
      nil
    end

    def cross_special(line, side, thing)
      spec = line.special
      if spec == 52
        @exit_requested = true
        return
      end
      if spec == 124
        @exit_requested = true
        @secret_exit = true
        return
      end
      result = cross_action(line, side, thing, spec)
      line.special = 0 if result == :clear
    end

    def teleport(line, side, thing)
      return if side == 1 || (thing.flags & Defs::MF_MISSILE) != 0

      @world.sectors.each_with_index do |sector, i|
        next unless sector.tag == line.tag

        @world.mobjs.each do |dest|
          next unless dest.doomednum == 14

          dest_sector = @world.point_in_subsector(dest.x, dest.y).sector
          next unless dest_sector.equal?(sector) || dest_sector.i_sector == i

          thing.momx = thing.momy = thing.momz = 0
          Collision.unset_thing_position(@world, thing)
          thing.x = dest.x
          thing.y = dest.y
          landed = @world.point_in_subsector(thing.x, thing.y)
          thing.floorz = landed.sector.floorheight
          thing.ceilingz = landed.sector.ceilingheight
          thing.z = thing.floorz
          thing.angle = dest.angle
          Collision.set_thing_position(@world, thing)
          if thing.player
            thing.player.viewz = thing.z + thing.player.viewheight
            thing.reactiontime = 18
          end
          @sound.play('telept')
          return true
        end
      end
      false
    end
  end
end
