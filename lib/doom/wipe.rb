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
# A tela antiga escorre e a nova aparece por cima.

module Doom
  class Wipe
    COLW = Defs::SCREENWIDTH / 2

    attr_reader :active

    def initialize
      @start = VVideo.blank
      @ending = VVideo.blank
      @y = []
      @active = false
    end

    def capture_start(fb)
      @start = fb.dup
    end

    def capture_end(fb)
      @ending = fb.dup
    end

    def begin_wipe(fb)
      fb.replace(@start)
      @y = Array.new(COLW, 0)
      @y[0] = -rand(16)
      (1...COLW).each do |i|
        ny = @y[i - 1] + (rand(3) - 1)
        ny = 0 if ny.positive?
        ny = -15 if ny == -16
        @y[i] = ny
      end
      @active = true
    end

    def tick(tics, fb)
      height = Defs::SCREENHEIGHT
      width = Defs::SCREENWIDTH
      done = true
      [1, tics].max.times do
        COLW.times do |i|
          yi = @y[i]
          x0 = i * 2
          if yi.negative?
            copy_column(@start, fb, x0, 0, height, 0)
            @y[i] = yi + 1
            done = false
            next
          end
          next if yi >= height

          dy = yi < 16 ? yi + 1 : 8
          dy = height - yi if yi + dy > height
          copy_column(@ending, fb, x0, yi, dy, yi)
          yi += dy
          @y[i] = yi
          remain = height - yi
          copy_column(@start, fb, x0, 0, remain, yi) if remain.positive?
          done = false
        end
      end
      if done
        fb.replace(@ending)
        @active = false
      end
      width
      done
    end

    private

    def copy_column(src, dest, x, src_y, rows, dest_y)
      return if rows <= 0

      width = Defs::SCREENWIDTH
      rows.times do |row|
        from = ((src_y + row) * width) + x
        to = ((dest_y + row) * width) + x
        dest.setbyte(to, src.getbyte(from))
        dest.setbyte(to + 1, src.getbyte(from + 1))
      end
    end
  end
end
