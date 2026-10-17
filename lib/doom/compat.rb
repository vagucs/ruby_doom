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
# Estouro de 32 bits e ponto fixo 16.16, iguais a doom/compat.py.
# O inteiro do Ruby cresce sozinho. O >> preenche com o sinal, como no Python.

module Doom
  module Compat
    MASK32 = 0xFFFFFFFF

    module_function

    def as_u32(n)
      n & MASK32
    end

    def as_i32(n)
      n &= MASK32
      n -= 0x100000000 if n >= 0x80000000
      n
    end

    def ushr(n, bits)
      n &= MASK32
      return n if bits <= 0
      return 0 if bits >= 32

      n >> bits
    end

    def shar(n, bits)
      n = as_i32(n)
      return n if bits <= 0
      return n.negative? ? -1 : 0 if bits >= 31

      n >> bits
    end

    def fixed_mul(a, b)
      as_i32((as_i32(a) * as_i32(b)) >> Defs::FRACBITS)
    end

    def fixed_div(a, b)
      a = as_i32(a)
      b = as_i32(b)
      if b.zero?
        return a >= 0 ? 0x7FFFFFFF : as_i32(-0x80000000)
      end

      abs_a = a.negative? ? -a : a
      abs_b = b.negative? ? -b : b
      if (abs_a >> 14) >= abs_b
        return (a ^ b).negative? ? as_i32(-0x80000000) : 0x7FFFFFFF
      end

      as_i32((a << 16) / b)
    end

    def abs_fixed(n)
      n = as_i32(n)
      n.negative? ? -n : n
    end
  end
end
