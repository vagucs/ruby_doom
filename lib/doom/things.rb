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
# Coisas do mapa. O estado nasce em thinker.rb e o combate anda em enemy.rb.

module Doom
  module Things
    module_function

    def spawn_map_things(world, skill = Defs::SK_MEDIUM, game = nil)
      bit = if skill <= Defs::SK_EASY
              1
            elsif skill == Defs::SK_NIGHTMARE || skill >= Defs::SK_HARD
              4
            else
              2
            end
      kills = 0
      items = 0
      world.things.each do |mt|
        next if mt.type == 11 || mt.type.between?(1, 4)
        next if (mt.options & bit).zero? || (mt.options & 16) != 0

        typ = Info.mobj_type_for_doomednum(mt.type)
        next if typ.negative?

        flags = Info::MOBJINFO[typ][Info::MI_FLAGS]
        next if game&.nomonsters && ((flags & Defs::MF_COUNTKILL) != 0 || typ == Info::MT_SKULL)

        z = (flags & Defs::MF_SPAWNCEILING) != 0 ? Thinker::ONCEILINGZ : Thinker::ONFLOORZ
        mo = Thinker.spawn_mobj(world, mt.x * Defs::FRACUNIT, mt.y * Defs::FRACUNIT, z, typ, game)
        mo.tics = 1 + (Rng.p_random % mo.tics) if mo.tics.positive?
        mo.angle = Compat.as_u32((mt.angle / 45) * 0x20000000)
        mo.spawnpoint = mt
        mo.flags |= Defs::MF_AMBUSH if (mt.options & Defs::MTF_AMBUSH) != 0
        mo.info = Items.lookup(mt.type)
        kills += 1 if (mo.flags & Defs::MF_COUNTKILL) != 0
        items += 1 if (mo.flags & Defs::MF_COUNTITEM) != 0
      end
      [kills, items]
    end
  end
end
