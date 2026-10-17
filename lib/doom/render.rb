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
# Renderer: BSP, paredes, pisos, tetos e ceu. A conta segue doom/render.py.

module Doom
  HEIGHTBITS = 12
  HEIGHTUNIT = 1 << HEIGHTBITS
  ANGLETOSKYSHIFT = 22
  SHRT_MAX = 0x7FFF
  INT_MAX = 0x7FFFFFFF
  INT_MIN = -0x7FFFFFFF

  class ClipRange
    attr_accessor :first, :last

    def initialize(first = 0, last = 0)
      @first = first
      @last = last
    end
  end

  class Visplane
    attr_accessor :height, :picnum, :lightlevel, :minx, :maxx, :top, :bottom

    def initialize(height, picnum, lightlevel, minx, maxx)
      @height = height
      @picnum = picnum
      @lightlevel = lightlevel
      @minx = minx
      @maxx = maxx
      @top = [0xFF] * Defs::SCREENWIDTH
      @bottom = [0] * Defs::SCREENWIDTH
    end
  end

  class DrawSeg
    attr_accessor :x1, :x2, :scale1, :scale2, :silhouette, :sprtopclip, :sprbottomclip,
                  :bsilheight, :tsilheight, :curline, :scalestep, :maskedtexturecol

    def initialize
      @x1 = @x2 = @scale1 = @scale2 = @silhouette = 0
      @bsilheight = @tsilheight = @scalestep = 0
      @sprtopclip = []
      @sprbottomclip = []
      @curline = nil
      @maskedtexturecol = nil
    end
  end

  class Renderer
    attr_reader :res, :viewx, :viewy, :viewz, :viewangle, :viewcos, :viewsin,
                :projection, :centerxfrac, :centeryfrac, :viewwidth, :viewheight,
                :viewwindowx, :viewwindowy, :scaledviewwidth,
                :ylookup, :columnofs, :detailshift, :drawsegs, :fixedcolormap,
                :pspritescale, :pspriteiscale, :extralight

    def initialize(resources)
      Tables.init_tables
      @res = resources
      @detailshift = 0
      @viewangletox = [0] * (Defs::FINEANGLES / 2)
      @xtoviewangle = [0] * (Defs::SCREENWIDTH + 1)
      @yslope = [0] * Defs::SCREENHEIGHT
      @distscale = [0] * Defs::SCREENWIDTH
      @scalelight = Array.new(Defs::LIGHTLEVELS) { [0] * Defs::MAXLIGHTSCALE }
      @zlight = Array.new(Defs::LIGHTLEVELS) { [0] * Defs::MAXLIGHTZ }
      @walllights = [0] * Defs::MAXLIGHTSCALE
      @solidsegs = Array.new(64) { ClipRange.new }
      @newend = 0
      @visplanes = []
      @drawsegs = []
      @viewx = @viewy = @viewz = @viewangle = 0
      @viewsin = @viewcos = 0
      @extralight = 0
      @fixedcolormap = nil
      @fb = VVideo.blank
      @basexscale = 0
      @baseyscale = 0
      @rw_midtexturemid = @rw_toptexturemid = @rw_bottomtexturemid = 0
      @pixhigh = @pixlow = @pixhighstep = @pixlowstep = 0
      @worldhigh = @worldlow = 0
      set_view_size(10, 0)
    end

    def set_view_size(blocks, detail)
      blocks = blocks.clamp(3, 11)
      @detailshift = detail.to_i.zero? ? 0 : 1
      if blocks == 11
        scaled = Defs::SCREENWIDTH
        viewheight = Defs::SCREENHEIGHT
      else
        scaled = blocks * 32
        viewheight = (blocks * 168 / 10) & ~7
      end
      @scaledviewwidth = scaled
      @viewwidth = scaled >> @detailshift
      @viewheight = viewheight
      @centerx = @viewwidth / 2
      @centery = @viewheight / 2
      @centerxfrac = @centerx << Defs::FRACBITS
      @centeryfrac = @centery << Defs::FRACBITS
      @projection = @centerxfrac
      @pspritescale = Defs::FRACUNIT * @viewwidth / Defs::SCREENWIDTH
      @pspriteiscale = Defs::FRACUNIT * Defs::SCREENWIDTH / [@viewwidth, 1].max
      @viewwindowx = (Defs::SCREENWIDTH - scaled) >> 1
      @viewwindowy = scaled == Defs::SCREENWIDTH ? 0 : (Defs::SCREENHEIGHT - Defs::SBARHEIGHT - viewheight) >> 1
      @ylookup = Array.new(Defs::SCREENHEIGHT) { |i| (i + @viewwindowy) * Defs::SCREENWIDTH }
      @columnofs = Array.new(Defs::SCREENWIDTH) { |i| @viewwindowx + i }
      @ceilingclip = [0] * [@viewwidth, 1].max
      @floorclip = [0] * [@viewwidth, 1].max
      init_mapping
      init_slopes
      init_lights
    end

    def setup_frame(x, y, z, angle, extra_light = 0, fixed_index = 0)
      @viewx = x
      @viewy = y
      @viewz = z
      @viewangle = Compat.as_u32(angle)
      @viewsin = Tables.fine_sin(@viewangle)
      @viewcos = Tables.fine_cos(@viewangle)
      @extralight = extra_light
      @fixedcolormap = fixed_index.zero? ? nil : @res.colormap(fixed_index)
      ang = Compat.ushr(Compat.as_u32(@viewangle - Defs::ANG90), Defs::ANGLETOFINESHIFT) & Defs::FINEMASK
      cx = @centerxfrac.zero? ? 1 : @centerxfrac
      @basexscale = Compat.fixed_div(Tables.finesine[(ang + Defs::FINEANGLES / 4) & Defs::FINEMASK], cx)
      @baseyscale = -Compat.fixed_div(Tables.finesine[ang], cx)
    end

    def render(world, fb)
      @fb = fb
      @visplanes = []
      @drawsegs = []
      clear_clip
      if world.nodes.empty?
        subsector(world, 0)
      else
        render_bsp_node(world, world.numnodes - 1)
      end
      draw_planes
    end

    def draw_masked
      @drawsegs.reverse_each do |ds|
        render_masked_seg_range(ds, ds.x1, ds.x2) if ds.maskedtexturecol && !ds.maskedtexturecol.empty?
      end
    end

    private

    def tex?(n)
      !n.nil? && !n.zero?
    end

    def init_mapping
      focallength = Compat.fixed_div(
        @centerxfrac,
        Tables.finetangent[Defs::FINEANGLES / 4 + Defs::FIELDOFVIEW / 2]
      )
      half = Defs::FINEANGLES / 2
      half.times do |i|
        ft = Tables.finetangent[i]
        t = if ft > Defs::FRACUNIT * 2
              -1
            elsif ft < -Defs::FRACUNIT * 2
              @viewwidth + 1
            else
              value = Compat.as_i32(@centerxfrac - Compat.fixed_mul(ft, focallength) + Defs::FRACUNIT - 1) >> Defs::FRACBITS
              value.clamp(-1, @viewwidth + 1)
            end
        @viewangletox[i] = t
      end
      (@viewwidth + 1).times do |x|
        i = 0
        i += 1 while i < half && @viewangletox[i] > x
        @xtoviewangle[x] = Compat.as_u32((i << Defs::ANGLETOFINESHIFT) - Defs::ANG90)
      end
      half.times do |i|
        if @viewangletox[i] == -1
          @viewangletox[i] = 0
        elsif @viewangletox[i] == @viewwidth + 1
          @viewangletox[i] = @viewwidth
        end
      end
      @clipangle = @xtoviewangle[0]
    end

    def init_lights
      Defs::LIGHTLEVELS.times do |i|
        startmap = ((Defs::LIGHTLEVELS - 1 - i) * 2) * Defs::NUMCOLORMAPS / Defs::LIGHTLEVELS
        Defs::MAXLIGHTZ.times do |j|
          scale = Compat.fixed_div((Defs::SCREENWIDTH / 2 * Defs::FRACUNIT), (j + 1) << Defs::LIGHTZSHIFT) >> Defs::LIGHTSCALESHIFT
          level = startmap - scale / 2
          @zlight[i][j] = level.clamp(0, Defs::NUMCOLORMAPS - 1)
        end
        vw = [@viewwidth << @detailshift, 1].max
        Defs::MAXLIGHTSCALE.times do |j|
          level = startmap - (j * Defs::SCREENWIDTH / vw / 2)
          @scalelight[i][j] = level.clamp(0, Defs::NUMCOLORMAPS - 1)
        end
      end
    end

    def init_slopes
      @viewheight.times do |i|
        dy = (((i - @centery) << Defs::FRACBITS) + Defs::FRACUNIT / 2).abs
        dy = 1 if dy < 1
        @yslope[i] = Compat.fixed_div(((@viewwidth << @detailshift) / 2) * Defs::FRACUNIT, dy)
      end
      @viewwidth.times do |i|
        cosadj = Compat.abs_fixed(Tables.fine_cos(@xtoviewangle[i]))
        @distscale[i] = Compat.fixed_div(Defs::FRACUNIT, [cosadj, 1].max)
      end
    end

    def point_to_angle(x, y)
      x = Compat.as_i32(x - @viewx)
      y = Compat.as_i32(y - @viewy)
      return 0 if x.zero? && y.zero?
      if x >= 0
        if y >= 0
          return Tables.tantoangle[Tables.slope_div(y, x)] if x > y

          return Compat.as_u32(Defs::ANG90 - 1 - Tables.tantoangle[Tables.slope_div(x, y)])
        end
        y = -y
        return Compat.as_u32(-Tables.tantoangle[Tables.slope_div(y, x)]) if x > y

        return Compat.as_u32(0xC0000000 + Tables.tantoangle[Tables.slope_div(x, y)])
      end
      x = -x
      if y >= 0
        return Compat.as_u32(Defs::ANG180 - 1 - Tables.tantoangle[Tables.slope_div(y, x)]) if x > y

        return Compat.as_u32(Defs::ANG90 + Tables.tantoangle[Tables.slope_div(x, y)])
      end
      y = -y
      return Compat.as_u32(Defs::ANG180 + Tables.tantoangle[Tables.slope_div(y, x)]) if x > y

      Compat.as_u32(0xC0000000 - 1 - Tables.tantoangle[Tables.slope_div(x, y)])
    end

    def point_on_side(x, y, node)
      dx = Compat.as_i32(x - node.x)
      dy = Compat.as_i32(y - node.y)
      left = Compat.as_i32(node.dy >> 16) * dx
      right = dy * Compat.as_i32(node.dx >> 16)
      right >= left ? 1 : 0
    end

    def scale_from_global_angle(visangle)
      anglea = Compat.as_u32(Defs::ANG90 + Compat.as_u32(visangle - @viewangle))
      angleb = Compat.as_u32(Defs::ANG90 + Compat.as_u32(visangle - @rw_normalangle))
      sinea = Tables.finesine[(anglea >> Defs::ANGLETOFINESHIFT) & Defs::FINEMASK]
      sineb = Tables.finesine[(angleb >> Defs::ANGLETOFINESHIFT) & Defs::FINEMASK]
      num = Compat.fixed_mul(@projection, sineb) << @detailshift
      den = Compat.fixed_mul(@rw_distance, sinea)
      if den > (num >> 16) && !den.zero?
        scale = Compat.fixed_div(num, den)
        scale = 64 * Defs::FRACUNIT if scale > 64 * Defs::FRACUNIT
        scale = 256 if scale < 256
      else
        scale = 64 * Defs::FRACUNIT
      end
      scale
    end

    def clear_clip
      @solidsegs[0].first = -0x7FFFFFFF
      @solidsegs[0].last = -1
      @solidsegs[1].first = @viewwidth
      @solidsegs[1].last = 0x7FFFFFFF
      @newend = 2
      @viewwidth.times do |i|
        @floorclip[i] = @viewheight
        @ceilingclip[i] = -1
      end
    end

    def find_plane(height, picnum, lightlevel)
      if picnum == @res.skyflatnum
        height = 0
        lightlevel = 0
      end
      @visplanes.each do |p|
        return p if p.height == height && p.picnum == picnum && p.lightlevel == lightlevel
      end
      p = Visplane.new(height, picnum, lightlevel, @viewwidth, -1)
      @visplanes << p
      p
    end

    def check_plane(pl, start, stop)
      return find_plane(0, 0, 0) if pl.nil?

      if start < pl.minx
        intrl = pl.minx
        unionl = start
      else
        unionl = pl.minx
        intrl = start
      end
      if stop > pl.maxx
        intrh = pl.maxx
        unionh = stop
      else
        unionh = pl.maxx
        intrh = stop
      end
      x = intrl
      while x <= intrh
        break if x >= 0 && x < Defs::SCREENWIDTH && pl.top[x] != 0xFF

        x += 1
      end
      if x > intrh
        pl.minx = unionl
        pl.maxx = unionh
        return pl
      end
      dup_plane(pl, start, stop)
    end

    def dup_plane(src, start, stop)
      p = Visplane.new(src.height, src.picnum, src.lightlevel, start, stop)
      @visplanes << p
      p
    end

    def render_bsp_node(world, bspnum)
      if (bspnum & Defs::NF_SUBSECTOR) != 0 || bspnum.negative?
        subsector(world, bspnum == -1 ? 0 : (bspnum & ~Defs::NF_SUBSECTOR))
        return
      end
      node = world.nodes[bspnum]
      side = point_on_side(@viewx, @viewy, node)
      render_bsp_node(world, node.children[side])
      render_bsp_node(world, node.children[side ^ 1])
    end

    def subsector(world, num)
      sub = world.subsectors[num]
      @frontsector = sub.sector
      light = (@frontsector.lightlevel >> 4) + @extralight
      light = light.clamp(0, Defs::LIGHTLEVELS - 1)
      @walllights = @scalelight[light]
      @floorplane = find_plane(@frontsector.floorheight, @frontsector.floorpic, @frontsector.lightlevel)
      @ceilingplane = find_plane(@frontsector.ceilingheight, @frontsector.ceilingpic, @frontsector.lightlevel)
      line = sub.firstline
      sub.numlines.times do
        add_line(world.segs[line])
        line += 1
      end
    end

    def add_line(line)
      @curline = line
      angle1 = point_to_angle(line.v1.x, line.v1.y)
      angle2 = point_to_angle(line.v2.x, line.v2.y)
      span = Compat.as_u32(angle1 - angle2)
      return if span >= Defs::ANG180

      @rw_angle1 = angle1
      angle1 = Compat.as_u32(angle1 - @viewangle)
      angle2 = Compat.as_u32(angle2 - @viewangle)
      tspan = Compat.as_u32(angle1 + @clipangle)
      if tspan > Compat.as_u32(2 * @clipangle)
        tspan = Compat.as_u32(tspan - 2 * @clipangle)
        return if tspan >= span

        angle1 = @clipangle
      end
      tspan = Compat.as_u32(@clipangle - angle2)
      if tspan > Compat.as_u32(2 * @clipangle)
        tspan = Compat.as_u32(tspan - 2 * @clipangle)
        return if tspan >= span

        angle2 = Compat.as_u32(-@clipangle)
      end
      mask = Defs::FINEANGLES / 2 - 1
      x1 = @viewangletox[Compat.ushr(Compat.as_u32(angle1 + Defs::ANG90), Defs::ANGLETOFINESHIFT) & mask]
      x2 = @viewangletox[Compat.ushr(Compat.as_u32(angle2 + Defs::ANG90), Defs::ANGLETOFINESHIFT) & mask]
      return if x1 == x2

      @backsector = line.backsector
      if @backsector.nil? || @backsector.ceilingheight <= @frontsector.floorheight || @backsector.floorheight >= @frontsector.ceilingheight
        clip_solid(x1, x2 - 1)
      else
        clip_pass(x1, x2 - 1)
      end
    end

    def clip_solid(first, last)
      return if first > last

      start = 0
      start += 1 while start < @newend && @solidsegs[start].last < first - 1
      if start >= @newend
        store_wall_range(first, last)
        return
      end
      if first < @solidsegs[start].first
        if last < @solidsegs[start].first - 1
          store_wall_range(first, last)
          @solidsegs.insert(start, ClipRange.new(first, last))
          @newend += 1
          @solidsegs << ClipRange.new if @newend > @solidsegs.length
          return
        end
        store_wall_range(first, @solidsegs[start].first - 1)
        @solidsegs[start].first = first
      end
      return if last <= @solidsegs[start].last

      nexti = start
      while nexti + 1 < @newend && last >= @solidsegs[nexti + 1].first - 1
        store_wall_range(@solidsegs[nexti].last + 1, @solidsegs[nexti + 1].first - 1)
        nexti += 1
        if last <= @solidsegs[nexti].last
          @solidsegs[start].last = @solidsegs[nexti].last
          crunch_solid(start, nexti)
          return
        end
      end
      store_wall_range(@solidsegs[nexti].last + 1, last)
      @solidsegs[start].last = last
      crunch_solid(start, nexti)
    end

    def crunch_solid(start, nexti)
      return if nexti == start

      tail = @solidsegs[(nexti + 1)...@newend]
      @solidsegs.slice!(start + 1, @newend - start - 1)
      @solidsegs.insert(start + 1, *tail)
      @newend = start + 1 + tail.length
      @solidsegs << ClipRange.new while @solidsegs.length < 64
    end

    def clip_pass(first, last)
      return if first > last

      start = 0
      start += 1 while start < @newend && @solidsegs[start].last < first - 1
      if start >= @newend
        store_wall_range(first, last)
        return
      end
      if first < @solidsegs[start].first
        if last < @solidsegs[start].first - 1
          store_wall_range(first, last)
          return
        end
        store_wall_range(first, @solidsegs[start].first - 1)
      end
      return if last <= @solidsegs[start].last

      nexti = start
      while nexti + 1 < @newend && last >= @solidsegs[nexti + 1].first - 1
        store_wall_range(@solidsegs[nexti].last + 1, @solidsegs[nexti + 1].first - 1)
        nexti += 1
        return if last <= @solidsegs[nexti].last
      end
      store_wall_range(@solidsegs[nexti].last + 1, last)
    end

    def store_wall_range(start, stop)
      return if start > stop

      line = @curline
      linedef = line.linedef
      sidedef = line.sidedef
      linedef.flags |= Defs::ML_MAPPED
      @rw_normalangle = Compat.as_u32(line.angle + Defs::ANG90)
      offsetangle = Compat.as_u32(@rw_normalangle - @rw_angle1)
      offsetangle = Compat.as_u32(-offsetangle) if offsetangle > Defs::ANG180
      offsetangle = Defs::ANG90 if offsetangle > Defs::ANG90
      distangle = Compat.as_u32(Defs::ANG90 - offsetangle)
      hyp = point_to_dist(line.v1.x, line.v1.y)
      @rw_distance = Compat.fixed_mul(hyp, Tables.finesine[(distangle >> Defs::ANGLETOFINESHIFT) & Defs::FINEMASK])
      @rw_x = start
      @rw_start = start
      @rw_stopx = stop + 1
      @rw_scale = scale_from_global_angle(Compat.as_u32(@viewangle + @xtoviewangle[start]))
      if stop > start
        scale2 = scale_from_global_angle(Compat.as_u32(@viewangle + @xtoviewangle[stop]))
        @rw_scalestep = (scale2 - @rw_scale) / (stop - start)
      else
        @rw_scalestep = 0
      end
      @worldtop = @frontsector.ceilingheight - @viewz
      @worldbottom = @frontsector.floorheight - @viewz
      @midtexture = @toptexture = @bottomtexture = 0
      @maskedtexture = false
      @maskedtexturecol = nil
      if @backsector.nil?
        @midtexture = sidedef.midtexture
        @markfloor = @markceiling = true
        if (linedef.flags & Defs::ML_DONTPEGBOTTOM) != 0
          vtop = @frontsector.floorheight + @res.texture_height(@midtexture)
          @rw_midtexturemid = vtop - @viewz
        else
          @rw_midtexturemid = @worldtop
        end
        @rw_midtexturemid += sidedef.rowoffset
      else
        @worldhigh = @backsector.ceilingheight - @viewz
        @worldlow = @backsector.floorheight - @viewz
        if @frontsector.ceilingpic == @res.skyflatnum && @backsector.ceilingpic == @res.skyflatnum
          @worldtop = @worldhigh
        end
        @markfloor = @worldlow != @worldbottom || @backsector.floorpic != @frontsector.floorpic || @backsector.lightlevel != @frontsector.lightlevel
        @markceiling = @worldhigh != @worldtop || @backsector.ceilingpic != @frontsector.ceilingpic || @backsector.lightlevel != @frontsector.lightlevel
        if @backsector.ceilingheight <= @frontsector.floorheight || @backsector.floorheight >= @frontsector.ceilingheight
          @markceiling = @markfloor = true
        end
        if @worldhigh < @worldtop
          @toptexture = sidedef.toptexture
          if (linedef.flags & Defs::ML_DONTPEGTOP) != 0
            @rw_toptexturemid = @worldtop
          else
            vtop = @backsector.ceilingheight + @res.texture_height(tex?(@toptexture) ? @toptexture : 0)
            @rw_toptexturemid = vtop - @viewz
          end
        end
        if @worldlow > @worldbottom
          @bottomtexture = sidedef.bottomtexture
          @rw_bottomtexturemid = (linedef.flags & Defs::ML_DONTPEGBOTTOM) != 0 ? @worldtop : @worldlow
        end
        @rw_toptexturemid += sidedef.rowoffset
        @rw_bottomtexturemid += sidedef.rowoffset
        if tex?(sidedef.midtexture)
          @maskedtexture = true
          @maskedtexturecol = [SHRT_MAX] * (stop - start + 1)
        end
      end
      @segtextured = tex?(@midtexture) || tex?(@toptexture) || tex?(@bottomtexture) || @maskedtexture
      if @segtextured
        offsetangle = Compat.as_u32(@rw_normalangle - @rw_angle1)
        offsetangle = Compat.as_u32(-offsetangle) if offsetangle > Defs::ANG180
        @rw_offset = Compat.fixed_mul(hyp, Tables.finesine[(offsetangle >> Defs::ANGLETOFINESHIFT) & Defs::FINEMASK])
        @rw_offset = -@rw_offset if Compat.as_u32(@rw_normalangle - @rw_angle1) < Defs::ANG180
        @rw_offset += sidedef.textureoffset + line.offset
        @rw_centerangle = Compat.as_u32(Defs::ANG90 + @viewangle - @rw_normalangle)
      end
      @markfloor = false if @frontsector.floorheight >= @viewz
      if @frontsector.ceilingheight <= @viewz && @frontsector.ceilingpic != @res.skyflatnum
        @markceiling = false
      end
      @ceilingplane = check_plane(@ceilingplane, start, stop) if @markceiling
      @floorplane = check_plane(@floorplane, start, stop) if @markfloor
      @worldtop >>= 4
      @worldbottom >>= 4
      @topstep = -Compat.fixed_mul(@rw_scalestep, @worldtop)
      @topfrac = (@centeryfrac >> 4) - Compat.fixed_mul(@worldtop, @rw_scale)
      @bottomstep = -Compat.fixed_mul(@rw_scalestep, @worldbottom)
      @bottomfrac = (@centeryfrac >> 4) - Compat.fixed_mul(@worldbottom, @rw_scale)
      unless @backsector.nil?
        @worldhigh >>= 4
        @worldlow >>= 4
        if @worldhigh < @worldtop
          @pixhigh = (@centeryfrac >> 4) - Compat.fixed_mul(@worldhigh, @rw_scale)
          @pixhighstep = -Compat.fixed_mul(@rw_scalestep, @worldhigh)
        end
        if @worldlow > @worldbottom
          @pixlow = (@centeryfrac >> 4) - Compat.fixed_mul(@worldlow, @rw_scale)
          @pixlowstep = -Compat.fixed_mul(@rw_scalestep, @worldlow)
        end
      end
      scale1 = @rw_scale
      render_seg_loop
      push_drawseg(start, stop, scale1)
    end

    def push_drawseg(start, stop, scale1)
      ds = DrawSeg.new
      ds.x1 = start
      ds.x2 = stop
      ds.scale1 = scale1
      ds.scale2 = scale1 + @rw_scalestep * [0, stop - start].max
      ds.curline = @curline
      ds.scalestep = @rw_scalestep
      ds.maskedtexturecol = @maskedtexturecol
      if @backsector.nil?
        ds.silhouette = Defs::SIL_BOTH
        ds.bsilheight = INT_MAX
        ds.tsilheight = INT_MIN
        width = stop - start + 1
        ds.sprtopclip = [@viewheight] * width
        ds.sprbottomclip = [-1] * width
      else
        ds.silhouette = Defs::SIL_NONE
        if @frontsector.floorheight > @backsector.floorheight
          ds.silhouette = Defs::SIL_BOTTOM
          ds.bsilheight = @frontsector.floorheight
        elsif @backsector.floorheight > @viewz
          ds.silhouette = Defs::SIL_BOTTOM
          ds.bsilheight = INT_MAX
        end
        if @frontsector.ceilingheight < @backsector.ceilingheight
          ds.silhouette |= Defs::SIL_TOP
          ds.tsilheight = @frontsector.ceilingheight
        elsif @backsector.ceilingheight < @viewz
          ds.silhouette |= Defs::SIL_TOP
          ds.tsilheight = INT_MIN
        end
        if @backsector.ceilingheight <= @frontsector.floorheight
          ds.silhouette |= Defs::SIL_BOTTOM
          ds.bsilheight = INT_MAX
        end
        if @backsector.floorheight >= @frontsector.ceilingheight
          ds.silhouette |= Defs::SIL_TOP
          ds.tsilheight = INT_MIN
        end
        ds.sprtopclip = @ceilingclip[start..stop].dup
        ds.sprbottomclip = @floorclip[start..stop].dup
        if @maskedtexture
          if (ds.silhouette & Defs::SIL_TOP).zero?
            ds.silhouette |= Defs::SIL_TOP
            ds.tsilheight = INT_MIN
          end
          if (ds.silhouette & Defs::SIL_BOTTOM).zero?
            ds.silhouette |= Defs::SIL_BOTTOM
            ds.bsilheight = INT_MAX
          end
        end
      end
      @drawsegs << ds
    end

    def point_to_dist(x, y)
      dx = Compat.abs_fixed(x - @viewx)
      dy = Compat.abs_fixed(y - @viewy)
      dx, dy = dy, dx if dy > dx
      return 0 if dx.zero?

      frac = Compat.fixed_div(dy, dx)
      ang = (Tables.tantoangle[[frac >> Defs::DBITS, 2048].min] + Defs::ANG90) >> Defs::ANGLETOFINESHIFT
      Compat.fixed_div(dx, Tables.finesine[ang & Defs::FINEMASK])
    end

    def render_seg_loop
      texturecolumn = 0
      while @rw_x < @rw_stopx
        yl = Compat.shar(@topfrac + HEIGHTUNIT - 1, HEIGHTBITS)
        yl = @ceilingclip[@rw_x] + 1 if yl < @ceilingclip[@rw_x] + 1
        if @markceiling && @ceilingplane
          top = @ceilingclip[@rw_x] + 1
          bottom = yl - 1
          bottom = @floorclip[@rw_x] - 1 if bottom >= @floorclip[@rw_x]
          if top <= bottom
            @ceilingplane.top[@rw_x] = top
            @ceilingplane.bottom[@rw_x] = bottom
          end
        end
        yh = Compat.shar(@bottomfrac, HEIGHTBITS)
        yh = @floorclip[@rw_x] - 1 if yh >= @floorclip[@rw_x]
        if @markfloor && @floorplane
          top = yh + 1
          bottom = @floorclip[@rw_x] - 1
          top = @ceilingclip[@rw_x] + 1 if top <= @ceilingclip[@rw_x]
          if top <= bottom
            @floorplane.top[@rw_x] = top
            @floorplane.bottom[@rw_x] = bottom
          end
        end
        if @segtextured
          angle = Compat.ushr(Compat.as_u32(@rw_centerangle + @xtoviewangle[@rw_x]), Defs::ANGLETOFINESHIFT)
          tanv = Tables.finetangent[angle & (Defs::FINEANGLES / 2 - 1)]
          texturecolumn = Compat.shar(@rw_offset - Compat.fixed_mul(tanv, @rw_distance), Defs::FRACBITS)
          index = Compat.ushr(@rw_scale, Defs::LIGHTSCALESHIFT)
          index = Defs::MAXLIGHTSCALE - 1 if index >= Defs::MAXLIGHTSCALE
          @dc_colormap = @fixedcolormap || @res.colormap(@walllights[index])
          @dc_x = @rw_x
          @dc_iscale = @rw_scale.zero? ? 0 : 0xFFFFFFFF / @rw_scale
        end
        if tex?(@midtexture)
          @dc_yl = yl
          @dc_yh = yh
          @dc_texturemid = @rw_midtexturemid
          @dc_source = @res.get_column(@midtexture, texturecolumn)
          draw_column
          @ceilingclip[@rw_x] = @viewheight
          @floorclip[@rw_x] = -1
        else
          if tex?(@toptexture)
            mid = Compat.shar(@pixhigh, HEIGHTBITS)
            @pixhigh += @pixhighstep
            mid = @floorclip[@rw_x] - 1 if mid >= @floorclip[@rw_x]
            if mid >= yl
              @dc_yl = yl
              @dc_yh = mid
              @dc_texturemid = @rw_toptexturemid
              @dc_source = @res.get_column(@toptexture, texturecolumn)
              draw_column
              @ceilingclip[@rw_x] = mid
            else
              @ceilingclip[@rw_x] = yl - 1
            end
          elsif @markceiling
            @ceilingclip[@rw_x] = yl - 1
          end
          if tex?(@bottomtexture)
            mid = Compat.shar(@pixlow + HEIGHTUNIT - 1, HEIGHTBITS)
            @pixlow += @pixlowstep
            mid = @ceilingclip[@rw_x] + 1 if mid <= @ceilingclip[@rw_x]
            if mid <= yh
              @dc_yl = mid
              @dc_yh = yh
              @dc_texturemid = @rw_bottomtexturemid
              @dc_source = @res.get_column(@bottomtexture, texturecolumn)
              draw_column
              @floorclip[@rw_x] = mid
            else
              @floorclip[@rw_x] = yh + 1
            end
          elsif @markfloor
            @floorclip[@rw_x] = yh + 1
          end
          if @maskedtexture && @maskedtexturecol
            @maskedtexturecol[@rw_x - @rw_start] = texturecolumn
          end
        end
        @rw_scale += @rw_scalestep
        @topfrac += @topstep
        @bottomfrac += @bottomstep
        @rw_x += 1
      end
    end

    def draw_column
      count = @dc_yh - @dc_yl
      return if count.negative? || @dc_x.negative? || @dc_x >= @viewwidth

      yl = @dc_yl.clamp(0, Defs::SCREENHEIGHT - 1)
      if @detailshift == 1
        x = @dc_x << 1
        return if x.negative? || x + 1 >= Defs::SCREENWIDTH

        dest = @ylookup[yl] + @columnofs[x]
        wide = true
      else
        dest = @ylookup[yl] + @columnofs[@dc_x]
        wide = false
      end
      fracstep = @dc_iscale
      frac = @dc_texturemid + (@dc_yl - @centery) * fracstep
      src = @dc_source
      cm = @dc_colormap
      slen = src.bytesize
      limit = Defs::SCREENWIDTH * Defs::SCREENHEIGHT
      cml = cm.bytesize
      while count >= 0 && dest < limit
        if slen.positive?
          idx = (frac >> Defs::FRACBITS) & 127
          pix = src.getbyte(idx % slen)
          val = pix < cml ? cm.getbyte(pix) : pix
          @fb.setbyte(dest, val)
          @fb.setbyte(dest + 1, val) if wide && dest + 1 < limit
        end
        dest += Defs::SCREENWIDTH
        frac = Compat.as_i32(frac + fracstep)
        count -= 1
      end
    end

    def render_masked_seg_range(ds, x1, x2)
      return if ds.maskedtexturecol.nil? || ds.curline.nil?

      line = ds.curline
      front = line.frontsector
      back = line.backsector
      sidedef = line.sidedef
      texnum = sidedef ? sidedef.midtexture : 0
      return unless tex?(texnum) && back && front

      lightnum = (front.lightlevel >> 4) + @extralight
      lightnum -= 1 if line.v1.y == line.v2.y
      lightnum += 1 if line.v1.x == line.v2.x
      lightnum = lightnum.clamp(0, Defs::LIGHTLEVELS - 1)
      walllights = @scalelight[lightnum]
      if (line.linedef.flags & Defs::ML_DONTPEGBOTTOM) != 0
        dc_texturemid = front.floorheight > back.floorheight ? front.floorheight : back.floorheight
        dc_texturemid = dc_texturemid + @res.texture_height(texnum) - @viewz
      else
        dc_texturemid = front.ceilingheight < back.ceilingheight ? front.ceilingheight : back.ceilingheight
        dc_texturemid -= @viewz
      end
      dc_texturemid += sidedef.rowoffset
      spryscale = ds.scale1 + (x1 - ds.x1) * ds.scalestep
      (x1..x2).each do |dc_x|
        i = dc_x - ds.x1
        if i.negative? || i >= ds.maskedtexturecol.length
          spryscale += ds.scalestep
          next
        end
        tcol = ds.maskedtexturecol[i]
        if tcol != SHRT_MAX
          index = spryscale.positive? ? Compat.ushr(spryscale, Defs::LIGHTSCALESHIFT) : 0
          index = Defs::MAXLIGHTSCALE - 1 if index >= Defs::MAXLIGHTSCALE
          @dc_colormap = @fixedcolormap || @res.colormap(walllights[index])
          @dc_x = dc_x
          @dc_iscale = spryscale.zero? ? 0 : 0xFFFFFFFF / spryscale
          @dc_texturemid = dc_texturemid
          sprtopscreen = @centeryfrac - Compat.fixed_mul(dc_texturemid, spryscale)
          mceil = i < ds.sprtopclip.length ? ds.sprtopclip[i] : -1
          mfloor = i < ds.sprbottomclip.length ? ds.sprbottomclip[i] : @viewheight
          draw_masked_column(@res.column_posts(texnum, tcol), sprtopscreen, spryscale, mceil, mfloor)
          ds.maskedtexturecol[i] = SHRT_MAX
        end
        spryscale += ds.scalestep
      end
    end

    def draw_masked_column(posts, sprtopscreen, spryscale, mceil, mfloor)
      basemid = @dc_texturemid
      posts.each do |topdelta, pixels|
        next if pixels.nil? || pixels.empty?

        topscreen = sprtopscreen + spryscale * topdelta
        bottomscreen = topscreen + spryscale * pixels.bytesize
        yl = (topscreen + Defs::FRACUNIT - 1) >> Defs::FRACBITS
        yh = (bottomscreen - 1) >> Defs::FRACBITS
        yh = mfloor - 1 if yh >= mfloor
        yl = mceil + 1 if yl <= mceil
        yl = 0 if yl.negative?
        yh = @viewheight - 1 if yh >= @viewheight
        next if yl > yh

        src = pixels.bytesize >= 128 ? pixels.byteslice(0, 128) : pixels + ("\0" * (128 - pixels.bytesize)).b
        @dc_yl = yl
        @dc_yh = yh
        @dc_source = src
        @dc_texturemid = basemid - (topdelta << Defs::FRACBITS)
        draw_column
      end
      @dc_texturemid = basemid
    end

    def draw_planes
      @visplanes.each do |pl|
        next if pl.minx > pl.maxx

        if pl.picnum == @res.skyflatnum
          @dc_iscale = 9 * Defs::FRACUNIT / 10
          @dc_colormap = @res.colormap(0)
          @dc_texturemid = 100 * Defs::FRACUNIT
          (pl.minx..pl.maxx).each do |x|
            yl = pl.top[x]
            yh = pl.bottom[x]
            next unless yl <= yh && yl < 0xFF

            ang = Compat.ushr(Compat.as_u32(@viewangle + @xtoviewangle[x]), ANGLETOSKYSHIFT)
            @dc_x = x
            @dc_yl = yl
            @dc_yh = yh
            @dc_source = @res.get_column(@res.skytexture, ang)
            draw_column
          end
          next
        end
        light = ((pl.lightlevel >> 4) + @extralight).clamp(0, Defs::LIGHTLEVELS - 1)
        planezlight = @zlight[light]
        flat = @res.flat_pixels(pl.picnum)
        planeheight = Compat.abs_fixed(pl.height - @viewz)
        next if planeheight.zero?

        x0 = [0, pl.minx].max
        x1 = [@viewwidth - 1, pl.maxx].min
        (x0..x1).each do |x|
          t1 = pl.top[x]
          b1 = pl.bottom[x]
          next if t1 > b1 || t1 == 0xFF

          y1 = [b1, @viewheight - 1].min
          (t1..y1).each do |y|
            distance = Compat.fixed_mul(planeheight, @yslope[y])
            length = Compat.fixed_mul(distance, @distscale[x])
            ang = Compat.ushr(Compat.as_u32(@viewangle + @xtoviewangle[x]), Defs::ANGLETOFINESHIFT) & Defs::FINEMASK
            ds_xfrac = @viewx + Compat.fixed_mul(Tables.finesine[(ang + Defs::FINEANGLES / 4) & Defs::FINEMASK], length)
            ds_yfrac = -@viewy - Compat.fixed_mul(Tables.finesine[ang], length)
            index = Compat.ushr(distance, Defs::LIGHTZSHIFT)
            index = Defs::MAXLIGHTZ - 1 if index > Defs::MAXLIGHTZ - 1
            cm = @fixedcolormap || @res.colormap(planezlight[index])
            spot = ((ds_xfrac >> 16) & 63) | ((ds_yfrac >> 10) & 0x0FC0)
            raw = spot < flat.bytesize ? flat.getbyte(spot) : 0
            pix = raw < cm.bytesize ? cm.getbyte(raw) : raw
            if @detailshift == 1
              xx = x << 1
              off = @ylookup[y] + @columnofs[xx]
              @fb.setbyte(off, pix)
              @fb.setbyte(off + 1, pix)
            else
              @fb.setbyte(@ylookup[y] + @columnofs[x], pix)
            end
          end
        end
      end
    end
  end
end
