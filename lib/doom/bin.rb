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
# Leitura little-endian dos lumps do mapa.

module Doom
  module Bin
    module_function

    def i16(data, off)
      data.byteslice(off, 2).unpack1('s<')
    end

    def u16(data, off)
      data.byteslice(off, 2).unpack1('S<')
    end

    def i32(data, off)
      data.byteslice(off, 4).unpack1('l<')
    end

    def u32(data, off)
      data.byteslice(off, 4).unpack1('L<')
    end

    def name8(data, off)
      raw = data.byteslice(off, 8).b
      cut = raw.index("\0")
      raw = raw.byteslice(0, cut) if cut
      raw.force_encoding(Encoding::ISO_8859_1).rstrip.upcase
    end
  end
end
