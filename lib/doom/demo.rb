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
# Gravacao e leitura de demo .lmp.

module Doom
  class Demo
    MARKER = 0x80

    attr_reader :data, :pos

    def initialize(data)
      @data = data.b
      @pos = 0
    end

    def self.load_bytes(wad, name)
      [name, "#{name}.lmp"].each do |path|
        return File.binread(path) if File.file?(path)
      end
      return nil if wad.check_num_for_name(name).negative?

      wad.cache_lump_name(name)
    rescue SystemCallError
      nil
    end

    def self.begin_record(skill, episode, mapn, respawn, fast, nomonsters)
      buf = String.new(encoding: 'BINARY')
      [109, skill & 0xFF, episode & 0xFF, mapn & 0xFF, 0, respawn ? 1 : 0, fast ? 1 : 0, nomonsters ? 1 : 0, 0].each do |byte|
        buf << byte.chr
      end
      buf << "\x01\x00\x00\x00".b
      new(buf)
    end

    def header
      version = get
      @pos = 0 if version <= 4
      skill = get
      episode = get
      mapn = get
      @pos += 9
      [skill, episode, mapn]
    end

    def read_cmd
      return nil if @pos + 4 > @data.bytesize || @data.getbyte(@pos) == MARKER

      cmd = Ticcmd.new
      cmd.forwardmove = sbyte
      cmd.sidemove = sbyte
      turn = get
      cmd.angleturn = turn << 8
      cmd.angleturn -= 65_536 if cmd.angleturn >= 32_768
      cmd.buttons = get
      cmd
    end

    def write_cmd(cmd)
      @data << (cmd.forwardmove & 0xFF).chr
      @data << (cmd.sidemove & 0xFF).chr
      @data << ((cmd.angleturn >> 8) & 0xFF).chr
      @data << (cmd.buttons & 0xFF).chr
      @pos = @data.bytesize
    end

    def finish(name)
      @data << MARKER.chr
      file = name.to_s
      file += '.lmp' unless file.downcase.end_with?('.lmp')
      File.binwrite(file, @data)
      file
    end

    private

    def get
      byte = @data.getbyte(@pos) || 0
      @pos += 1
      byte
    end

    def sbyte
      n = get
      n >= 128 ? n - 256 : n
    end
  end
end
