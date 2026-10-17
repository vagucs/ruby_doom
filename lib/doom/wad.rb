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
# Leitor de WAD. O nome do lump tem 8 bytes e nao distingue maiusculas.

module Doom
  Lump = Struct.new(:name, :position, :size, :cache, :wad_path, keyword_init: true)

  class Wad
    def initialize
      @lumps = []
      @index = {}
    end

    def add_file(path)
      path = File.expand_path(path)
      File.open(path, 'rb') do |file|
        header = file.read(12)
        ident = header.byteslice(0, 4)
        raise "nao e um WAD: #{path}" unless ident == 'IWAD' || ident == 'PWAD'

        numlumps, infotableofs = header.byteslice(4, 8).unpack('L<L<')
        file.seek(infotableofs)
        directory = file.read(numlumps * 16)
        start = @lumps.length
        numlumps.times do |i|
          off = i * 16
          pos, size = directory.byteslice(off, 8).unpack('L<L<')
          name = name8(directory.byteslice(off + 8, 8))
          @lumps << Lump.new(name: name, position: pos, size: size, cache: nil, wad_path: path)
        end
        (start...@lumps.length).each { |i| @index[@lumps[i].name] = i }
      end
    end

    def num_lumps
      @lumps.length
    end

    def check_num_for_name(name)
      @index.fetch(name8(name), -1)
    end

    def get_num_for_name(name)
      n = check_num_for_name(name)
      raise "lump nao encontrado: #{name}" if n.negative?

      n
    end

    def lump_length(num)
      @lumps[num].size
    end

    def cache_lump_num(num)
      lump = @lumps[num]
      if lump.cache.nil?
        File.open(lump.wad_path, 'rb') do |file|
          file.seek(lump.position)
          lump.cache = file.read(lump.size).b
        end
      end
      lump.cache
    end

    def cache_lump_name(name)
      cache_lump_num(get_num_for_name(name))
    end

    def lump_name(num)
      @lumps[num].name
    end

    def each_lump
      @lumps.each_with_index { |lump, index| yield index, lump.name }
    end

    private

    def name8(raw)
      raw = raw.b
      cut = raw.index("\0")
      raw = raw.byteslice(0, cut) if cut
      raw.force_encoding(Encoding::ISO_8859_1).rstrip.upcase
    end
  end
end
