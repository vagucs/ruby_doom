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
# Colisao do corpo e o rastro do tiro.

module Doom
  class MoveCheck
    attr_accessor :floorz, :ceilingz, :dropoffz, :spechit, :blocked, :ceilingline, :bbox

    def initialize
      @floorz = @ceilingz = @dropoffz = 0
      @spechit = []
      @blocked = false
      @ceilingline = nil
      @bbox = [0, 0, 0, 0]
    end
  end

  class DivLine
    attr_accessor :x, :y, :dx, :dy

    def initialize(x, y, dx, dy)
      @x = x
      @y = y
      @dx = dx
      @dy = dy
    end
  end

  module Collision
    INT_MAX = 0x7FFFFFFF

    module_function

    def point_on_line_side(x, y, line)
      if line.dx.zero?
        return line.dy.positive? ? 1 : 0 if x <= line.v1.x

        return line.dy.negative? ? 1 : 0
      end
      if line.dy.zero?
        return line.dx.negative? ? 1 : 0 if y <= line.v1.y

        return line.dx.positive? ? 1 : 0
      end
      dx = Compat.as_i32(x - line.v1.x)
      dy = Compat.as_i32(y - line.v1.y)
      left = Compat.fixed_mul(line.dy >> Defs::FRACBITS, dx)
      right = Compat.fixed_mul(dy, line.dx >> Defs::FRACBITS)
      right < left ? 0 : 1
    end

    def box_on_line_side(bbox, line)
      if line.dx.zero?
        p1 = bbox[Defs::BOXRIGHT] < line.v1.x ? 0 : 1
        p2 = bbox[Defs::BOXLEFT] < line.v1.x ? 0 : 1
        if line.dy.positive?
          p1 ^= 1
          p2 ^= 1
        end
      elsif line.dy.zero?
        p1 = bbox[Defs::BOXTOP] > line.v1.y ? 0 : 1
        p2 = bbox[Defs::BOXBOTTOM] > line.v1.y ? 0 : 1
        if line.dx.negative?
          p1 ^= 1
          p2 ^= 1
        end
      else
        slopetype = (line.dy.positive? == line.dx.positive?) ? 0 : 1
        if slopetype.zero?
          p1 = point_on_line_side(bbox[Defs::BOXLEFT], bbox[Defs::BOXTOP], line)
          p2 = point_on_line_side(bbox[Defs::BOXRIGHT], bbox[Defs::BOXBOTTOM], line)
        else
          p1 = point_on_line_side(bbox[Defs::BOXRIGHT], bbox[Defs::BOXTOP], line)
          p2 = point_on_line_side(bbox[Defs::BOXLEFT], bbox[Defs::BOXBOTTOM], line)
        end
      end
      p1 == p2 ? p1 : -1
    end

    def line_opening(line)
      return [0, 0, 0] if line.backsector.nil?

      front = line.frontsector
      back = line.backsector
      opentop = [front.ceilingheight, back.ceilingheight].min
      if front.floorheight > back.floorheight
        [opentop, front.floorheight, back.floorheight]
      else
        [opentop, back.floorheight, front.floorheight]
      end
    end

    def unset_thing_position(world, thing)
      return unless thing.blocklinked

      nxt = thing.bnext
      prev = thing.bprev
      if nxt
        nxt.bprev = prev
      end
      if prev
        prev.bnext = nxt
      else
        i = thing.bindex
        links = world.blocklinks
        links[i] = nxt if i && i >= 0 && i < links.length && links[i].equal?(thing)
      end
      thing.bnext = nil
      thing.bprev = nil
      thing.blocklinked = false
    end

    def set_thing_position(world, thing)
      links = world.blocklinks
      thing.bnext = nil
      thing.bprev = nil
      thing.blocklinked = false
      return if (thing.flags & Defs::MF_NOBLOCKMAP) != 0 || links.nil? || links.empty?

      bx = Compat.shar(thing.x - world.bmaporgx, Defs::MAPBLOCKSHIFT)
      by = Compat.shar(thing.y - world.bmaporgy, Defs::MAPBLOCKSHIFT)
      return if bx.negative? || by.negative? || bx >= world.bmapwidth || by >= world.bmapheight

      i = by * world.bmapwidth + bx
      head = links[i]
      thing.bnext = head
      head.bprev = thing if head
      links[i] = thing
      thing.bindex = i
      thing.blocklinked = true
    end

    def block_things(world, x, y)
      return true if x.negative? || y.negative? || x >= world.bmapwidth || y >= world.bmapheight

      mo = world.blocklinks[y * world.bmapwidth + x]
      while mo
        nxt = mo.bnext
        return false unless yield(mo)

        mo = nxt
      end
      true
    end

    def block_lines(world, x, y)
      return true if x.negative? || y.negative? || x >= world.bmapwidth || y >= world.bmapheight

      lump = world.blockmaplump
      offset = world.blockmap[y * world.bmapwidth + x]
      while offset && offset >= 0 && offset < lump.length
        n = lump[offset]
        offset += 1
        return true if n == 0xFFFF
        next if n >= world.lines.length

        ld = world.lines[n]
        next if ld.validcount == world.validcount

        ld.validcount = world.validcount
        return false unless yield(ld)
      end
      true
    end

    def pit_thing(world, thing, other, game = nil)
      return true if (other.flags & (Defs::MF_SOLID | Defs::MF_SPECIAL | Defs::MF_SHOOTABLE)).zero?

      blockdist = other.radius + thing.radius
      return true if (other.x - thing.tmx).abs >= blockdist || (other.y - thing.tmy).abs >= blockdist
      return true if other.equal?(thing)
      if (thing.flags & Defs::MF_SKULLFLY) != 0
        dmg = ((Rng.p_random % 8) + 1) * thing.damage
        game&.damage_mobj(other, thing, dmg, thing)
        thing.flags &= ~Defs::MF_SKULLFLY
        thing.momx = thing.momy = thing.momz = 0
        Thinker.set_mobj_state(thing, Info::MOBJINFO[thing.type][Info::MI_SPAWNSTATE], world, game)
        return false
      end
      if (thing.flags & Defs::MF_MISSILE) != 0
        target = thing.target
        if target && same_species(target, other)
          return true if other.equal?(target)
          return false if other.type != Info::MT_PLAYER
        end
        return (other.flags & Defs::MF_SOLID).zero? if (other.flags & Defs::MF_SHOOTABLE).zero?
        return true unless Enemy.missile_reaches(thing, other, thing.tmx, thing.tmy, thing.z)

        return false
      end
      if (other.flags & Defs::MF_SPECIAL) != 0
        solid = (other.flags & Defs::MF_SOLID) != 0
        game.touch_special(other, thing) if game && (thing.flags & Defs::MF_PICKUP) != 0
        return !solid
      end

      (other.flags & Defs::MF_SOLID).zero?
    end

    def same_species(target, other)
      return true if target.type == other.type
      return true if target.type == Info::MT_KNIGHT && other.type == Info::MT_BRUISER

      target.type == Info::MT_BRUISER && other.type == Info::MT_KNIGHT
    end

    def pit_line(thing, chk, ld)
      bbox = chk.bbox
      return true if bbox[Defs::BOXRIGHT] <= ld.bbox[Defs::BOXLEFT] ||
                      bbox[Defs::BOXLEFT] >= ld.bbox[Defs::BOXRIGHT] ||
                      bbox[Defs::BOXTOP] <= ld.bbox[Defs::BOXBOTTOM] ||
                      bbox[Defs::BOXBOTTOM] >= ld.bbox[Defs::BOXTOP]
      return true if box_on_line_side(bbox, ld) != -1
      return false if ld.backsector.nil?

      if (thing.flags & Defs::MF_MISSILE).zero?
        return false if (ld.flags & Defs::ML_BLOCKING) != 0
        return false if thing.player.nil? && (ld.flags & Defs::ML_BLOCKMONSTERS) != 0
      end
      opentop, openbottom, lowfloor = line_opening(ld)
      if opentop < chk.ceilingz
        chk.ceilingz = opentop
        chk.ceilingline = ld
      end
      chk.floorz = openbottom if openbottom > chk.floorz
      chk.dropoffz = lowfloor if lowfloor < chk.dropoffz
      chk.spechit << ld if ld.special != 0
      true
    end

    def check_position(world, thing, x, y, game = nil)
      chk = MoveCheck.new
      thing.tmx = x
      thing.tmy = y
      radius = thing.radius
      bbox = chk.bbox
      bbox[Defs::BOXTOP] = y + radius
      bbox[Defs::BOXBOTTOM] = y - radius
      bbox[Defs::BOXRIGHT] = x + radius
      bbox[Defs::BOXLEFT] = x - radius
      sub = world.point_in_subsector(x, y)
      chk.floorz = sub.sector.floorheight
      chk.dropoffz = chk.floorz
      chk.ceilingz = sub.sector.ceilingheight
      world.validcount += 1
      return chk if (thing.flags & Defs::MF_NOCLIP) != 0

      links = world.blocklinks
      return chk if links.nil? || links.empty?

      orgx = world.bmaporgx
      orgy = world.bmaporgy
      xl = Compat.shar(bbox[Defs::BOXLEFT] - orgx - Defs::MAXRADIUS, Defs::MAPBLOCKSHIFT)
      xh = Compat.shar(bbox[Defs::BOXRIGHT] - orgx + Defs::MAXRADIUS, Defs::MAPBLOCKSHIFT)
      yl = Compat.shar(bbox[Defs::BOXBOTTOM] - orgy - Defs::MAXRADIUS, Defs::MAPBLOCKSHIFT)
      yh = Compat.shar(bbox[Defs::BOXTOP] - orgy + Defs::MAXRADIUS, Defs::MAPBLOCKSHIFT)
      xl.upto(xh) do |bx|
        yl.upto(yh) do |by|
            unless block_things(world, bx, by) { |th| pit_thing(world, thing, th, game) }
            chk.blocked = true
            return chk
          end
        end
      end
      xl = Compat.shar(bbox[Defs::BOXLEFT] - orgx, Defs::MAPBLOCKSHIFT)
      xh = Compat.shar(bbox[Defs::BOXRIGHT] - orgx, Defs::MAPBLOCKSHIFT)
      yl = Compat.shar(bbox[Defs::BOXBOTTOM] - orgy, Defs::MAPBLOCKSHIFT)
      yh = Compat.shar(bbox[Defs::BOXTOP] - orgy, Defs::MAPBLOCKSHIFT)
      xl.upto(xh) do |bx|
        yl.upto(yh) do |by|
          unless block_lines(world, bx, by) { |ld| pit_line(thing, chk, ld) }
            chk.blocked = true
            return chk
          end
        end
      end
      chk
    end

    def floatok
      @floatok
    end

    def tmfloorz
      @tmfloorz
    end

    def last_spechit
      @last_spechit || []
    end

    def ceilingline
      @ceilingline
    end

    def try_move(world, thing, x, y, game = nil)
      @floatok = false
      @ceilingline = nil
      chk = check_position(world, thing, x, y, game)
      @last_spechit = chk.spechit
      @tmfloorz = chk.floorz
      @ceilingline = chk.ceilingline
      return false if chk.blocked
      unless (thing.flags & Defs::MF_NOCLIP) != 0
        return false if chk.ceilingz - chk.floorz < thing.height

        @floatok = true
        return false if (thing.flags & Defs::MF_TELEPORT).zero? && chk.ceilingz - thing.z < thing.height
        return false if (thing.flags & Defs::MF_TELEPORT).zero? && chk.floorz - thing.z > Defs::MAXSTEP
        if (thing.flags & (Defs::MF_DROPOFF | Defs::MF_FLOAT)).zero? && chk.floorz - chk.dropoffz > Defs::MAXSTEP
          return false
        end
      end
      oldx = thing.x
      oldy = thing.y
      unset_thing_position(world, thing)
      thing.floorz = chk.floorz
      thing.ceilingz = chk.ceilingz
      thing.x = x
      thing.y = y
      set_thing_position(world, thing)
      cross = game || world.specials
      if cross && (thing.flags & (Defs::MF_TELEPORT | Defs::MF_NOCLIP)).zero?
        chk.spechit.reverse_each do |ln|
          next if ln.special.zero?

          side = point_on_line_side(thing.x, thing.y, ln)
          oldside = point_on_line_side(oldx, oldy, ln)
          if side != oldside
            if game
              game.cross_special(ln, oldside, thing)
            else
              world.specials.cross_special(ln, oldside, thing)
            end
          end
        end
      end
      true
    end

    def thing_height_clip(world, thing)
      on_floor = thing.z == thing.floorz
      chk = check_position(world, thing, thing.x, thing.y)
      thing.floorz = chk.floorz
      thing.ceilingz = chk.ceilingz
      if on_floor
        thing.z = thing.floorz
      elsif thing.z + thing.height > thing.ceilingz
        thing.z = thing.ceilingz - thing.height
      end
      thing.player.viewz = thing.z + thing.player.viewheight if thing.player
      thing.ceilingz - thing.floorz >= thing.height
    end

    def change_sector(world, sector, crush)
      nofit = false
      world.mobjs.each do |thing|
        next unless world.point_in_subsector(thing.x, thing.y).sector.equal?(sector)
        next if thing_height_clip(world, thing)

        if thing.health <= 0
          thing.flags &= ~Defs::MF_SOLID
          thing.height = 0
          next
        end
        next if (thing.flags & Defs::MF_SHOOTABLE).zero?

        nofit = true
        next unless crush

        thing.health -= 10
        thing.player.health = thing.health if thing.player
        if thing.health <= 0
          thing.flags &= ~Defs::MF_SOLID
          thing.height = 0
        end
      end
      nofit
    end

    def use_lines(world, player)
      mo = player.mo
      x1 = mo.x
      y1 = mo.y
      reach = Compat.shar(Defs::USERANGE, Defs::FRACBITS)
      x2 = x1 + reach * Tables.fine_cos(mo.angle)
      y2 = y1 + reach * Tables.fine_sin(mo.angle)
      path_traverse(world, x1, y1, x2, y2) do |inn|
        ln = inn[:line]
        if ln.special.zero?
          opentop, openbottom, = line_opening(ln)
          next false if opentop - openbottom <= 0

          next true
        end
        side = point_on_line_side(mo.x, mo.y, ln) == 1 ? 1 : 0
        world.specials&.use_special(ln, mo, side)
        false
      end
    end

    def point_on_divline_side(x, y, line)
      if line.dx.zero?
        return line.dy.positive? ? 1 : 0 if x <= line.x

        return line.dy.negative? ? 1 : 0
      end
      if line.dy.zero?
        return line.dx.negative? ? 1 : 0 if y <= line.y

        return line.dx.positive? ? 1 : 0
      end
      dx = x - line.x
      dy = y - line.y
      xor = Compat.as_u32(line.dy) ^ Compat.as_u32(line.dx) ^ Compat.as_u32(dx) ^ Compat.as_u32(dy)
      if (xor & 0x80000000) != 0
        return ((Compat.as_u32(line.dy) ^ Compat.as_u32(dx)) & 0x80000000) != 0 ? 1 : 0
      end

      left = Compat.fixed_mul(Compat.shar(line.dy, 8), Compat.shar(dx, 8))
      right = Compat.fixed_mul(Compat.shar(dy, 8), Compat.shar(line.dx, 8))
      right < left ? 0 : 1
    end

    def intercept_vector(v2, v1)
      den = Compat.as_i32(
        Compat.fixed_mul(Compat.shar(v1.dy, 8), v2.dx) - Compat.fixed_mul(Compat.shar(v1.dx, 8), v2.dy)
      )
      return 0 if den.zero?

      num = Compat.as_i32(
        Compat.fixed_mul(Compat.shar(v1.x - v2.x, 8), v1.dy) +
        Compat.fixed_mul(Compat.shar(v2.y - v1.y, 8), v1.dx)
      )
      Compat.fixed_div(num, den)
    end

    def add_line_intercept(ld)
      big = 16 * Defs::FRACUNIT
      dx = @trace_dx
      dy = @trace_dy
      tr = div_trace
      if dx > big || dy > big || dx < -big || dy < -big
        s1 = point_on_divline_side(ld.v1.x, ld.v1.y, tr)
        s2 = point_on_divline_side(ld.v2.x, ld.v2.y, tr)
      else
        s1 = point_on_line_side(@trace_x, @trace_y, ld)
        s2 = point_on_line_side(@trace_x + dx, @trace_y + dy, ld)
      end
      return true if s1 == s2

      frac = intercept_vector(tr, DivLine.new(ld.v1.x, ld.v1.y, ld.dx, ld.dy))
      return true if frac.negative?
      return false if @earlyout && frac < Defs::FRACUNIT && ld.backsector.nil?

      @intercepts << { frac: frac, isaline: true, line: ld, thing: nil }
      true
    end

    def add_thing_intercept(thing)
      tr = div_trace
      positive = Compat.as_i32(Compat.as_u32(tr.dx) ^ Compat.as_u32(tr.dy)).positive?
      if positive
        x1 = thing.x - thing.radius
        y1 = thing.y + thing.radius
        x2 = thing.x + thing.radius
        y2 = thing.y - thing.radius
      else
        x1 = thing.x - thing.radius
        y1 = thing.y - thing.radius
        x2 = thing.x + thing.radius
        y2 = thing.y + thing.radius
      end
      return true if point_on_divline_side(x1, y1, tr) == point_on_divline_side(x2, y2, tr)

      frac = intercept_vector(tr, DivLine.new(x1, y1, x2 - x1, y2 - y1))
      return true if frac.negative?

      @intercepts << { frac: frac, isaline: false, line: nil, thing: thing }
      true
    end

    def div_trace
      DivLine.new(@trace_x, @trace_y, @trace_dx, @trace_dy)
    end

    def traverse_intercepts(maxfrac)
      count = @intercepts.length
      while count.positive?
        count -= 1
        dist = INT_MAX
        chosen = nil
        @intercepts.each do |scan|
          next unless scan[:frac] < dist

          dist = scan[:frac]
          chosen = scan
        end
        return true if dist > maxfrac
        return false if chosen.nil? || !yield(chosen)

        chosen[:frac] = INT_MAX
      end
      true
    end

    def abs32(n)
      n = Compat.as_i32(n)
      n.negative? ? -n : n
    end

    def path_traverse(world, x1, y1, x2, y2, flags = Defs::PT_ADDLINES)
      @earlyout = (flags & Defs::PT_EARLYOUT) != 0
      @intercepts = []
      world.validcount += 1
      orgx = world.bmaporgx
      orgy = world.bmaporgy
      x1 += Defs::FRACUNIT if ((x1 - orgx) & (Defs::MAPBLOCKSIZE - 1)).zero?
      y1 += Defs::FRACUNIT if ((y1 - orgy) & (Defs::MAPBLOCKSIZE - 1)).zero?
      @trace_x = x1
      @trace_y = y1
      @trace_dx = Compat.as_i32(x2 - x1)
      @trace_dy = Compat.as_i32(y2 - y1)
      x1 = Compat.as_i32(x1 - orgx)
      y1 = Compat.as_i32(y1 - orgy)
      xt1 = Compat.shar(x1, Defs::MAPBLOCKSHIFT)
      yt1 = Compat.shar(y1, Defs::MAPBLOCKSHIFT)
      x2m = Compat.as_i32(x2 - orgx)
      y2m = Compat.as_i32(y2 - orgy)
      xt2 = Compat.shar(x2m, Defs::MAPBLOCKSHIFT)
      yt2 = Compat.shar(y2m, Defs::MAPBLOCKSHIFT)
      if xt2 > xt1
        mapxstep = 1
        partial = Defs::FRACUNIT - (Compat.shar(x1, Defs::MAPBTOFRAC) & (Defs::FRACUNIT - 1))
        ystep = Compat.fixed_div(Compat.as_i32(y2m - y1), abs32(Compat.as_i32(x2m - x1)))
      elsif xt2 < xt1
        mapxstep = -1
        partial = Compat.shar(x1, Defs::MAPBTOFRAC) & (Defs::FRACUNIT - 1)
        ystep = Compat.fixed_div(Compat.as_i32(y2m - y1), abs32(Compat.as_i32(x2m - x1)))
      else
        mapxstep = 0
        partial = Defs::FRACUNIT
        ystep = 256 * Defs::FRACUNIT
      end
      yintercept = Compat.as_i32(Compat.shar(y1, Defs::MAPBTOFRAC) + Compat.fixed_mul(partial, ystep))
      if yt2 > yt1
        mapystep = 1
        partial = Defs::FRACUNIT - (Compat.shar(y1, Defs::MAPBTOFRAC) & (Defs::FRACUNIT - 1))
        xstep = Compat.fixed_div(Compat.as_i32(x2m - x1), abs32(Compat.as_i32(y2m - y1)))
      elsif yt2 < yt1
        mapystep = -1
        partial = Compat.shar(y1, Defs::MAPBTOFRAC) & (Defs::FRACUNIT - 1)
        xstep = Compat.fixed_div(Compat.as_i32(x2m - x1), abs32(Compat.as_i32(y2m - y1)))
      else
        mapystep = 0
        partial = Defs::FRACUNIT
        xstep = 256 * Defs::FRACUNIT
      end
      xintercept = Compat.as_i32(Compat.shar(x1, Defs::MAPBTOFRAC) + Compat.fixed_mul(partial, xstep))
      mapx = xt1
      mapy = yt1
      64.times do
        if (flags & Defs::PT_ADDLINES) != 0
          return false unless block_lines(world, mapx, mapy) { |ld| add_line_intercept(ld) }
        end
        if (flags & Defs::PT_ADDTHINGS) != 0
          return false unless block_things(world, mapx, mapy) { |th| add_thing_intercept(th) }
        end
        break if mapx == xt2 && mapy == yt2

        if Compat.shar(yintercept, Defs::FRACBITS) == mapy
          yintercept = Compat.as_i32(yintercept + ystep)
          mapx += mapxstep
        elsif Compat.shar(xintercept, Defs::FRACBITS) == mapx
          xintercept = Compat.as_i32(xintercept + xstep)
          mapy += mapystep
        end
      end
      traverse_intercepts(Defs::FRACUNIT) { |inn| yield(inn) }
    end

    def stairstep(world, thing, game = nil)
      return if try_move(world, thing, thing.x, thing.y + thing.momy, game)

      try_move(world, thing, thing.x + thing.momx, thing.y, game)
    end

    def hit_slide_line(thing, line, tmx, tmy)
      return [tmx, 0] if line.dy.zero?
      return [0, tmy] if line.dx.zero?

      side = point_on_line_side(thing.x, thing.y, line)
      lineangle = angle_to(0, 0, line.dx, line.dy)
      lineangle = Compat.as_u32(lineangle + Defs::ANG180) if side == 1
      moveangle = angle_to(0, 0, tmx, tmy)
      delta = Compat.as_u32(moveangle - lineangle)
      delta = Compat.as_u32(delta + Defs::ANG180) if delta > Defs::ANG180
      newlen = Compat.fixed_mul(approx_distance(tmx, tmy), Tables.fine_cos(delta))
      [Compat.fixed_mul(newlen, Tables.fine_cos(lineangle)), Compat.fixed_mul(newlen, Tables.fine_sin(lineangle))]
    end

    def slide_move(world, thing, momx, momy, game = nil)
      momx = momx.positive? ? Defs::MAXMOVE : -Defs::MAXMOVE if momx.abs > Defs::MAXMOVE
      momy = momy.positive? ? Defs::MAXMOVE : -Defs::MAXMOVE if momy.abs > Defs::MAXMOVE
      thing.momx = momx
      thing.momy = momy
      hitcount = 0
      loop do
        hitcount += 1
        if hitcount == 3
          stairstep(world, thing, game)
          return
        end
        if thing.momx.positive?
          leadx = thing.x + thing.radius
          trailx = thing.x - thing.radius
        else
          leadx = thing.x - thing.radius
          trailx = thing.x + thing.radius
        end
        if thing.momy.positive?
          leady = thing.y + thing.radius
          traily = thing.y - thing.radius
        else
          leady = thing.y - thing.radius
          traily = thing.y + thing.radius
        end
        best = [Defs::FRACUNIT + 1, nil]
        trav = lambda do |inn|
          li = inn[:line]
          blocking = false
          if (li.flags & Defs::ML_TWOSIDED).zero?
            return true if point_on_line_side(thing.x, thing.y, li) != 0

            blocking = true
          else
            opentop, openbottom, = line_opening(li)
            if opentop - openbottom < thing.height ||
               opentop - thing.z < thing.height ||
               openbottom - thing.z > 24 * Defs::FRACUNIT
              blocking = true
            end
          end
          return true unless blocking

          if inn[:frac] < best[0]
            best[0] = inn[:frac]
            best[1] = li
          end
          false
        end
        mx = thing.momx
        my = thing.momy
        path_traverse(world, leadx, leady, leadx + mx, leady + my, &trav)
        path_traverse(world, trailx, leady, trailx + mx, leady + my, &trav)
        path_traverse(world, leadx, traily, leadx + mx, traily + my, &trav)
        if best[0] == Defs::FRACUNIT + 1 || best[1].nil?
          stairstep(world, thing, game)
          return
        end
        best[0] -= 0x800
        if best[0].positive?
          newx = Compat.fixed_mul(thing.momx, best[0])
          newy = Compat.fixed_mul(thing.momy, best[0])
          unless try_move(world, thing, thing.x + newx, thing.y + newy, game)
            stairstep(world, thing, game)
            return
          end
        end
        best[0] = Defs::FRACUNIT - (best[0] + 0x800)
        best[0] = Defs::FRACUNIT if best[0] > Defs::FRACUNIT
        return if best[0] <= 0

        tmx = Compat.fixed_mul(thing.momx, best[0])
        tmy = Compat.fixed_mul(thing.momy, best[0])
        tmx, tmy = hit_slide_line(thing, best[1], tmx, tmy)
        thing.momx = tmx
        thing.momy = tmy
        return if try_move(world, thing, thing.x + tmx, thing.y + tmy, game)
      end
    end

    def shot_ends(source, angle, attackrange)
      x2 = source.x + Compat.shar(attackrange, Defs::FRACBITS) * Tables.fine_cos(angle)
      y2 = source.y + Compat.shar(attackrange, Defs::FRACBITS) * Tables.fine_sin(angle)
      shootz = source.z + (source.height >> 1) + 8 * Defs::FRACUNIT
      [x2, y2, shootz]
    end

    def aim(world, source, angle, attackrange)
      x2, y2, shootz = shot_ends(source, angle, attackrange)
      window = (100 * Defs::FRACUNIT) / 160
      state = { top: window, bottom: -window, slope: 0, target: nil }
      path_traverse(world, source.x, source.y, x2, y2, Defs::PT_ADDLINES | Defs::PT_ADDTHINGS) do |inn|
        if inn[:isaline]
          li = inn[:line]
          next false if (li.flags & Defs::ML_TWOSIDED).zero?

          opentop, openbottom, = line_opening(li)
          next false if openbottom >= opentop

          dist = Compat.fixed_mul(attackrange, inn[:frac])
          front = li.frontsector
          back = li.backsector
          if back.nil? || front.floorheight != back.floorheight
            slope = Compat.fixed_div(openbottom - shootz, dist)
            state[:bottom] = slope if slope > state[:bottom]
          end
          if back.nil? || front.ceilingheight != back.ceilingheight
            slope = Compat.fixed_div(opentop - shootz, dist)
            state[:top] = slope if slope < state[:top]
          end
          next state[:top] > state[:bottom]
        end
        th = inn[:thing]
        next true if th.equal?(source) || (th.flags & Defs::MF_SHOOTABLE).zero?

        dist = Compat.fixed_mul(attackrange, inn[:frac])
        thingtop = Compat.fixed_div(th.z + th.height - shootz, dist)
        next true if thingtop < state[:bottom]

        thingbot = Compat.fixed_div(th.z - shootz, dist)
        next true if thingbot > state[:top]

        thingtop = state[:top] if thingtop > state[:top]
        thingbot = state[:bottom] if thingbot < state[:bottom]
        state[:slope] = (thingtop + thingbot) / 2
        state[:target] = th
        false
      end
      state[:target] ? [state[:slope], state[:target]] : [0, nil]
    end

    def missile_aim(world, source)
      base = source.angle
      span = 16 * 64 * Defs::FRACUNIT
      shifted = Compat.as_u32(base + (1 << 26))
      [base, shifted, Compat.as_u32(shifted - (2 << 26))].each do |ang|
        slope, target = aim(world, source, ang, span)
        return { angle: ang, slope: slope } if target
      end
      { angle: base, slope: 0 }
    end

    def bullet_slope(world, source)
      missile_aim(world, source)[:slope]
    end

    def aim_slope(world, source, angle, attackrange)
      aim(world, source, angle, attackrange)[0]
    end

    def aim_line_attack(world, source, angle, attackrange)
      aim(world, source, angle, attackrange)[1]
    end

    def line_attack(world, source, damage, game, attackrange, angle = nil, slope = nil)
      ang = angle.nil? ? source.angle : angle
      aimslope = slope.nil? ? aim(world, source, ang, attackrange)[0] : slope
      x2, y2, shootz = shot_ends(source, ang, attackrange)
      sky = game&.res&.skyflatnum || -1
      hit = false
      path_traverse(world, source.x, source.y, x2, y2, Defs::PT_ADDLINES | Defs::PT_ADDTHINGS) do |inn|
        if inn[:isaline]
          li = inn[:line]
          game&.shoot_special(li, source) if li.special != 0
          hit_line = false
          dist = Compat.fixed_mul(attackrange, inn[:frac])
          front = li.frontsector
          back = li.backsector
          if (li.flags & Defs::ML_TWOSIDED).zero?
            hit_line = true
          elsif back.nil?
            hit_line = true if Compat.fixed_div(line_opening(li)[1] - shootz, dist) > aimslope
            hit_line = true if Compat.fixed_div(line_opening(li)[0] - shootz, dist) < aimslope
          else
            opentop, openbottom, = line_opening(li)
            if front.floorheight != back.floorheight && Compat.fixed_div(openbottom - shootz, dist) > aimslope
              hit_line = true
            end
            if !hit_line && front.ceilingheight != back.ceilingheight && Compat.fixed_div(opentop - shootz, dist) < aimslope
              hit_line = true
            end
          end
          next true unless hit_line

          frac = inn[:frac] - Compat.fixed_div(4 * Defs::FRACUNIT, attackrange)
          x = @trace_x + Compat.fixed_mul(@trace_dx, frac)
          y = @trace_y + Compat.fixed_mul(@trace_dy, frac)
          z = shootz + Compat.fixed_mul(aimslope, Compat.fixed_mul(frac, attackrange))
          if front && front.ceilingpic == sky
            next false if z > front.ceilingheight
            next false if li.backsector && li.backsector.ceilingpic == sky
          end
          spawn_puff(world, x, y, z, game, attackrange)
          next false
        end
        th = inn[:thing]
        next true if th.equal?(source) || (th.flags & Defs::MF_SHOOTABLE).zero?

        dist = Compat.fixed_mul(attackrange, inn[:frac])
        next true if Compat.fixed_div(th.z + th.height - shootz, dist) < aimslope
        next true if Compat.fixed_div(th.z - shootz, dist) > aimslope

        frac = inn[:frac] - Compat.fixed_div(10 * Defs::FRACUNIT, attackrange)
        x = @trace_x + Compat.fixed_mul(@trace_dx, frac)
        y = @trace_y + Compat.fixed_mul(@trace_dy, frac)
        z = shootz + Compat.fixed_mul(aimslope, Compat.fixed_mul(frac, attackrange))
        if (th.flags & Defs::MF_NOBLOOD) != 0
          spawn_puff(world, x, y, z, game, attackrange)
        else
          spawn_blood(world, x, y, z, game, damage)
        end
        game&.damage_mobj(th, source, damage, source) if game && damage != 0
        hit = true
        false
      end
      hit
    end

    def spawn_puff(world, x, y, z, game, attackrange)
      z += (Rng.p_random - Rng.p_random) * 1024
      th = Thinker.spawn_mobj(world, x, y, z, Info::MT_PUFF, game)
      th.momz = Defs::FRACUNIT
      th.tics -= Rng.p_random & 3
      th.tics = 1 if th.tics < 1
      Thinker.set_mobj_state(th, Info::S_PUFF3, world, game) if attackrange == Defs::MELEERANGE
    end

    def spawn_blood(world, x, y, z, game, damage)
      z += (Rng.p_random - Rng.p_random) * 1024
      th = Thinker.spawn_mobj(world, x, y, z, Info::MT_BLOOD, game)
      th.momz = Defs::FRACUNIT * 2
      th.tics -= Rng.p_random & 3
      th.tics = 1 if th.tics < 1
      if damage <= 12 && damage >= 9
        Thinker.set_mobj_state(th, Info::S_BLOOD2, world, game)
      elsif damage < 9
        Thinker.set_mobj_state(th, Info::S_BLOOD3, world, game)
      end
    end

    def intercept_frac(x1, y1, x2, y2, line)
      ax = x1.to_f / Defs::FRACUNIT
      ay = y1.to_f / Defs::FRACUNIT
      bx = x2.to_f / Defs::FRACUNIT
      by = y2.to_f / Defs::FRACUNIT
      cx = line.v1.x.to_f / Defs::FRACUNIT
      cy = line.v1.y.to_f / Defs::FRACUNIT
      dx = line.v2.x.to_f / Defs::FRACUNIT
      dy = line.v2.y.to_f / Defs::FRACUNIT
      den = (bx - ax) * (dy - cy) - (by - ay) * (dx - cx)
      return nil if den.abs < 1e-8

      t = ((cx - ax) * (dy - cy) - (cy - ay) * (dx - cx)) / den
      u = ((cx - ax) * (by - ay) - (cy - ay) * (bx - ax)) / den
      return nil if t.negative? || t > 1.0 || u.negative? || u > 1.0

      (t * Defs::FRACUNIT).to_i
    end

    def check_sight(world, t1, t2)
      s1 = world.point_in_subsector(t1.x, t1.y).sector
      s2 = world.point_in_subsector(t2.x, t2.y).sector
      nsec = world.sectors.length
      rej = world.rejectmatrix
      if nsec.positive? && rej && !rej.empty?
        pnum = s1.i_sector * nsec + s2.i_sector
        bytenum = pnum >> 3
        bitnum = 1 << (pnum & 7)
        return false if bytenum < rej.bytesize && (rej.getbyte(bytenum) & bitnum) != 0
      end
      return true if s1.equal?(s2)

      world.lines.each do |ln|
        if ln.backsector
          opentop, openbottom, = line_opening(ln)
          next if (opentop - openbottom).positive?
        end
        frac = intercept_frac(t1.x, t1.y, t2.x, t2.y, ln)
        return false if frac && Defs::FRACUNIT / 64 < frac && frac < Defs::FRACUNIT - Defs::FRACUNIT / 64
      end
      true
    end

    def approx_distance(dx, dy)
      dx = dx.abs
      dy = dy.abs
      dx, dy = dy, dx if dx < dy
      dx + dy / 2
    end

    def angle_to(x1, y1, x2, y2)
      Tables.init_tables
      x = Compat.as_i32(x2 - x1)
      y = Compat.as_i32(y2 - y1)
      return 0 if x.zero? && y.zero?

      if x >= 0
        if y >= 0
          return Tables.tantoangle[slope_div(y, x)] if x > y

          return Compat.as_u32(Defs::ANG90 - 1 - Tables.tantoangle[slope_div(x, y)])
        end
        y = -y
        return Compat.as_u32(-Tables.tantoangle[slope_div(y, x)]) if x > y

        return Compat.as_u32(0xC0000000 + Tables.tantoangle[slope_div(x, y)])
      end
      x = -x
      if y >= 0
        return Compat.as_u32(Defs::ANG180 - 1 - Tables.tantoangle[slope_div(y, x)]) if x > y

        return Compat.as_u32(Defs::ANG90 + Tables.tantoangle[slope_div(x, y)])
      end
      y = -y
      return Compat.as_u32(Defs::ANG180 + Tables.tantoangle[slope_div(y, x)]) if x > y

      Compat.as_u32(0xC0000000 - 1 - Tables.tantoangle[slope_div(x, y)])
    end

    def slope_div(num, den)
      Tables.slope_div(num, den)
    end
  end
end
