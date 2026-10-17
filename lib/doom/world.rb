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
# Carga do mapa: vertices, linhas, lados, setores, segs, nodes e blockmap.

module Doom
  Vertex = Struct.new(:x, :y, keyword_init: true)
  MapThing = Struct.new(:x, :y, :angle, :type, :options, keyword_init: true)

  class Sector
    attr_accessor :floorheight, :ceilingheight, :floorpic, :ceilingpic,
                  :lightlevel, :special, :tag, :lines, :i_sector, :specialdata,
                  :soundtraversed, :soundtarget, :validcount

    def initialize
      @floorheight = @ceilingheight = 0
      @floorpic = @ceilingpic = @lightlevel = @special = @tag = @i_sector = 0
      @lines = []
      @specialdata = nil
      @soundtraversed = 0
      @soundtarget = nil
      @validcount = 0
    end
  end

  class Side
    attr_accessor :textureoffset, :rowoffset, :toptexture, :bottomtexture,
                  :midtexture, :sector

    def initialize
      @textureoffset = @rowoffset = 0
      @toptexture = @bottomtexture = @midtexture = 0
      @sector = nil
    end
  end

  class Line
    attr_accessor :v1, :v2, :dx, :dy, :flags, :special, :tag, :sidenum, :bbox,
                  :frontsector, :backsector, :sides, :i_line, :validcount

    def initialize
      @dx = @dy = @flags = @special = @tag = @i_line = @validcount = 0
      @sidenum = [-1, -1]
      @bbox = [0, 0, 0, 0]
      @sides = []
    end
  end

  class Seg
    attr_accessor :v1, :v2, :offset, :angle, :sidedef, :linedef, :frontsector, :backsector

    def initialize
      @offset = @angle = 0
    end
  end

  class Subsector
    attr_accessor :numlines, :firstline, :sector

    def initialize(numlines, firstline)
      @numlines = numlines
      @firstline = firstline
      @sector = nil
    end
  end

  class Node
    attr_accessor :x, :y, :dx, :dy, :bbox, :children

    def initialize
      @x = @y = @dx = @dy = 0
      @bbox = []
      @children = [0, 0]
    end
  end

  class World
    attr_accessor :vertexes, :sectors, :sides, :lines, :segs, :subsectors, :nodes,
                  :things, :numnodes, :mobjs, :validcount, :rejectmatrix,
                  :blockmap, :blockmaplump, :blocklinks,
                  :bmaporgx, :bmaporgy, :bmapwidth, :bmapheight, :specials, :leveltime

    def initialize
      @vertexes = []
      @sectors = []
      @sides = []
      @lines = []
      @segs = []
      @subsectors = []
      @nodes = []
      @things = []
      @mobjs = []
      @numnodes = 0
      @validcount = 0
      @blockmap = []
      @blockmaplump = []
      @blocklinks = []
      @bmaporgx = @bmaporgy = 0
      @bmapwidth = @bmapheight = 0
      @specials = nil
      @rejectmatrix = ''.b
      @leveltime = 0
    end

    def setup_level(wad, res, episode, mapn)
      lumpname = wad.check_num_for_name(format('MAP%02d', mapn)) >= 0 ? format('MAP%02d', mapn) : "E#{episode}M#{mapn}"
      lumpnum = wad.get_num_for_name(lumpname)
      load_vertexes(wad.cache_lump_num(lumpnum + 4))
      load_sectors(wad.cache_lump_num(lumpnum + 8), res)
      load_sides(wad.cache_lump_num(lumpnum + 3), res)
      load_lines(wad.cache_lump_num(lumpnum + 2))
      load_segs(wad.cache_lump_num(lumpnum + 5))
      load_subsectors(wad.cache_lump_num(lumpnum + 6))
      load_nodes(wad.cache_lump_num(lumpnum + 7))
      load_things(wad.cache_lump_num(lumpnum + 1))
      load_blockmap(wad.cache_lump_num(lumpnum + 10))
      @rejectmatrix = wad.cache_lump_num(lumpnum + 9)
      @numnodes = @nodes.length
      @subsectors.each { |ss| ss.sector = @segs[ss.firstline].frontsector }
    end

    def player_start
      @things.find { |t| t.type == 1 } || @things[0]
    end

    def point_in_subsector(x, y)
      nodenum = @numnodes - 1
      return @subsectors[0] if nodenum.negative?

      while (nodenum & Defs::NF_SUBSECTOR).zero?
        node = @nodes[nodenum]
        nodenum = node.children[point_on_side(x, y, node)]
      end
      @subsectors[nodenum & ~Defs::NF_SUBSECTOR]
    end

    def point_on_side(x, y, node)
      dx = Compat.as_i32(x - node.x)
      dy = Compat.as_i32(y - node.y)
      left = Compat.as_i32(node.dy >> 16) * dx
      right = dy * Compat.as_i32(node.dx >> 16)
      right >= left ? 1 : 0
    end

    private

    def load_vertexes(data)
      n = data.bytesize / Defs::MAPVERTEX_SIZE
      @vertexes = Array.new(n) do |i|
        Vertex.new(x: Bin.i16(data, i * 4) * Defs::FRACUNIT, y: Bin.i16(data, i * 4 + 2) * Defs::FRACUNIT)
      end
    end

    def load_sectors(data, res)
      n = data.bytesize / Defs::MAPSECTOR_SIZE
      @sectors = Array.new(n) do |i|
        o = i * Defs::MAPSECTOR_SIZE
        s = Sector.new
        s.floorheight = Bin.i16(data, o) * Defs::FRACUNIT
        s.ceilingheight = Bin.i16(data, o + 2) * Defs::FRACUNIT
        s.floorpic = res.flat_num_for_name(Bin.name8(data, o + 4))
        s.ceilingpic = res.flat_num_for_name(Bin.name8(data, o + 12))
        s.lightlevel = Bin.i16(data, o + 20)
        s.special = Bin.i16(data, o + 22)
        s.tag = Bin.i16(data, o + 24)
        s.i_sector = i
        s
      end
    end

    def load_sides(data, res)
      n = data.bytesize / Defs::MAPSIDEDEF_SIZE
      @sides = Array.new(n) do |i|
        o = i * Defs::MAPSIDEDEF_SIZE
        sd = Side.new
        sd.textureoffset = Bin.i16(data, o) * Defs::FRACUNIT
        sd.rowoffset = Bin.i16(data, o + 2) * Defs::FRACUNIT
        sd.toptexture = res.texture_num_for_name(Bin.name8(data, o + 4))
        sd.bottomtexture = res.texture_num_for_name(Bin.name8(data, o + 12))
        sd.midtexture = res.texture_num_for_name(Bin.name8(data, o + 20))
        sec = Bin.i16(data, o + 28)
        sd.sector = sec >= 0 && sec < @sectors.length ? @sectors[sec] : @sectors[0]
        sd
      end
    end

    def load_lines(data)
      n = data.bytesize / Defs::MAPLINEDEF_SIZE
      @lines = []
      n.times do |i|
        o = i * Defs::MAPLINEDEF_SIZE
        ln = Line.new
        v1 = Bin.i16(data, o)
        v2 = Bin.i16(data, o + 2)
        ln.v1 = @vertexes[v1]
        ln.v2 = @vertexes[v2]
        ln.dx = ln.v2.x - ln.v1.x
        ln.dy = ln.v2.y - ln.v1.y
        ln.flags = Bin.i16(data, o + 4)
        ln.special = Bin.i16(data, o + 6)
        ln.tag = Bin.i16(data, o + 8)
        s0 = Bin.i16(data, o + 10)
        s1 = Bin.i16(data, o + 12)
        ln.sidenum = [s0, s1]
        ln.frontsector = s0 >= 0 ? @sides[s0].sector : nil
        ln.backsector = s1 >= 0 ? @sides[s1].sector : nil
        ln.sides = [s0 >= 0 ? @sides[s0] : nil, s1 >= 0 ? @sides[s1] : nil]
        if ln.v1.x < ln.v2.x
          ln.bbox[Defs::BOXLEFT] = ln.v1.x
          ln.bbox[Defs::BOXRIGHT] = ln.v2.x
        else
          ln.bbox[Defs::BOXLEFT] = ln.v2.x
          ln.bbox[Defs::BOXRIGHT] = ln.v1.x
        end
        if ln.v1.y < ln.v2.y
          ln.bbox[Defs::BOXBOTTOM] = ln.v1.y
          ln.bbox[Defs::BOXTOP] = ln.v2.y
        else
          ln.bbox[Defs::BOXBOTTOM] = ln.v2.y
          ln.bbox[Defs::BOXTOP] = ln.v1.y
        end
        ln.i_line = i
        ln.frontsector.lines << ln if ln.frontsector
        ln.backsector.lines << ln if ln.backsector && !ln.backsector.equal?(ln.frontsector)
        @lines << ln
      end
    end

    def load_segs(data)
      n = data.bytesize / Defs::MAPSEG_SIZE
      @segs = Array.new(n) do |i|
        o = i * Defs::MAPSEG_SIZE
        sg = Seg.new
        sg.v1 = @vertexes[Bin.i16(data, o)]
        sg.v2 = @vertexes[Bin.i16(data, o + 2)]
        sg.angle = (Bin.i16(data, o + 4) << 16) & 0xFFFFFFFF
        ln = @lines[Bin.i16(data, o + 6)]
        sg.linedef = ln
        side = Bin.i16(data, o + 8)
        sg.offset = Bin.i16(data, o + 10) * Defs::FRACUNIT
        sg.sidedef = ln.sides[side] || ln.sides[0]
        sg.frontsector = sg.sidedef&.sector
        sg.backsector = if (ln.flags & Defs::ML_TWOSIDED) != 0
                          ln.sides[side ^ 1]&.sector
                        end
        sg
      end
    end

    def load_subsectors(data)
      n = data.bytesize / Defs::MAPSUBSECTOR_SIZE
      @subsectors = Array.new(n) do |i|
        o = i * Defs::MAPSUBSECTOR_SIZE
        Subsector.new(Bin.u16(data, o), Bin.u16(data, o + 2))
      end
    end

    def load_nodes(data)
      n = data.bytesize / Defs::MAPNODE_SIZE
      @nodes = Array.new(n) do |i|
        o = i * Defs::MAPNODE_SIZE
        nd = Node.new
        nd.x = Bin.i16(data, o) * Defs::FRACUNIT
        nd.y = Bin.i16(data, o + 2) * Defs::FRACUNIT
        nd.dx = Bin.i16(data, o + 4) * Defs::FRACUNIT
        nd.dy = Bin.i16(data, o + 6) * Defs::FRACUNIT
        p = o + 8
        nd.bbox = Array.new(2) do
          top = Bin.i16(data, p) * Defs::FRACUNIT
          bot = Bin.i16(data, p + 2) * Defs::FRACUNIT
          left = Bin.i16(data, p + 4) * Defs::FRACUNIT
          right = Bin.i16(data, p + 6) * Defs::FRACUNIT
          p += 8
          [top, bot, left, right]
        end
        nd.children = [Bin.u16(data, p), Bin.u16(data, p + 2)]
        nd
      end
    end

    def load_blockmap(data)
      n = data.bytesize / 2
      lump = Array.new(n) { |i| Bin.u16(data, i * 2) }
      @blockmaplump = lump
      @blockmap = []
      @blocklinks = []
      return if n < 4

      @bmaporgx = Bin.i16(data, 0) * Defs::FRACUNIT
      @bmaporgy = Bin.i16(data, 2) * Defs::FRACUNIT
      @bmapwidth = Bin.i16(data, 4)
      @bmapheight = Bin.i16(data, 6)
      count = @bmapwidth * @bmapheight
      @blockmap = lump[4, count] || []
      @blocklinks = Array.new(count)
    end

    def load_things(data)
      n = data.bytesize / Defs::MAPTHING_SIZE
      @things = Array.new(n) do |i|
        o = i * Defs::MAPTHING_SIZE
        MapThing.new(
          x: Bin.i16(data, o),
          y: Bin.i16(data, o + 2),
          angle: Bin.i16(data, o + 4),
          type: Bin.i16(data, o + 6),
          options: Bin.i16(data, o + 8)
        )
      end
    end
  end
end
