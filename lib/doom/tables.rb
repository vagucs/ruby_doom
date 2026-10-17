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
# finesine, finetangent e tantoangle, geradas na largada.

module Doom
  module Tables
    module_function

    def finesine
      @finesine
    end

    def finetangent
      @finetangent
    end

    def tantoangle
      @tantoangle
    end

    def init_tables
      return if @finesine && !@finesine.empty?

      n = Defs::FINEANGLES / 4 * 5
      @finesine = Array.new(n) do |i|
        a = (i + 0.5) * Math::PI * 2 / Defs::FINEANGLES
        (Defs::FRACUNIT * Math.sin(a)).to_i
      end
      @finetangent = Array.new(Defs::FINEANGLES / 2) do |i|
        a = (i - Defs::FINEANGLES / 4 + 0.5) * Math::PI * 2 / Defs::FINEANGLES
        begin
          v = (Defs::FRACUNIT * Math.tan(a)).to_i
        rescue FloatDomainError, RangeError
          v = a.positive? ? 0x7FFFFFFF : -0x7FFFFFFF
        end
        v = 0x7FFFFFFF if v > 0x7FFFFFFF
        v = -0x7FFFFFFF if v < -0x7FFFFFFF
        v
      end
      @tantoangle = Array.new(Defs::SLOPERANGE + 1) do |i|
        Compat.as_u32((Math.atan(i.to_f / Defs::SLOPERANGE) / (Math::PI * 2) * 0xFFFFFFFF).to_i)
      end
    end

    def finesine_at(index)
      @finesine[index]
    end

    def fine_sin(angle)
      @finesine[(Compat.as_u32(angle) >> Defs::ANGLETOFINESHIFT) & Defs::FINEMASK]
    end

    def fine_cos(angle)
      @finesine[((Compat.as_u32(angle) >> Defs::ANGLETOFINESHIFT) + Defs::FINEANGLES / 4) & Defs::FINEMASK]
    end

    def slope_div(num, den)
      return Defs::SLOPERANGE if den < 512

      ans = (num << 3) / (den >> 8)
      ans > Defs::SLOPERANGE ? Defs::SLOPERANGE : ans
    end
  end
end
