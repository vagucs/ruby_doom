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
# Desenho de patch no framebuffer de 320x200, um indice por byte.

module Doom
  module VVideo
    module_function

    def blank
      ("\0" * (Defs::SCREENWIDTH * Defs::SCREENHEIGHT)).b
    end

    def fill(fb, color = 0)
      fb.replace((color.chr * fb.bytesize).b)
    end

    def patch_size(patch)
      patch.unpack('s<s<s<s<')
    end

    def draw_patch(fb, x, y, patch, flipped: false)
      w, _h, left, top = patch_size(patch)
      x -= left
      y -= top
      desttop = y * Defs::SCREENWIDTH + x
      limit = Defs::SCREENWIDTH * Defs::SCREENHEIGHT
      w.times do |col|
        src_col = flipped ? w - 1 - col : col
        column = patch.byteslice(8 + src_col * 4, 4).unpack1('L<')
        while column < patch.bytesize
          topdelta = patch.getbyte(column)
          break if topdelta == 0xFF

          length = patch.getbyte(column + 1)
          source = column + 3
          dest = desttop + topdelta * Defs::SCREENWIDTH
          length.times do
            fb.setbyte(dest, patch.getbyte(source)) if dest >= 0 && dest < limit
            source += 1
            dest += Defs::SCREENWIDTH
          end
          column += length + 4
        end
        desttop += 1
      end
    end
  end
end
