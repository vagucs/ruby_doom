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
# Sprites do mapa e a arma na frente da tela.

module Doom
  class SpriteFrame
    attr_accessor :rotate, :lump, :flip

    def initialize
      @rotate = -1
      @lump = [-1] * 8
      @flip = [0] * 8
    end
  end

  module Sprites
    MAX_SPRITE_FRAMES = 29
    MINZ = 4 * Defs::FRACUNIT
    FUZZ_DIR = [
      1, -1, 1, -1, 1, 1, -1, 1, 1, -1, 1, 1, 1, -1, 1, 1, 1, -1, -1, -1, -1, 1, -1, -1, 1,
      1, 1, 1, -1, 1, -1, 1, 1, -1, -1, 1, 1, -1, -1, -1, -1, 1, 1, 1, 1, -1, 1, 1, -1, 1
    ].freeze

    module_function

    def build(wad)
      start = wad.check_num_for_name('S_START')
      finish = wad.check_num_for_name('S_END')
      start = wad.check_num_for_name('SS_START') if start.negative?
      finish = wad.check_num_for_name('SS_END') if finish.negative?
      if start >= 0 && finish > start
        first = start + 1
        last = finish - 1
      else
        first = 0
        last = wad.num_lumps - 1
      end
      buckets = Hash.new { |h, k| h[k] = [] }
      first.upto(last) do |lump|
        name = wad.lump_name(lump)
        next if name.length < 6

        buckets[name.byteslice(0, 4)] << lump
      end
      result = {}
      buckets.each do |sprname, lumps|
        frames = Array.new(MAX_SPRITE_FRAMES) { SpriteFrame.new }
        maxframe = -1
        lumps.each do |lump|
          name = wad.lump_name(lump)
          frame = name.getbyte(4) - 'A'.ord
          rotation = name.getbyte(5) - '0'.ord
          maxframe = frame if install(frames, lump, frame, rotation, false) && frame > maxframe
          next if name.length < 8

          mark = name.getbyte(6)
          next if mark < 'A'.ord || mark > ']'.ord

          frame2 = mark - 'A'.ord
          rotation2 = name.getbyte(7) - '0'.ord
          maxframe = frame2 if install(frames, lump, frame2, rotation2, true) && frame2 > maxframe
        end
        next if maxframe.negative?

        (maxframe + 1).times do |i|
          slot = frames[i]
          next unless slot.rotate == -1

          slot.rotate = 0
        end
        result[sprname] = frames[0..maxframe]
      end
      result
    end

    def install(frames, lump, frame, rotation, flipped)
      return false if frame.negative? || frame >= MAX_SPRITE_FRAMES || rotation.negative? || rotation > 8

      sf = frames[frame]
      if rotation.zero?
        return true if sf.rotate == 1

        sf.rotate = 0
        8.times do |r|
          sf.lump[r] = lump
          sf.flip[r] = flipped ? 1 : 0
        end
        return true
      end
      return true if sf.rotate.zero?

      sf.rotate = 1
      idx = rotation - 1
      if sf.lump[idx].negative?
        sf.lump[idx] = lump
        sf.flip[idx] = flipped ? 1 : 0
      end
      true
    end

    def lookup(res, name, ang_to_thing, moangle, frame)
      base = name.to_s.b.byteslice(0, 4).force_encoding(Encoding::ISO_8859_1).upcase
      sprframes = res.sprites[base]
      return nil if sprframes.nil? || sprframes.empty?

      fi = frame & 0x7FFF
      return nil if fi >= sprframes.length

      sf = sprframes[fi]
      if sf.rotate != 0
        rot = (Compat.as_u32(ang_to_thing - moangle + ((Defs::ANG45 / 2) * 9)) >> 29) & 7
        lump = sf.lump[rot]
        flip = sf.flip[rot]
      else
        lump = sf.lump[0]
        flip = sf.flip[0]
      end
      return nil if lump.nil? || lump.negative?

      [lump, flip]
    end

    def draw(renderer, world, fb)
      vis = []
      world.mobjs.each do |mo|
        next if mo.sprite.nil? || mo.sprite.empty? || mo.player || (mo.flags & Defs::MF_NOSECTOR) != 0

        item = project(renderer, mo)
        vis << item if item
      end
      vis.sort_by! { |spr| spr[:scale] }
      vis.each { |spr| paint(renderer, fb, spr) }
    end

    def project(renderer, mo)
      tr_x = Compat.as_i32(mo.x - renderer.viewx)
      tr_y = Compat.as_i32(mo.y - renderer.viewy)
      gxt = Compat.fixed_mul(tr_x, renderer.viewcos)
      gyt = -Compat.fixed_mul(tr_y, renderer.viewsin)
      tz = gxt - gyt
      return nil if tz < MINZ

      xscale = Compat.fixed_div(renderer.projection, tz)
      gxt = -Compat.fixed_mul(tr_x, renderer.viewsin)
      gyt = Compat.fixed_mul(tr_y, renderer.viewcos)
      tx = -(gyt + gxt)
      return nil if tx.abs > tz * 4

      found = lookup(renderer.res, mo.sprite, renderer.send(:point_to_angle, mo.x, mo.y), mo.angle, mo.frame)
      return nil unless found

      lump, flip = found
      patch = renderer.res.wad.cache_lump_num(lump)
      w, _h, left, top = patch_size(patch)
      tx -= left * Defs::FRACUNIT
      x1 = (renderer.centerxfrac + Compat.fixed_mul(tx, xscale)) >> Defs::FRACBITS
      return nil if x1 > renderer.viewwidth

      tx += w * Defs::FRACUNIT
      x2 = ((renderer.centerxfrac + Compat.fixed_mul(tx, xscale)) >> Defs::FRACBITS) - 1
      return nil if x2.negative?

      iscale = xscale.zero? ? Defs::FRACUNIT : Compat.fixed_div(Defs::FRACUNIT, xscale)
      xiscale = flip != 0 ? -iscale : iscale
      startfrac = flip != 0 ? (w << Defs::FRACBITS) - 1 : 0
      vis_x1 = [x1, 0].max
      vis_x2 = [x2, renderer.viewwidth - 1].min
      startfrac += xiscale * (vis_x1 - x1) if vis_x1 > x1
      {
        mo: mo, patch: patch, w: w, scale: xscale << renderer.detailshift,
        gx: mo.x, gy: mo.y, gz: mo.z, gzt: mo.z + top * Defs::FRACUNIT,
        texturemid: mo.z + top * Defs::FRACUNIT - renderer.viewz,
        x1: vis_x1, x2: vis_x2, xiscale: xiscale, startfrac: startfrac
      }
    end

    def patch_size(patch)
      patch.byteslice(0, 8).unpack('s<s<s<s<')
    end

    def point_on_seg_side(x, y, line)
      lx = line.v1.x
      ly = line.v1.y
      ldx = line.v2.x - lx
      ldy = line.v2.y - ly
      if ldx.zero?
        return ldy.positive? ? 1 : 0 if x <= lx

        return ldy.negative? ? 1 : 0
      end
      if ldy.zero?
        return ldx.negative? ? 1 : 0 if y <= ly

        return ldx.positive? ? 1 : 0
      end
      dx = x - lx
      dy = y - ly
      left = Compat.fixed_mul(ldy >> Defs::FRACBITS, dx)
      right = Compat.fixed_mul(dy, ldx >> Defs::FRACBITS)
      right < left ? 0 : 1
    end

    def clip_against_walls(renderer, spr)
      x1 = spr[:x1]
      x2 = spr[:x2]
      clipbot = [-2] * Defs::SCREENWIDTH
      cliptop = [-2] * Defs::SCREENWIDTH
      renderer.drawsegs.reverse_each do |ds|
        next if ds.x1 > x2 || ds.x2 < x1
        next if ds.silhouette.zero? && (ds.maskedtexturecol.nil? || ds.maskedtexturecol.empty?)

        r1 = [ds.x1, x1].max
        r2 = [ds.x2, x2].min
        scale = [ds.scale1, ds.scale2].max
        lowscale = [ds.scale1, ds.scale2].min
        in_front = scale < spr[:scale] || (
          lowscale < spr[:scale] && ds.curline && point_on_seg_side(spr[:gx], spr[:gy], ds.curline).zero?
        )
        if in_front
          renderer.send(:render_masked_seg_range, ds, r1, r2) if ds.maskedtexturecol && !ds.maskedtexturecol.empty?
          next
        end
        silhouette = ds.silhouette
        silhouette &= ~Defs::SIL_BOTTOM if spr[:gz] >= ds.bsilheight
        silhouette &= ~Defs::SIL_TOP if spr[:gzt] <= ds.tsilheight
        r1.upto(r2) do |x|
          i = x - ds.x1
          next if i.negative? || i >= ds.sprtopclip.length

          clipbot[x] = ds.sprbottomclip[i] if (silhouette & Defs::SIL_BOTTOM) != 0 && clipbot[x] == -2
          cliptop[x] = ds.sprtopclip[i] if (silhouette & Defs::SIL_TOP) != 0 && cliptop[x] == -2
        end
      end
      viewh = renderer.viewheight
      x1.upto(x2) do |x|
        clipbot[x] = viewh if clipbot[x] == -2
        cliptop[x] = -1 if cliptop[x] == -2
      end
      [cliptop, clipbot]
    end

    def paint(renderer, fb, spr, clip_walls: true)
      patch = spr[:patch]
      patch_w = spr[:w]
      iscale = spr[:xiscale]
      spryscale = spr[:scale]
      y_iscale = iscale.abs >> renderer.detailshift
      y_iscale = 1 if y_iscale < 1
      sprtopscreen = renderer.centeryfrac - Compat.fixed_mul(spr[:texturemid], spryscale)
      if clip_walls
        cliptop, clipbot = clip_against_walls(renderer, spr)
      else
        cliptop = [-1] * Defs::SCREENWIDTH
        clipbot = [renderer.viewheight] * Defs::SCREENWIDTH
      end
      return if patch.bytesize < 8 + patch_w * 4

      colofs = patch.byteslice(8, patch_w * 4).unpack("L<#{patch_w}")
      mo = spr[:mo]
      fuzz = mo && (mo.flags & Defs::MF_SHADOW) != 0
      cm = fuzz ? renderer.res.colormap(6) : (renderer.fixedcolormap || renderer.res.colormap(0))
      frac = spr[:startfrac]
      spr[:x1].upto(spr[:x2]) do |x|
        col = frac >> Defs::FRACBITS
        if col >= 0 && col < patch_w
          column = colofs[col]
          while column < patch.bytesize
            topdelta = patch.getbyte(column)
            break if topdelta.nil? || topdelta == 0xFF

            length = patch.getbyte(column + 1).to_i
            source = column + 3
            topscreen = sprtopscreen + spryscale * topdelta
            bottomscreen = topscreen + spryscale * length
            yl = (topscreen + Defs::FRACUNIT - 1) >> Defs::FRACBITS
            yh = (bottomscreen - 1) >> Defs::FRACBITS
            yl = cliptop[x] + 1 if yl <= cliptop[x]
            yh = clipbot[x] - 1 if yh >= clipbot[x]
            yl = 0 if yl.negative?
            yh = renderer.viewheight - 1 if yh >= renderer.viewheight
            if fuzz
              yl = 1 if yl <= 0
              yh = renderer.viewheight - 2 if yh >= renderer.viewheight - 1
            end
            if yl <= yh
              texfrac = Compat.fixed_mul((yl << Defs::FRACBITS) - topscreen, y_iscale)
              texfrac = 0 if texfrac.negative?
              yl.upto(yh) do |y|
                if fuzz
                  fuzz_pixel(renderer, fb, x, y, cm)
                else
                  idx = texfrac >> Defs::FRACBITS
                  if idx >= 0 && idx < length
                    pix = patch.getbyte(source + idx).to_i
                    val = pix < cm.bytesize ? cm.getbyte(pix) : pix
                    plot(renderer, fb, x, y, val)
                  end
                end
                texfrac += y_iscale
              end
            end
            column += length + 4
          end
        end
        frac += iscale
      end
    end

    def plot(renderer, fb, x, y, val)
      xx = renderer.detailshift != 0 ? x << 1 : x
      off = renderer.ylookup[y] + renderer.columnofs[xx]
      return if off.negative? || off >= fb.bytesize

      fb.setbyte(off, val)
      fb.setbyte(off + 1, val) if renderer.detailshift != 0 && off + 1 < fb.bytesize
    end

    def fuzz_pixel(renderer, fb, x, y, cm)
      @fuzzpos = 0 if @fuzzpos.nil?
      xx = renderer.detailshift != 0 ? x << 1 : x
      dest = renderer.ylookup[y] + renderer.columnofs[xx]
      src = dest + FUZZ_DIR[@fuzzpos] * Defs::SCREENWIDTH
      @fuzzpos = (@fuzzpos + 1) % FUZZ_DIR.length
      src = dest if src.negative? || src >= fb.bytesize
      pix = fb.getbyte(src).to_i
      val = pix < cm.bytesize ? cm.getbyte(pix) : pix
      plot(renderer, fb, x, y, val)
    end

    def draw_weapon(renderer, player, fb, leveltime)
      return if player.nil? || player.mo.nil?

      sx, sy = weapon_xy(player, leveltime)
      draw_psprite(renderer, fb, Actors.weapon_patch(player), sx, sy)
      draw_psprite(renderer, fb, player.psprite_flash, sx, sy)
    end

    def weapon_xy(player, leveltime)
      state = player.psprite_state
      return [Defs::FRACUNIT, player.psprite_sy] if state == 'up' || state == 'down'
      return [Defs::FRACUNIT, player.psprite_sy.zero? ? Actors::WEAPONTOP : player.psprite_sy] if state == 'atk'

      bob = player.bob
      angle = (128 * leveltime) & Defs::FINEMASK
      sx = Defs::FRACUNIT + Compat.fixed_mul(bob, Tables.finesine[(angle + Defs::FINEANGLES / 4) % Tables.finesine.length])
      angle &= Defs::FINEANGLES / 2 - 1
      sy = Actors::WEAPONTOP + Compat.fixed_mul(bob, Tables.finesine[angle])
      player.psprite_sy = sy
      [sx, sy]
    end

    def draw_psprite(renderer, fb, name, sx, sy)
      return if name.nil? || name.length < 5

      frame = name.getbyte(4) - 'A'.ord
      found = lookup(renderer.res, name.byteslice(0, 4), 0, 0, frame)
      return unless found

      lump, = found
      patch = renderer.res.wad.cache_lump_num(lump)
      w, _h, left, top = patch_size(patch)
      scale = renderer.pspritescale
      iscale = renderer.pspriteiscale
      tx = sx - 160 * Defs::FRACUNIT
      tx -= left * Defs::FRACUNIT
      x1 = (renderer.centerxfrac + Compat.fixed_mul(tx, scale)) >> Defs::FRACBITS
      return if x1 > renderer.viewwidth

      tx += w * Defs::FRACUNIT
      x2 = ((renderer.centerxfrac + Compat.fixed_mul(tx, scale)) >> Defs::FRACBITS) - 1
      return if x2.negative?

      vis_x1 = [x1, 0].max
      vis_x2 = [x2, renderer.viewwidth - 1].min
      startfrac = 0
      startfrac += iscale * (vis_x1 - x1) if vis_x1 > x1
      texturemid = 100 * Defs::FRACUNIT + Defs::FRACUNIT / 2 - (sy - top * Defs::FRACUNIT)
      paint(
        renderer, fb,
        {
          patch: patch, w: w, scale: scale << renderer.detailshift, texturemid: texturemid,
          x1: vis_x1, x2: vis_x2, xiscale: iscale, startfrac: startfrac, mo: nil
        },
        clip_walls: false
      )
    end
  end
end
