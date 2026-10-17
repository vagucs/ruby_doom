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
# Texturas, flats, colormaps e a tabela de sprites.

module Doom
  TexPatch = Struct.new(:originx, :originy, :patch, keyword_init: true)

  class Texture
    attr_accessor :name, :width, :height, :patches, :widthmask, :composite, :col_lump, :col_ofs

    def initialize(name, width, height)
      @name = name
      @width = width
      @height = height
      @patches = []
      @widthmask = 0
      @composite = nil
      @col_lump = []
      @col_ofs = []
    end
  end

  class Resources
    attr_reader :skytexture, :skyflatnum, :textures, :wad, :sprites

    def initialize(wad)
      @wad = wad
      @textures = []
      @tex_index = {}
      @flats_first = 0
      @flats_last = 0
      @flattranslation = []
      @colormaps = ''.b
      @skytexture = 0
      @skyflatnum = 0
      @sprites = {}
    end

    def init
      init_textures
      init_flats
      @colormaps = @wad.cache_lump_name('COLORMAP')
      @skyflatnum = flat_num_for_name('F_SKY1')
      @skytexture = texture_num_for_name('SKY1')
      @sprites = Sprites.build(@wad)
    end

    def colormap(level)
      level = 0 if level.negative?
      level = 32 if level > 32
      @colormaps.byteslice(level * 256, 256)
    end

    def flat_num_for_name(name)
      i = @wad.check_num_for_name(name)
      return 0 if i.negative?

      i - @flats_first
    end

    def flat_lump(flatnum)
      flatnum = 0 if flatnum.negative?
      n = @flats_last - @flats_first + 1
      flatnum = 0 if flatnum >= n
      @flats_first + @flattranslation[flatnum]
    end

    def texture_num_for_name(name)
      key = name.to_s.dup.force_encoding(Encoding::ISO_8859_1).upcase.rstrip
      key = key.byteslice(0, 8) || ''
      return 0 if key.empty? || key == '-'

      @tex_index.fetch(key, 0)
    end

    def texture_height(texnum)
      @textures[texnum].height * Defs::FRACUNIT
    end

    def column_posts(texnum, col)
      return [] if texnum <= 0 || texnum >= @textures.length

      tex = @textures[texnum]
      col &= tex.widthmask
      lump = tex.col_lump[col]
      posts = []
      if lump >= 0
        patch = @wad.cache_lump_num(lump)
        column = tex.col_ofs[col]
        while column < patch.bytesize
          topdelta = patch.getbyte(column)
          break if topdelta == 0xFF

          length = patch.getbyte(column + 1)
          source = column + 3
          posts << [topdelta, patch.byteslice(source, length)]
          column += length + 4
        end
        return posts
      end
      generate_composite(tex)
      ofs = tex.col_ofs[col]
      colbytes = tex.composite.byteslice(ofs, tex.height)
      posts << [0, colbytes] if colbytes && !colbytes.empty?
      posts
    end

    def get_column(texnum, col)
      tex = @textures[texnum]
      return ("\0" * 128).b if tex.nil? || tex.width <= 0

      col &= tex.widthmask
      lump = tex.col_lump[col]
      if lump >= 0
        pdata = @wad.cache_lump_num(lump)
        return column_to_source(pdata, tex.col_ofs[col])
      end
      generate_composite(tex)
      ofs = tex.col_ofs[col]
      repeat_column(tex.composite.byteslice(ofs, tex.height) || ''.b)
    end

    def flat_pixels(flatnum)
      data = @wad.cache_lump_num(flat_lump(flatnum))
      return data.byteslice(0, 4096) if data.bytesize >= 4096

      data + ("\0" * (4096 - data.bytesize)).b
    end

    private

    def init_flats
      @flats_first = @wad.get_num_for_name('F_START') + 1
      @flats_last = @wad.get_num_for_name('F_END') - 1
      n = @flats_last - @flats_first + 1
      @flattranslation = (0...n).to_a
    end

    def init_textures
      pnames = @wad.cache_lump_name('PNAMES')
      nummappatches = Bin.i32(pnames, 0)
      patchlookup = Array.new(nummappatches) { |i| @wad.check_num_for_name(Bin.name8(pnames, 4 + i * 8)) }
      maptex1 = @wad.cache_lump_name('TEXTURE1')
      numtextures1 = Bin.i32(maptex1, 0)
      maptex2 = ''.b
      numtextures2 = 0
      if @wad.check_num_for_name('TEXTURE2') >= 0
        maptex2 = @wad.cache_lump_name('TEXTURE2')
        numtextures2 = Bin.i32(maptex2, 0)
      end
      (numtextures1 + numtextures2).times do |i|
        if i < numtextures1
          offset = Bin.i32(maptex1, 4 + i * 4)
          src = maptex1
        else
          offset = Bin.i32(maptex2, 4 + (i - numtextures1) * 4)
          src = maptex2
        end
        name = Bin.name8(src, offset)
        width = Bin.i16(src, offset + 12)
        height = Bin.i16(src, offset + 14)
        patchcount = Bin.i16(src, offset + 20)
        tex = Texture.new(name, width, height)
        poff = offset + 22
        patchcount.times do
          ox = Bin.i16(src, poff)
          oy = Bin.i16(src, poff + 2)
          pidx = Bin.i16(src, poff + 4)
          poff += 10
          lump = pidx >= 0 && pidx < patchlookup.length ? patchlookup[pidx] : -1
          tex.patches << TexPatch.new(originx: ox, originy: oy, patch: lump)
        end
        j = 1
        j *= 2 while j * 2 <= width
        tex.widthmask = j - 1
        tex.col_lump = Array.new(width, -1)
        tex.col_ofs = Array.new(width, 0)
        @tex_index[name] = @textures.length
        @textures << tex
      end
      @textures.each { |tex| generate_lookup(tex) }
    end

    def generate_lookup(tex)
      patchcount = Array.new(tex.width, 0)
      tex.patches.each do |mp|
        next if mp.patch.negative?

        pdata = @wad.cache_lump_num(mp.patch)
        pw = Bin.i16(pdata, 0)
        x1 = mp.originx
        x2 = x1 + pw
        x2 = tex.width if x2 > tex.width
        x = x1.negative? ? 0 : x1
        while x < x2
          patchcount[x] += 1
          tex.col_lump[x] = mp.patch
          tex.col_ofs[x] = Bin.u32(pdata, 8 + (x - mp.originx) * 4)
          x += 1
        end
      end
      tex.width.times { |x| tex.col_lump[x] = -1 if patchcount[x] > 1 }
    end

    def generate_composite(tex)
      return if tex.composite

      buf = ("\0" * (tex.width * tex.height)).b
      tex.patches.each do |mp|
        next if mp.patch.negative?

        pdata = @wad.cache_lump_num(mp.patch)
        pw = Bin.i16(pdata, 0)
        x1 = mp.originx
        x2 = [x1 + pw, tex.width].min
        x = [x1, 0].max
        while x < x2
          colofs = Bin.u32(pdata, 8 + (x - mp.originx) * 4)
          draw_column_in_cache(pdata, colofs, buf, x, mp.originy, tex)
          x += 1
        end
      end
      tex.composite = buf
      tex.width.times { |x| tex.col_ofs[x] = x * tex.height if tex.col_lump[x].negative? }
    end

    def draw_column_in_cache(patch, column, cache, x, originy, tex)
      while column < patch.bytesize
        topdelta = patch.getbyte(column)
        break if topdelta == 0xFF

        length = patch.getbyte(column + 1)
        source = column + 3
        pos = originy + topdelta
        count = length
        if pos.negative?
          count += pos
          source -= pos
          pos = 0
        end
        count = tex.height - pos if pos + count > tex.height
        dest = x * tex.height + pos
        i = 0
        while i < count
          cache.setbyte(dest + i, patch.getbyte(source + i))
          i += 1
        end
        column += length + 4
      end
    end

    def column_to_source(patch, column)
      buf = ("\0" * 128).b
      while column < patch.bytesize
        topdelta = patch.getbyte(column)
        break if topdelta == 0xFF

        length = patch.getbyte(column + 1)
        source = column + 3
        length.times do |i|
          y = topdelta + i
          buf.setbyte(y, patch.getbyte(source + i)) if y >= 0 && y < 128
        end
        column += length + 4
      end
      buf
    end

    def repeat_column(colbytes)
      buf = ("\0" * 128).b
      return buf if colbytes.nil? || colbytes.empty?

      128.times { |i| buf.setbyte(i, colbytes.getbyte(i % colbytes.bytesize)) }
      buf
    end
  end
end
