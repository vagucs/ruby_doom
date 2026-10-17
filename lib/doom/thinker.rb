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
# Nasce a coisa, troca o estado e avanca o quadro.

module Doom
  module Thinker
    ONFLOORZ = -0x80000000
    ONCEILINGZ = 0x7FFFFFFF

    module_function

    def spawn_mobj(world, x, y, z, typ, game = nil)
      info = Info::MOBJINFO[typ]
      sub = world.point_in_subsector(x, y)
      mo = Mobj.new
      mo.x = x
      mo.y = y
      mo.radius = info[Info::MI_RADIUS]
      mo.height = info[Info::MI_HEIGHT]
      mo.floorz = sub.sector.floorheight
      mo.ceilingz = sub.sector.ceilingheight
      mo.flags = info[Info::MI_FLAGS]
      mo.health = info[Info::MI_SPAWNHEALTH]
      mo.type = typ
      mo.doomednum = info[Info::MI_DOOMEDNUM]
      mo.alive = true
      mo.damage = info[Info::MI_DAMAGE]
      mo.reactiontime = info[Info::MI_REACTIONTIME] if game.nil? || game.skill != Defs::SK_NIGHTMARE
      mo.lastlook = Rng.p_random % 4
      if z == ONCEILINGZ || ((info[Info::MI_FLAGS] & Defs::MF_SPAWNCEILING) != 0 && z == ONFLOORZ)
        mo.z = mo.ceilingz - mo.height
      elsif z == ONFLOORZ
        mo.z = mo.floorz
      else
        mo.z = z
      end
      world.mobjs << mo
      Collision.set_thing_position(world, mo)
      state = info[Info::MI_SPAWNSTATE]
      st = Info::STATES[state]
      mo.istate = state
      mo.tics = st[2]
      mo.sprite = Info::SPRNAMES[st[0]]
      mo.frame = st[1]
      mo
    end

    def remove_mobj(world, mo)
      Collision.unset_thing_position(world, mo)
      mo.alive = false
      mo.istate = Info::S_NULL
      mo.flags = 0
      world.mobjs.delete(mo)
    end

    def set_mobj_state(mo, state, world, game)
      safety = 0
      loop do
        if state == Info::S_NULL || mo.nil?
          remove_mobj(world, mo) if mo && world
          return false
        end
        st = Info::STATES[state]
        mo.istate = state
        mo.tics = st[2]
        mo.sprite = Info::SPRNAMES[st[0]]
        mo.frame = st[1]
        act = Info::ACTIONS[st[3]]
        if act && !act.empty?
          Enemy.call_action(act, mo, world, game)
          return false unless mo.alive
        end
        state = st[4]
        return true if mo.tics != 0

        safety += 1
        return true if safety > 100
      end
    end

    def mobj_thinker(world, mo, game)
      if !mo.momx.zero? || !mo.momy.zero? || (mo.flags & Defs::MF_SKULLFLY) != 0
        Enemy.p_xy_movement(world, mo, game)
        return unless mo.alive
      end
      if mo.z != mo.floorz || !mo.momz.zero?
        Enemy.mobj_z(mo, world, game)
        return unless mo.alive
      end
      if mo.tics != -1
        mo.tics -= 1
        set_mobj_state(mo, Info::STATES[mo.istate][4], world, game) unless mo.tics.positive?
        return
      end
      return if (mo.flags & Defs::MF_COUNTKILL).zero?
      return unless game&.respawnmonsters

      mo.movecount += 1
      return if mo.movecount < 12 * Defs::TICRATE
      return if (game.leveltime & 31) != 0
      return if Rng.p_random > 4

      nightmare_respawn(world, mo, game)
    end

    def nightmare_respawn(world, mo, game)
      sp = mo.spawnpoint
      return if sp.nil?

      x = sp.x * Defs::FRACUNIT
      y = sp.y * Defs::FRACUNIT
      return if Collision.check_position(world, mo, x, y).blocked

      spawn_mobj(world, mo.x, mo.y, mo.floorz, Info::MT_TFOG, game)
      game.start_sound('telept')
      floorz = world.point_in_subsector(x, y).sector.floorheight
      spawn_mobj(world, x, y, floorz, Info::MT_TFOG, game)
      game.start_sound('telept')
      info = Info::MOBJINFO[mo.type]
      z = (info[Info::MI_FLAGS] & Defs::MF_SPAWNCEILING) != 0 ? ONCEILINGZ : ONFLOORZ
      spawned = spawn_mobj(world, x, y, z, mo.type, game)
      spawned.spawnpoint = sp
      spawned.angle = Compat.as_u32((sp.angle / 45) * 0x20000000)
      spawned.flags |= Defs::MF_AMBUSH if (sp.options & Defs::MTF_AMBUSH) != 0
      spawned.reactiontime = 18
      spawned.info = mo.info
      remove_mobj(world, mo)
    end

    def apply_fast(game)
      want = !!(game.fastparm || game.skill == Defs::SK_NIGHTMARE)
      game.respawnmonsters = game.skill == Defs::SK_NIGHTMARE || !!game.respawnparm
      return if @fast_on == want

      unless @sarg_tics
        @sarg_tics = (Info::S_SARG_RUN1..Info::S_SARG_PAIN2).map { |i| Info::STATES[i][2] }
        @shot_speed = {
          Info::MT_BRUISERSHOT => Info::MOBJINFO[Info::MT_BRUISERSHOT][Info::MI_SPEED],
          Info::MT_HEADSHOT => Info::MOBJINFO[Info::MT_HEADSHOT][Info::MI_SPEED],
          Info::MT_TROOPSHOT => Info::MOBJINFO[Info::MT_TROOPSHOT][Info::MI_SPEED]
        }
      end
      @fast_on = want
      @sarg_tics.each_with_index do |tics, i|
        Info::STATES[Info::S_SARG_RUN1 + i][2] = want ? [1, tics / 2].max : tics
      end
      fast = 20 * Defs::FRACUNIT
      @shot_speed.each do |mt, speed|
        Info::MOBJINFO[mt][Info::MI_SPEED] = want ? fast : speed
      end
    end
  end
end
