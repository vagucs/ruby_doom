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
# Mapa automatico. Tab abre e fecha. As paredes vistas ficam marcadas.

module Doom
  class Automap
    REDS = 256 - (5 * 16)
    REDRANGE = 16
    GREENS = 7 * 16
    GRAYS = 6 * 16
    BROWNS = 4 * 16
    YELLOWS = 256 - 32 + 7
    WHITE = 256 - 47
    WALLCOLORS = REDS
    FDWALLCOLORS = BROWNS
    CDWALLCOLORS = YELLOWS
    THINGCOLORS = GREENS
    GRIDCOLORS = 104
    XHAIRCOLORS = GRAYS
    INITSCALEMTOF = 13_107
    F_PANINC = 4
    M_ZOOMIN = 66_846
    M_ZOOMOUT = 64_250
    MARKS = 10
    INT_MAX = 0x7FFFFFFF
    OC_LEFT = 1
    OC_RIGHT = 2
    OC_BOTTOM = 4
    OC_TOP = 8
    KEY_TAB = 9
    KEY_RIGHT = 1_073_741_903
    KEY_LEFT = 1_073_741_904
    KEY_DOWN = 1_073_741_905
    KEY_UP = 1_073_741_906
    KEY_MINUS = 45
    KEY_EQUALS = 61
    KEY_PLUS = 43
    KEY_KP_MINUS = 1_073_741_910
    KEY_KP_PLUS = 1_073_741_911

    attr_reader :active

    def initialize
      @active = false
      @cheating = 0
      @grid = 0
      @followplayer = 1
      @stopped = true
      @lastlevel = -1
      @lastepisode = -1
      @bigstate = 0
      @amclock = 0
      @f_x = 0
      @f_y = 0
      @f_w = Defs::SCREENWIDTH
      @f_h = Defs::SCREENHEIGHT - Defs::SBARHEIGHT
      @m_x = @m_y = @m_x2 = @m_y2 = 0
      @m_w = @m_h = 0
      @min_x = @min_y = @max_x = @max_y = 0
      @min_scale_mtof = Defs::FRACUNIT
      @max_scale_mtof = Defs::FRACUNIT
      @scale_mtof = INITSCALEMTOF
      @scale_ftom = Defs::FRACUNIT
      @old_m_x = @old_m_y = @old_m_w = @old_m_h = 0
      @f_oldloc_x = INT_MAX
      @f_oldloc_y = 0
      @m_paninc_x = 0
      @m_paninc_y = 0
      @mtof_zoommul = Defs::FRACUNIT
      @ftom_zoommul = Defs::FRACUNIT
      n_r = (8 * Defs::PLAYER_RADIUS) / 7
      q = n_r / 4
      e = n_r / 8
      @player_arrow = [
        [-n_r + e, 0, n_r, 0],
        [n_r, 0, n_r - (n_r / 2), q],
        [n_r, 0, n_r - (n_r / 2), -q],
        [-n_r + e, 0, -n_r - e, q],
        [-n_r + e, 0, -n_r - e, -q],
        [-n_r + (3 * e), 0, -n_r + e, q],
        [-n_r + (3 * e), 0, -n_r + e, -q]
      ]
      half = (-0.5 * Defs::FRACUNIT).to_i
      tip = (0.7 * Defs::FRACUNIT).to_i
      @thin = [
        [half, -tip, Defs::FRACUNIT, 0],
        [Defs::FRACUNIT, 0, half, tip],
        [half, tip, half, -tip]
      ]
      @marknums = Array.new(10)
      @markpoints = Array.new(MARKS) { [-1, -1] }
      @markpointnum = 0
      @fb = nil
      @clip = [0, 0, 0, 0]
    end

    def start(game)
      stop unless @stopped
      @stopped = false
      if @lastlevel != game.mapn || @lastepisode != game.episode
        level_init(game)
        @lastlevel = game.mapn
        @lastepisode = game.episode
      end
      init_variables(game)
      load_pics(game.wad)
      @active = true
    end

    def stop
      @active = false
      @stopped = true
      @m_paninc_x = 0
      @m_paninc_y = 0
      @mtof_zoommul = Defs::FRACUNIT
      @ftom_zoommul = Defs::FRACUNIT
      @bigstate = 0
    end

    def reset_level
      stop if @active
      @lastlevel = -1
      @lastepisode = -1
      @cheating = 0
    end

    def ticker(game)
      return unless @active

      @amclock += 1
      follow_player(game) if @followplayer != 0
      change_window_scale if @ftom_zoommul != Defs::FRACUNIT
      change_window_loc if @m_paninc_x != 0 || @m_paninc_y != 0
    end

    def drawer(fb, game)
      return unless @active

      @fb = fb
      clear_fb(0)
      draw_grid(game) if @grid != 0
      draw_walls(game)
      draw_players(game)
      draw_things(game) if @cheating == 2
      put_dot(@f_w / 2, @f_h / 2, XHAIRCOLORS)
      draw_marks
      @fb = nil
    end

    def cycle_iddt
      @cheating = (@cheating + 1) % 3
    end

    def responder(key, game)
      return false if game.nil? || game.player.nil? || game.world.nil?
      return false unless key.is_a?(Integer)

      unless @active
        return false unless key == KEY_TAB

        start(game)
        return true
      end
      if key == KEY_RIGHT && @followplayer.zero?
        @m_paninc_x = ftom(F_PANINC)
        return true
      end
      if key == KEY_LEFT && @followplayer.zero?
        @m_paninc_x = -ftom(F_PANINC)
        return true
      end
      if key == KEY_UP && @followplayer.zero?
        @m_paninc_y = ftom(F_PANINC)
        return true
      end
      if key == KEY_DOWN && @followplayer.zero?
        @m_paninc_y = -ftom(F_PANINC)
        return true
      end
      if [KEY_MINUS, KEY_KP_MINUS].include?(key)
        @mtof_zoommul = M_ZOOMOUT
        @ftom_zoommul = M_ZOOMIN
        return true
      end
      if [KEY_EQUALS, KEY_KP_PLUS, KEY_PLUS].include?(key)
        @mtof_zoommul = M_ZOOMIN
        @ftom_zoommul = M_ZOOMOUT
        return true
      end
      if key == KEY_TAB
        stop
        return true
      end
      if key == 48
        @bigstate = @bigstate.zero? ? 1 : 0
        if @bigstate != 0
          save_scale
          min_out_window_scale
        else
          restore_scale(game)
        end
        return true
      end
      if key == 102
        @followplayer = @followplayer.zero? ? 1 : 0
        @f_oldloc_x = INT_MAX
        game.player.set_message(@followplayer != 0 ? 'Follow Mode ON' : 'Follow Mode OFF')
        return true
      end
      if key == 103
        @grid = @grid.zero? ? 1 : 0
        game.player.set_message(@grid != 0 ? 'Grid ON' : 'Grid OFF')
        return true
      end
      if key == 109
        game.player.set_message("Marked Spot #{@markpointnum}")
        add_mark
        return true
      end
      if key == 99
        clear_marks
        game.player.set_message('All Marks Cleared')
        return true
      end
      false
    end

    def release_key(key)
      return unless @active

      if [KEY_RIGHT, KEY_LEFT].include?(key) && @followplayer.zero?
        @m_paninc_x = 0
      elsif [KEY_UP, KEY_DOWN].include?(key) && @followplayer.zero?
        @m_paninc_y = 0
      elsif [KEY_MINUS, KEY_KP_MINUS, KEY_EQUALS, KEY_KP_PLUS, KEY_PLUS].include?(key)
        @mtof_zoommul = Defs::FRACUNIT
        @ftom_zoommul = Defs::FRACUNIT
      end
    end

    private

    def ftom(x)
      Compat.fixed_mul(x * Defs::FRACUNIT, @scale_ftom)
    end

    def mtof(x)
      Compat.shar(Compat.fixed_mul(x, @scale_mtof), 16)
    end

    def cxmtof(x)
      @f_x + mtof(x - @m_x)
    end

    def cymtof(y)
      @f_y + (@f_h - mtof(y - @m_y))
    end

    def level_init(game)
      @f_x = 0
      @f_y = 0
      @f_w = Defs::SCREENWIDTH
      @f_h = Defs::SCREENHEIGHT - Defs::SBARHEIGHT
      clear_marks
      find_min_max(game.world)
      @scale_mtof = Compat.fixed_div(@min_scale_mtof, (0.7 * Defs::FRACUNIT).to_i)
      @scale_mtof = @min_scale_mtof if @scale_mtof > @max_scale_mtof
      @scale_ftom = Compat.fixed_div(Defs::FRACUNIT, @scale_mtof)
    end

    def init_variables(game)
      @active = true
      @f_oldloc_x = INT_MAX
      @amclock = 0
      @m_paninc_x = 0
      @m_paninc_y = 0
      @ftom_zoommul = Defs::FRACUNIT
      @mtof_zoommul = Defs::FRACUNIT
      @m_w = ftom(@f_w)
      @m_h = ftom(@f_h)
      mo = game.player.mo
      @m_x = mo.x - (@m_w / 2)
      @m_y = mo.y - (@m_h / 2)
      change_window_loc
      @old_m_x = @m_x
      @old_m_y = @m_y
      @old_m_w = @m_w
      @old_m_h = @m_h
    end

    def load_pics(wad)
      10.times do |i|
        n = wad.check_num_for_name("AMMNUM#{i}")
        @marknums[i] = n >= 0 ? wad.cache_lump_num(n) : nil
      end
    end

    def clear_marks
      @markpoints = Array.new(MARKS) { [-1, -1] }
      @markpointnum = 0
    end

    def add_mark
      @markpoints[@markpointnum] = [@m_x + (@m_w / 2), @m_y + (@m_h / 2)]
      @markpointnum = (@markpointnum + 1) % MARKS
    end

    def find_min_max(world)
      @min_x = INT_MAX
      @min_y = INT_MAX
      @max_x = -INT_MAX
      @max_y = -INT_MAX
      world.vertexes.each do |vertex|
        @min_x = vertex.x if vertex.x < @min_x
        @max_x = vertex.x if vertex.x > @max_x
        @min_y = vertex.y if vertex.y < @min_y
        @max_y = vertex.y if vertex.y > @max_y
      end
      max_w = @max_x - @min_x
      max_h = @max_y - @min_y
      max_w = Defs::FRACUNIT if max_w <= 0
      max_h = Defs::FRACUNIT if max_h <= 0
      a = Compat.fixed_div(@f_w * Defs::FRACUNIT, max_w)
      b = Compat.fixed_div(@f_h * Defs::FRACUNIT, max_h)
      @min_scale_mtof = a < b ? a : b
      @max_scale_mtof = Compat.fixed_div(@f_h * Defs::FRACUNIT, 2 * Defs::PLAYER_RADIUS)
    end

    def activate_new_scale
      @m_x += @m_w / 2
      @m_y += @m_h / 2
      @m_w = ftom(@f_w)
      @m_h = ftom(@f_h)
      @m_x -= @m_w / 2
      @m_y -= @m_h / 2
      @m_x2 = @m_x + @m_w
      @m_y2 = @m_y + @m_h
    end

    def save_scale
      @old_m_x = @m_x
      @old_m_y = @m_y
      @old_m_w = @m_w
      @old_m_h = @m_h
    end

    def restore_scale(game)
      @m_w = @old_m_w
      @m_h = @old_m_h
      if @followplayer.zero?
        @m_x = @old_m_x
        @m_y = @old_m_y
      else
        mo = game.player.mo
        @m_x = mo.x - (@m_w / 2)
        @m_y = mo.y - (@m_h / 2)
      end
      @m_x2 = @m_x + @m_w
      @m_y2 = @m_y + @m_h
      @scale_mtof = Compat.fixed_div(@f_w * Defs::FRACUNIT, @m_w)
      @scale_ftom = Compat.fixed_div(Defs::FRACUNIT, @scale_mtof)
    end

    def min_out_window_scale
      @scale_mtof = @min_scale_mtof
      @scale_ftom = Compat.fixed_div(Defs::FRACUNIT, @scale_mtof)
      activate_new_scale
    end

    def max_out_window_scale
      @scale_mtof = @max_scale_mtof
      @scale_ftom = Compat.fixed_div(Defs::FRACUNIT, @scale_mtof)
      activate_new_scale
    end

    def change_window_scale
      @scale_mtof = Compat.fixed_mul(@scale_mtof, @mtof_zoommul)
      @scale_ftom = Compat.fixed_div(Defs::FRACUNIT, @scale_mtof)
      if @scale_mtof < @min_scale_mtof
        min_out_window_scale
      elsif @scale_mtof > @max_scale_mtof
        max_out_window_scale
      else
        activate_new_scale
      end
    end

    def change_window_loc
      if @m_paninc_x != 0 || @m_paninc_y != 0
        @followplayer = 0
        @f_oldloc_x = INT_MAX
      end
      @m_x += @m_paninc_x
      @m_y += @m_paninc_y
      if @m_x + (@m_w / 2) > @max_x
        @m_x = @max_x - (@m_w / 2)
      elsif @m_x + (@m_w / 2) < @min_x
        @m_x = @min_x - (@m_w / 2)
      end
      if @m_y + (@m_h / 2) > @max_y
        @m_y = @max_y - (@m_h / 2)
      elsif @m_y + (@m_h / 2) < @min_y
        @m_y = @min_y - (@m_h / 2)
      end
      @m_x2 = @m_x + @m_w
      @m_y2 = @m_y + @m_h
    end

    def follow_player(game)
      mo = game.player.mo
      return if @f_oldloc_x == mo.x && @f_oldloc_y == mo.y

      @m_x = ftom(mtof(mo.x)) - (@m_w / 2)
      @m_y = ftom(mtof(mo.y)) - (@m_h / 2)
      @m_x2 = @m_x + @m_w
      @m_y2 = @m_y + @m_h
      @f_oldloc_x = mo.x
      @f_oldloc_y = mo.y
    end

    def clear_fb(color)
      return unless @fb

      row = (color & 0xFF).chr * @f_w
      @fb[0, @f_w * @f_h] = row * @f_h
    end

    def put_dot(xx, yy, color)
      return unless @fb && xx >= 0 && xx < @f_w && yy >= 0 && yy < @f_h

      @fb.setbyte((yy * @f_w) + xx, color & 0xFF)
    end

    def draw_fline(x0, y0, x1, y1, color)
      return unless x0 >= 0 && x0 < @f_w && y0 >= 0 && y0 < @f_h && x1 >= 0 && x1 < @f_w && y1 >= 0 && y1 < @f_h

      dx = x1 - x0
      ax = 2 * dx.abs
      sx = dx.negative? ? -1 : 1
      dy = y1 - y0
      ay = 2 * dy.abs
      sy = dy.negative? ? -1 : 1
      x = x0
      y = y0
      if ax > ay
        d = ay - (ax / 2)
        loop do
          put_dot(x, y, color)
          return if x == x1

          if d >= 0
            y += sy
            d -= ax
          end
          x += sx
          d += ay
        end
      else
        d = ax - (ay / 2)
        loop do
          put_dot(x, y, color)
          return if y == y1

          if d >= 0
            x += sx
            d -= ay
          end
          y += sy
          d += ax
        end
      end
    end

    def trunc_div(num, den)
      return 0 if den.zero?

      (num.to_f / den).to_i
    end

    def outcode(mx, my)
      oc = 0
      oc |= my.negative? ? OC_TOP : OC_BOTTOM if my.negative? || my >= @f_h
      oc |= mx.negative? ? OC_LEFT : OC_RIGHT if mx.negative? || mx >= @f_w
      oc
    end

    def clip_mline(ax, ay, bx, by)
      out1 = ay > @m_y2 ? OC_TOP : (ay < @m_y ? OC_BOTTOM : 0)
      out2 = by > @m_y2 ? OC_TOP : (by < @m_y ? OC_BOTTOM : 0)
      return false if (out1 & out2) != 0

      out1 |= ax < @m_x ? OC_LEFT : (ax > @m_x2 ? OC_RIGHT : 0)
      out2 |= bx < @m_x ? OC_LEFT : (bx > @m_x2 ? OC_RIGHT : 0)
      return false if (out1 & out2) != 0

      fx0 = cxmtof(ax)
      fy0 = cymtof(ay)
      fx1 = cxmtof(bx)
      fy1 = cymtof(by)
      out1 = outcode(fx0, fy0)
      out2 = outcode(fx1, fy1)
      return false if (out1 & out2) != 0

      8.times do
        return store_clip(fx0, fy0, fx1, fy1) if (out1 | out2).zero?

        outside = out1.zero? ? out2 : out1
        if (outside & OC_TOP) != 0
          tmpx = fy0 == fy1 ? fx0 : fx0 + trunc_div((fx1 - fx0) * fy0, fy0 - fy1)
          tmpy = 0
        elsif (outside & OC_BOTTOM) != 0
          tmpx = fy0 == fy1 ? fx0 : fx0 + trunc_div((fx1 - fx0) * (fy0 - @f_h), fy0 - fy1)
          tmpy = @f_h - 1
        elsif (outside & OC_RIGHT) != 0
          tmpy = fx0 == fx1 ? fy0 : fy0 + trunc_div((fy1 - fy0) * (@f_w - 1 - fx0), fx1 - fx0)
          tmpx = @f_w - 1
        else
          tmpy = fx0 == fx1 ? fy0 : fy0 + trunc_div((fy1 - fy0) * -fx0, fx1 - fx0)
          tmpx = 0
        end
        if outside == out1
          fx0 = tmpx
          fy0 = tmpy
          out1 = outcode(fx0, fy0)
        else
          fx1 = tmpx
          fy1 = tmpy
          out2 = outcode(fx1, fy1)
        end
        return false if (out1 & out2) != 0
      end
      false
    end

    def store_clip(fx0, fy0, fx1, fy1)
      @clip = [fx0, fy0, fx1, fy1]
      true
    end

    def draw_mline(ax, ay, bx, by, color)
      return unless clip_mline(ax, ay, bx, by)

      draw_fline(@clip[0], @clip[1], @clip[2], @clip[3], color)
    end

    def draw_grid(game)
      block = 128 * Defs::FRACUNIT
      orgx = game.world.bmaporgx
      orgy = game.world.bmaporgy
      start = @m_x
      rem = (start - orgx) % block
      start += block - rem if rem != 0
      x = start
      while x < @m_x + @m_w
        draw_mline(x, @m_y, x, @m_y + @m_h, GRIDCOLORS)
        x += block
      end
      start = @m_y
      rem = (start - orgy) % block
      start += block - rem if rem != 0
      y = start
      while y < @m_y + @m_h
        draw_mline(@m_x, y, @m_x + @m_w, y, GRIDCOLORS)
        y += block
      end
    end

    def draw_walls(game)
      color = WALLCOLORS
      game.world.lines.each do |line|
        ax = line.v1.x
        ay = line.v1.y
        bx = line.v2.x
        by = line.v2.y
        if @cheating != 0 || (line.flags & Defs::ML_MAPPED) != 0
          next if (line.flags & Defs::ML_DONTDRAW) != 0 && @cheating.zero?
          if line.backsector.nil?
            draw_mline(ax, ay, bx, by, color)
            next
          end
          next if line.frontsector.nil?

          if line.special == 39
            draw_mline(ax, ay, bx, by, WALLCOLORS + (REDRANGE / 2))
          elsif (line.flags & Defs::ML_SECRET) != 0
            draw_mline(ax, ay, bx, by, color)
          elsif line.backsector.floorheight != line.frontsector.floorheight
            draw_mline(ax, ay, bx, by, FDWALLCOLORS)
          elsif line.backsector.ceilingheight != line.frontsector.ceilingheight
            draw_mline(ax, ay, bx, by, CDWALLCOLORS)
          elsif @cheating != 0
            draw_mline(ax, ay, bx, by, GRAYS)
          end
        elsif game.player.powers[Defs::PW_ALLMAP] != 0 && (line.flags & Defs::ML_DONTDRAW).zero?
          draw_mline(ax, ay, bx, by, GRAYS + 3)
        end
      end
    end

    def rotate(x, y, angle)
      n = Compat.ushr(Compat.as_u32(angle), Defs::ANGLETOFINESHIFT)
      Tables.init_tables
      cs = Tables.finesine_at(n + (Defs::FINEANGLES / 4))
      sn = Tables.finesine_at(n)
      [Compat.fixed_mul(x, cs) - Compat.fixed_mul(y, sn), Compat.fixed_mul(x, sn) + Compat.fixed_mul(y, cs)]
    end

    def draw_character(lines, scale, angle, color, x, y)
      lines.each do |ax, ay, bx, by|
        nax = scale.zero? ? ax : Compat.fixed_mul(scale, ax)
        nay = scale.zero? ? ay : Compat.fixed_mul(scale, ay)
        nbx = scale.zero? ? bx : Compat.fixed_mul(scale, bx)
        nby = scale.zero? ? by : Compat.fixed_mul(scale, by)
        if angle != 0
          nax, nay = rotate(nax, nay, angle)
          nbx, nby = rotate(nbx, nby, angle)
        end
        draw_mline(nax + x, nay + y, nbx + x, nby + y, color)
      end
    end

    def draw_players(game)
      mo = game.player.mo
      draw_character(@player_arrow, 0, mo.angle, WHITE, mo.x, mo.y)
    end

    def draw_things(game)
      scale = 16 * Defs::FRACUNIT
      game.world.mobjs.each do |mo|
        draw_character(@thin, scale, mo.angle, THINGCOLORS, mo.x, mo.y)
      end
    end

    def draw_marks
      return unless @fb

      @markpoints.each_with_index do |(mx, my), i|
        next if mx == -1 || @marknums[i].nil?

        fx = cxmtof(mx)
        fy = cymtof(my)
        next unless @f_x <= fx && fx <= @f_w - 5 && @f_y <= fy && fy <= @f_h - 6

        VVideo.draw_patch(@fb, fx, fy, @marknums[i])
      end
    end
  end
end
