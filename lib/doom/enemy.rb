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
# Armas, dano, visao, perseguicao e chefes.

module Doom
  class Play
    attr_accessor :player, :world, :specials, :res, :wad, :skill, :episode, :mapn,
                  :leveltime, :fastparm, :respawnparm, :respawnmonsters, :nomonsters,
                  :sound, :totalkills, :totalitems, :totalsecret, :iwad_path

    def initialize
      @skill = Defs::SK_MEDIUM
      @episode = 1
      @mapn = 1
      @leveltime = 0
      @fastparm = false
      @respawnparm = false
      @respawnmonsters = false
      @nomonsters = false
    end

    def start_sound(name)
      @sound&.play(name)
    end

    def use_special(line, thing, side)
      return false unless @specials

      @specials.use_special(line, thing, side) ? true : false
    end

    def cross_special(line, side, thing)
      @specials&.cross_special(line, side, thing)
    end

    def shoot_special(line, thing)
      @specials&.shoot_special(line, thing)
    end

    def touch_special(special, toucher)
      Items.touch(self, special, toucher)
    end

    def damage_mobj(target, source, damage, inflictor = nil)
      return unless target.alive && (target.flags & Defs::MF_SHOOTABLE) != 0

      damage >>= 1 if target.player && @skill == Defs::SK_BABY
      src = inflictor || source
      skip_saw = source&.player && source.player.readyweapon == Defs::WP_CHAINSAW
      if src && (target.flags & Defs::MF_NOCLIP).zero? && !skip_saw
        ang = Collision.angle_to(src.x, src.y, target.x, target.y)
        mass = Info::MOBJINFO[target.type][Info::MI_MASS]
        mass = 100 if mass.zero?
        thrust = damage * (Defs::FRACUNIT / 8) * 100 / mass
        if damage < 40 && damage > target.health && target.z - src.z > 64 * Defs::FRACUNIT && (Rng.p_random & 1) != 0
          ang = Compat.as_u32(ang + Defs::ANG180)
          thrust *= 4
        end
        target.momx += Compat.fixed_mul(thrust, Tables.fine_cos(ang))
        target.momy += Compat.fixed_mul(thrust, Tables.fine_sin(ang))
      end
      if target.player
        player = target.player
        return if ((player.cheats & Defs::CF_GODMODE) != 0 || !player.powers[0].zero?) && damage < 1000

        saved = 0
        unless player.armortype.zero?
          saved = damage / (player.armortype == 1 ? 3 : 2)
          if player.armorpoints <= saved
            saved = player.armorpoints
            player.armortype = 0
          end
          player.armorpoints -= saved
        end
        damage -= saved
        player.health -= damage
        target.health = player.health
        player.damagecount += damage
        player.damagecount = 100 if player.damagecount > 100
        player.attacker = source
        if player.health <= 0
          player.health = 0
          target.health = 0
          player.playerstate = Defs::PST_DEAD
          target.alive = false
          target.flags &= ~(Defs::MF_SOLID | Defs::MF_SHOOTABLE)
          start_sound('pldeth')
        else
          start_sound('plpain')
          pain_or_wake(target, source)
        end
        return
      end
      target.health -= damage
      if target.health <= 0
        Enemy.kill_monster(target, self, source)
        return
      end
      pain_or_wake(target, source)
    end

    def pain_or_wake(target, source)
      info = Info::MOBJINFO[target.type]
      if Rng.p_random < info[Info::MI_PAINCHANCE] && (target.flags & Defs::MF_SKULLFLY).zero?
        target.flags |= Defs::MF_JUSTHIT
        Thinker.set_mobj_state(target, info[Info::MI_PAINSTATE], @world, self) unless info[Info::MI_PAINSTATE].zero?
      end
      target.reactiontime = 0
      return if source.nil? || source.equal?(target) || target.player

      target.target = source
      return unless target.istate == info[Info::MI_SPAWNSTATE] && !info[Info::MI_SEESTATE].zero?

      Thinker.set_mobj_state(target, info[Info::MI_SEESTATE], @world, self)
    end
  end

  module Enemy
    DI_EAST = 0
    DI_NORTHEAST = 1
    DI_NORTH = 2
    DI_NORTHWEST = 3
    DI_WEST = 4
    DI_SOUTHWEST = 5
    DI_SOUTH = 6
    DI_SOUTHEAST = 7
    DI_NODIR = 8
    XSPEED = [Defs::FRACUNIT, 47000, 0, -47000, -Defs::FRACUNIT, -47000, 0, 47000].freeze
    YSPEED = [0, 47000, Defs::FRACUNIT, 47000, 0, -47000, -Defs::FRACUNIT, -47000].freeze
    OPPOSITE = [4, 5, 6, 7, 0, 1, 2, 3, 8].freeze
    DIAGS = [DI_NORTHWEST, DI_NORTHEAST, DI_SOUTHWEST, DI_SOUTHEAST].freeze
    TRACEANGLE = 0xC000000
    FATSPREAD = Defs::ANG90 / 8
    MAX_SKULLS = 21
    FLOATSPEED = 4 * Defs::FRACUNIT

    module_function

    def reset_brain
      @brain_targets = []
      @brain_target_on = 0
    end

    def p_random
      Rng.p_random
    end

    def tick(world, game)
      player = game.player
      return if player.nil? || player.mo.nil?

      world.mobjs.dup.each do |mo|
        next if mo.equal?(player.mo)

        Thinker.mobj_thinker(world, mo, game)
      end
    end

    def info_of(mo)
      Info::MOBJINFO[mo.type]
    end

    def kill_monster(mo, game, source)
      info = info_of(mo)
      mo.flags &= ~(Defs::MF_SHOOTABLE | Defs::MF_FLOAT | Defs::MF_SKULLFLY)
      mo.flags |= Defs::MF_CORPSE | Defs::MF_DROPOFF
      mo.height >>= 2
      if source&.player && (mo.flags & Defs::MF_COUNTKILL) != 0
        source.player.killcount += 1
      end
      xds = info[Info::MI_XDEATHSTATE]
      st = !xds.zero? && mo.health < -info[Info::MI_SPAWNHEALTH] ? xds : info[Info::MI_DEATHSTATE]
      Thinker.set_mobj_state(mo, st, game.world, game)
      return unless mo.alive

      mo.tics -= p_random & 3
      mo.tics = 1 if mo.tics < 1
      drop = { Info::MT_POSSESSED => Info::MT_CLIP, Info::MT_SHOTGUY => Info::MT_SHOTGUN, Info::MT_CHAINGUY => Info::MT_CHAINGUN }[mo.type]
      return unless drop

      item = Thinker.spawn_mobj(game.world, mo.x, mo.y, Thinker::ONFLOORZ, drop, game)
      item.flags |= Defs::MF_DROPPED
    end

    def noise_alert(world, emitter, _game = nil)
      return if emitter.nil?

      sec = world.point_in_subsector(emitter.x, emitter.y).sector
      world.validcount += 1
      recursive_sound(world, sec, 0, emitter)
    end

    def recursive_sound(world, sec, soundblocks, target)
      return if sec.validcount == world.validcount && sec.soundtraversed <= soundblocks + 1

      sec.validcount = world.validcount
      sec.soundtraversed = soundblocks + 1
      sec.soundtarget = target
      sec.lines.each do |check|
        next if (check.flags & Defs::ML_TWOSIDED).zero?

        opentop, openbottom, = Collision.line_opening(check)
        next if opentop - openbottom <= 0

        other = check.frontsector.equal?(sec) ? check.backsector : check.frontsector
        next if other.nil?

        if (check.flags & Defs::ML_SOUNDBLOCK) != 0
          recursive_sound(world, other, 1, target) if soundblocks.zero?
        else
          recursive_sound(world, other, soundblocks, target)
        end
      end
    end

    def look(world, mo, player_mo, game)
      mo.threshold = 0
      see = false
      targ = world.point_in_subsector(mo.x, mo.y).sector.soundtarget
      if targ && (targ.flags & Defs::MF_SHOOTABLE) != 0
        mo.target = targ
        see = (mo.flags & Defs::MF_AMBUSH) != 0 ? Collision.check_sight(world, mo, targ) : true
      end
      return unless see || look_for_players(world, mo, player_mo, false)

      mo.movedir = DI_NODIR
      mo.movecount = 0
      play_see_sound(mo, game)
      Thinker.set_mobj_state(mo, info_of(mo)[Info::MI_SEESTATE], world, game)
    end

    def play_see_sound(mo, game)
      sound = info_of(mo)[Info::MI_SEESOUND]
      return if sound.nil? || sound.empty?

      sound = %w[posit1 posit2 posit3][p_random % 3] if sound == 'posit1'
      sound = %w[bgsit1 bgsit2][p_random % 2] if sound == 'bgsit1'
      game.start_sound(sound)
    end

    def play_death_sound(mo, game)
      sound = info_of(mo)[Info::MI_DEATHSOUND]
      return if sound.nil? || sound.empty?

      sound = %w[podth1 podth2 podth3][p_random % 3] if sound == 'podth1'
      sound = %w[bgdth1 bgdth2][p_random % 2] if sound == 'bgdth1'
      game.start_sound(sound)
    end

    def look_for_players(world, mo, player_mo, allaround)
      return false if player_mo.nil?

      count = 0
      stop = (mo.lastlook - 1) & 3
      loop do
        unless mo.lastlook.zero?
          mo.lastlook = (mo.lastlook + 1) & 3
          next
        end
        return false if count == 2 || mo.lastlook == stop

        count += 1
        if player_mo.health <= 0 || (player_mo.flags & Defs::MF_SHOOTABLE).zero?
          mo.lastlook = (mo.lastlook + 1) & 3
          next
        end
        unless Collision.check_sight(world, mo, player_mo)
          mo.lastlook = (mo.lastlook + 1) & 3
          next
        end
        unless allaround
          an = Collision.angle_to(mo.x, mo.y, player_mo.x, player_mo.y) - mo.angle
          an &= 0xFFFFFFFF
          if an > Defs::ANG90 && an < Defs::ANG270
            dist = Collision.approx_distance(player_mo.x - mo.x, player_mo.y - mo.y)
            if dist > Defs::MELEERANGE
              mo.lastlook = (mo.lastlook + 1) & 3
              next
            end
          end
        end
        mo.target = player_mo
        return true
      end
    end

    def chase(world, mo, player_mo, game)
      info = info_of(mo)
      mo.reactiontime -= 1 if mo.reactiontime != 0
      if mo.threshold != 0
        target = mo.target
        if target.nil? || target.health <= 0
          mo.threshold = 0
        else
          mo.threshold -= 1
        end
      end
      face_movedir(mo) if mo.movedir < 8
      target = mo.target
      if target.nil? || (target.flags & Defs::MF_SHOOTABLE).zero?
        return if look_for_players(world, mo, player_mo, true)

        Thinker.set_mobj_state(mo, info[Info::MI_SPAWNSTATE], world, game)
        return
      end
      if (mo.flags & Defs::MF_JUSTATTACKED) != 0
        mo.flags &= ~Defs::MF_JUSTATTACKED
        new_chase_dir(world, mo, game) if game.skill != Defs::SK_NIGHTMARE && !game.fastparm
        return
      end
      dist = Collision.approx_distance(target.x - mo.x, target.y - mo.y)
      melee_range = Defs::MELEERANGE - 20 * Defs::FRACUNIT + target.radius
      if !info[Info::MI_MELEESTATE].zero? && dist < melee_range && Collision.check_sight(world, mo, target)
        game.start_sound(info[Info::MI_ATTACKSOUND]) unless info[Info::MI_ATTACKSOUND].empty?
        Thinker.set_mobj_state(mo, info[Info::MI_MELEESTATE], world, game)
        return
      end
      unless info[Info::MI_MISSILESTATE].zero?
        skip = game.skill < Defs::SK_NIGHTMARE && !game.fastparm && !mo.movecount.zero?
        if !skip && missile_ok(world, mo, target, dist, !info[Info::MI_MELEESTATE].zero?)
          Thinker.set_mobj_state(mo, info[Info::MI_MISSILESTATE], world, game)
          mo.flags |= Defs::MF_JUSTATTACKED
          return
        end
      end
      mo.movecount -= 1
      new_chase_dir(world, mo, game) if mo.movecount.negative? || !move(world, mo, info[Info::MI_SPEED], game)
      game.start_sound(info[Info::MI_ACTIVESOUND]) if !info[Info::MI_ACTIVESOUND].empty? && p_random < 3
    end

    def missile_ok(world, mo, target, dist, has_melee)
      return false unless Collision.check_sight(world, mo, target)
      if (mo.flags & Defs::MF_JUSTHIT) != 0
        mo.flags &= ~Defs::MF_JUSTHIT
        return true
      end
      return false if mo.reactiontime != 0

      d = dist - 64 * Defs::FRACUNIT
      d -= 128 * Defs::FRACUNIT unless has_melee
      d >>= 16
      return false if mo.type == Info::MT_VILE && d > 14 * 64
      if mo.type == Info::MT_UNDEAD
        return false if d < 196

        d >>= 1
      end
      d >>= 1 if [Info::MT_CYBORG, Info::MT_SPIDER, Info::MT_SKULL].include?(mo.type)
      d = 200 if d > 200
      d = 160 if mo.type == Info::MT_CYBORG && d > 160
      p_random >= d
    end

    def face_target(mo, target)
      mo.angle = Collision.angle_to(mo.x, mo.y, target.x, target.y)
      return if (target.flags & Defs::MF_SHADOW).zero?

      mo.angle = Compat.as_u32(mo.angle + (p_random - p_random) * 2_097_152)
    end

    def face_movedir(mo)
      return unless mo.movedir >= 0 && mo.movedir < 8

      mo.angle = Compat.as_u32(mo.angle & 3_758_096_384)
      delta = Compat.as_i32(mo.angle - mo.movedir * Defs::ANG45)
      if delta.positive?
        mo.angle = Compat.as_u32(mo.angle - Defs::ANG45)
      elsif delta.negative?
        mo.angle = Compat.as_u32(mo.angle + Defs::ANG45)
      end
    end

    def move(world, mo, speed, game)
      return false if mo.movedir.negative? || mo.movedir >= 8

      nx = mo.x + speed * XSPEED[mo.movedir]
      ny = mo.y + speed * YSPEED[mo.movedir]
      unless Collision.try_move(world, mo, nx, ny, game)
        if (mo.flags & Defs::MF_FLOAT) != 0 && Collision.floatok
          mo.z += mo.z < Collision.tmfloorz ? FLOATSPEED : -FLOATSPEED
          mo.flags |= Defs::MF_INFLOAT
          return true
        end
        hits = Collision.last_spechit
        return false if hits.nil? || hits.empty?

        mo.movedir = DI_NODIR
        good = false
        hits.reverse_each do |ln|
          good = true if ln.special != 0 && game && game.use_special(ln, mo, 0)
        end
        return good
      end
      mo.flags &= ~Defs::MF_INFLOAT
      mo.z = mo.floorz if (mo.flags & Defs::MF_FLOAT).zero?
      true
    end

    def new_chase_dir(world, mo, game)
      target = mo.target
      return if target.nil?

      old = mo.movedir
      turn = old >= 0 && old < 8 ? OPPOSITE[old] : DI_NODIR
      dx = target.x - mo.x
      dy = target.y - mo.y
      d2 = dx > 10 * Defs::FRACUNIT ? DI_EAST : (dx < -10 * Defs::FRACUNIT ? DI_WEST : DI_NODIR)
      d3 = dy < -10 * Defs::FRACUNIT ? DI_SOUTH : (dy > 10 * Defs::FRACUNIT ? DI_NORTH : DI_NODIR)
      speed = info_of(mo)[Info::MI_SPEED]
      if d2 != DI_NODIR && d3 != DI_NODIR
        mo.movedir = DIAGS[(dy.negative? ? 2 : 0) + (dx.positive? ? 1 : 0)]
        if mo.movedir != turn && move(world, mo, speed, game)
          mo.movecount = p_random & 15
          return
        end
      end
      d2, d3 = d3, d2 if p_random > 200 || dy.abs > dx.abs
      d2 = DI_NODIR if d2 == turn
      d3 = DI_NODIR if d3 == turn
      if d2 != DI_NODIR
        mo.movedir = d2
        if move(world, mo, speed, game)
          mo.movecount = p_random & 15
          return
        end
      end
      if d3 != DI_NODIR
        mo.movedir = d3
        if move(world, mo, speed, game)
          mo.movecount = p_random & 15
          return
        end
      end
      if old != DI_NODIR
        mo.movedir = old
        if move(world, mo, speed, game)
          mo.movecount = p_random & 15
          return
        end
      end
      dirs = (p_random & 1) != 0 ? (0..7) : (7).downto(0)
      dirs.each do |tdir|
        next if tdir == turn

        mo.movedir = tdir
        if move(world, mo, speed, game)
          mo.movecount = p_random & 15
          return
        end
      end
      if turn != DI_NODIR
        mo.movedir = turn
        if move(world, mo, speed, game)
          mo.movecount = p_random & 15
          return
        end
      end
      mo.movedir = DI_NODIR
      mo.movecount = p_random & 15
    end

    def spawn_missile_mt(world, source, dest, typ, game, ang = nil)
      info = Info::MOBJINFO[typ]
      speed = info[Info::MI_SPEED]
      dest ||= source
      if ang.nil?
        ang = Collision.angle_to(source.x, source.y, dest.x, dest.y)
        ang = Compat.as_u32(ang + (p_random - p_random) * 1_048_576) if (dest.flags & Defs::MF_SHADOW) != 0
      end
      dist = Collision.approx_distance(dest.x - source.x, dest.y - source.y)
      steps = speed.zero? ? 1 : dist / speed
      steps = 1 if steps < 1
      mo = Thinker.spawn_mobj(world, source.x, source.y, source.z + 32 * Defs::FRACUNIT, typ, game)
      mo.target = source
      mo.angle = ang
      mo.momx = Compat.fixed_mul(speed, Tables.fine_cos(ang))
      mo.momy = Compat.fixed_mul(speed, Tables.fine_sin(ang))
      mo.momz = (dest.z - source.z) / steps
      check_missile_spawn(mo)
      mo
    end

    def check_missile_spawn(mo)
      mo.tics -= p_random & 3
      mo.tics = 1 if mo.tics < 1
      mo.x += mo.momx >> 1
      mo.y += mo.momy >> 1
      mo.z += mo.momz >> 1
    end

    def spawn_player_missile(world, source, _sprite, _speed, damage, kind)
      typ = kind == 'rocket' ? Info::MT_ROCKET : (kind == 'plasma' ? Info::MT_PLASMA : Info::MT_BFG)
      aim = Collision.missile_aim(world, source)
      ang = aim[:angle]
      speed = Info::MOBJINFO[typ][Info::MI_SPEED]
      mo = Thinker.spawn_mobj(world, source.x, source.y, source.z + 32 * Defs::FRACUNIT, typ, nil)
      mo.target = source
      mo.angle = ang
      mo.momx = Compat.fixed_mul(speed, Tables.fine_cos(ang))
      mo.momy = Compat.fixed_mul(speed, Tables.fine_sin(ang))
      mo.momz = Compat.fixed_mul(speed, aim[:slope])
      mo.damage = damage if damage != 0
      check_missile_spawn(mo)
      mo
    end

    def trunc2(n)
      n = Compat.as_i32(n)
      n.negative? ? -((-n) / 2) : n / 2
    end

    def p_xy_movement(world, mo, game)
      if mo.momx.zero? && mo.momy.zero?
        if (mo.flags & Defs::MF_SKULLFLY) != 0
          mo.flags &= ~Defs::MF_SKULLFLY
          mo.momx = mo.momy = mo.momz = 0
          Thinker.set_mobj_state(mo, info_of(mo)[Info::MI_SPAWNSTATE], world, game)
        end
        return
      end
      mo.momx = Defs::MAXMOVE if mo.momx > Defs::MAXMOVE
      mo.momx = -Defs::MAXMOVE if mo.momx < -Defs::MAXMOVE
      mo.momy = Defs::MAXMOVE if mo.momy > Defs::MAXMOVE
      mo.momy = -Defs::MAXMOVE if mo.momy < -Defs::MAXMOVE
      xmove = mo.momx
      ymove = mo.momy
      half = Defs::MAXMOVE / 2
      while !xmove.zero? || !ymove.zero?
        if xmove > half || ymove > half
          ptryx = mo.x + trunc2(xmove)
          ptryy = mo.y + trunc2(ymove)
          xmove = trunc2(xmove)
          ymove = trunc2(ymove)
        else
          ptryx = mo.x + xmove
          ptryy = mo.y + ymove
          xmove = ymove = 0
        end
        if (mo.flags & Defs::MF_NOCLIP) != 0
          Collision.unset_thing_position(world, mo)
          mo.x = ptryx
          mo.y = ptryy
          Collision.set_thing_position(world, mo)
          next
        end
        next if Collision.try_move(world, mo, ptryx, ptryy, game)

        if mo.player
          Collision.slide_move(world, mo, mo.momx, mo.momy, game)
        elsif (mo.flags & Defs::MF_MISSILE) != 0
          line = Collision.ceilingline
          sky = game&.res&.skyflatnum || -1
          if line&.backsector && line.backsector.ceilingpic == sky
            Thinker.remove_mobj(world, mo)
          else
            explode_missile(world, mo, game, nil)
          end
          return
        else
          mo.momx = mo.momy = 0
        end
      end
      player = mo.player
      if player && (player.cheats & Defs::CF_NOMOMENTUM) != 0
        mo.momx = mo.momy = 0
        return
      end
      return if (mo.flags & (Defs::MF_MISSILE | Defs::MF_SKULLFLY)) != 0
      return if mo.z > mo.floorz

      if (mo.flags & Defs::MF_CORPSE) != 0 &&
         (mo.momx > Defs::FRACUNIT / 4 || mo.momx < -(Defs::FRACUNIT / 4) ||
          mo.momy > Defs::FRACUNIT / 4 || mo.momy < -(Defs::FRACUNIT / 4))
        sec = world.point_in_subsector(mo.x, mo.y).sector
        return if mo.floorz != sec.floorheight
      end
      stopped = -Defs::STOPSPEED < mo.momx && mo.momx < Defs::STOPSPEED &&
                -Defs::STOPSPEED < mo.momy && mo.momy < Defs::STOPSPEED
      idle = player.nil? || (player.cmd.forwardmove.zero? && player.cmd.sidemove.zero?)
      if stopped && idle
        if player
          n = mo.istate - Info::S_PLAY_RUN1
          Thinker.set_mobj_state(mo, Info::S_PLAY, world, game) if n >= 0 && n < 4
        end
        mo.momx = mo.momy = 0
      else
        mo.momx = Compat.fixed_mul(mo.momx, Defs::FRICTION)
        mo.momy = Compat.fixed_mul(mo.momy, Defs::FRICTION)
      end
    end

    def mobj_z(mo, world, game)
      player = mo.player
      if player && mo.z < mo.floorz
        player.viewheight -= mo.floorz - mo.z
        player.deltaviewheight = Compat.shar(Defs::VIEWHEIGHT - player.viewheight, 3)
      end
      mo.z += mo.momz
      if (mo.flags & Defs::MF_FLOAT) != 0 && mo.target && (mo.flags & (Defs::MF_SKULLFLY | Defs::MF_INFLOAT)).zero?
        dist = Collision.approx_distance(mo.x - mo.target.x, mo.y - mo.target.y)
        delta = (mo.target.z + Compat.shar(mo.height, 1)) - mo.z
        if delta.negative? && dist < -(delta * 3)
          mo.z -= FLOATSPEED
        elsif delta.positive? && dist < delta * 3
          mo.z += FLOATSPEED
        end
      end
      if mo.z <= mo.floorz
        if mo.momz.negative?
          if player && mo.momz < -Defs::GRAVITY * 8
            player.deltaviewheight = Compat.shar(mo.momz, 3)
            game&.start_sound('oof')
          end
          mo.momz = 0
        end
        mo.z = mo.floorz
        mo.momz = -mo.momz if (mo.flags & Defs::MF_SKULLFLY) != 0 && (mo.flags & Defs::MF_MISSILE).zero?
        if (mo.flags & Defs::MF_MISSILE) != 0 && (mo.flags & Defs::MF_NOCLIP).zero?
          explode_missile(world, mo, game, nil)
          return
        end
      elsif (mo.flags & Defs::MF_NOGRAVITY).zero?
        mo.momz = mo.momz.zero? ? -Defs::GRAVITY * 2 : mo.momz - Defs::GRAVITY
      end
      return unless mo.z + mo.height > mo.ceilingz

      mo.momz = 0 if mo.momz.positive?
      mo.z = mo.ceilingz - mo.height
      mo.momz = -mo.momz if (mo.flags & Defs::MF_SKULLFLY) != 0
      return unless (mo.flags & Defs::MF_MISSILE) != 0 && (mo.flags & Defs::MF_NOCLIP).zero?

      explode_missile(world, mo, game, nil)
    end

    def missile_reaches(mo, other, x, y, z)
      return false if other.equal?(mo) || other.equal?(mo.target) || other.health <= 0
      return false if (other.flags & Defs::MF_SHOOTABLE).zero?

      reach = other.radius + mo.radius
      return false if (other.x - x).abs >= reach || (other.y - y).abs >= reach

      slack = 64 * Defs::FRACUNIT
      z1 = z + mo.momz
      low = [z, z1].min - slack
      high = [z, z1].max + mo.height + slack
      if z <= mo.floorz
        low = [low, mo.floorz - slack].min
        high = [high, mo.floorz + slack].max
      end
      low <= other.z + other.height && high >= other.z
    end

    def missile_victim(world, mo)
      spots = [[mo.x, mo.y, mo.z]]
      spots << [mo.tmx, mo.tmy, mo.z] if mo.tmx != mo.x || mo.tmy != mo.y
      best = nil
      best_dist = 1 << 62
      world.mobjs.each do |other|
        spots.each do |x, y, z|
          next unless missile_reaches(mo, other, x, y, z)

          dist = [other.x - x, other.y - y].map(&:abs).max
          if dist < best_dist
            best_dist = dist
            best = other
          end
        end
      end
      best
    end

    def explode_missile(world, mo, game, hit)
      hit = missile_victim(world, mo) if hit.nil?
      if hit && game
        src = mo.target || mo
        dmg = mo.damage.zero? ? info_of(mo)[Info::MI_DAMAGE] : mo.damage
        game.damage_mobj(hit, src, dmg * ((p_random % 8) + 1), mo)
      end
      mo.momx = mo.momy = mo.momz = 0
      mo.flags &= ~Defs::MF_MISSILE
      Thinker.set_mobj_state(mo, info_of(mo)[Info::MI_DEATHSTATE], world, game)
    end

    def radius_attack(world, spot, source, damage, game)
      world.mobjs.dup.each do |other|
        next if other.equal?(spot) || (other.flags & Defs::MF_SHOOTABLE).zero?
        next if other.type == Info::MT_CYBORG || other.type == Info::MT_SPIDER

        dx = (other.x - spot.x).abs
        dy = (other.y - spot.y).abs
        dist = (dx > dy ? dx : dy) - other.radius
        dist = 0 if dist.negative?
        dist >>= 16
        next if dist >= damage
        next unless Collision.check_sight(world, other, spot)

        game.damage_mobj(other, source || spot, damage - dist, spot)
      end
    end

    def bfg_spray(world, ball, game)
      shooter = ball.target
      return if shooter.nil?

      40.times do |i|
        an = Compat.as_u32(shooter.angle - Defs::ANG90 / 2 + (Defs::ANG90 / 40) * i)
        target = Collision.aim_line_attack(world, shooter, an, 16 * 64 * Defs::FRACUNIT)
        next if target.nil?

        damage = 0
        15.times { damage += (p_random & 7) + 1 }
        game.damage_mobj(target, shooter, damage, ball)
      end
    end

    def tracer_home(mo)
      dest = mo.tracer
      return if dest.nil? || dest.health <= 0

      exact = Collision.angle_to(mo.x, mo.y, dest.x, dest.y)
      diff = (exact - mo.angle) & 0xFFFFFFFF
      if diff > 0x80000000
        mo.angle = Compat.as_u32(mo.angle - TRACEANGLE)
        mo.angle = exact if ((exact - mo.angle) & 0xFFFFFFFF) < 0x80000000
      else
        mo.angle = Compat.as_u32(mo.angle + TRACEANGLE)
        mo.angle = exact if ((exact - mo.angle) & 0xFFFFFFFF) > 0x80000000
      end
      speed = info_of(mo)[Info::MI_SPEED]
      mo.momx = Compat.fixed_mul(speed, Tables.fine_cos(mo.angle))
      mo.momy = Compat.fixed_mul(speed, Tables.fine_sin(mo.angle))
      dist = Collision.approx_distance(dest.x - mo.x, dest.y - mo.y)
      steps = speed.zero? ? 1 : dist / speed
      steps = 1 if steps < 1
      mo.momz = (dest.z + 40 * Defs::FRACUNIT - mo.z) / steps
    end

    def vile_chase(world, mo, game)
      world.mobjs.each do |other|
        next if other.equal?(mo) || (other.flags & Defs::MF_CORPSE).zero? || other.health.positive?

        info = Info::MOBJINFO[other.type]
        next if info[Info::MI_RAISESTATE].zero?

        maxdist = mo.radius + other.radius
        next if (other.x - mo.x).abs > maxdist || (other.y - mo.y).abs > maxdist

        Thinker.set_mobj_state(mo, Info::S_VILE_HEAL1, world, game)
        game.start_sound('slop')
        Thinker.set_mobj_state(other, info[Info::MI_RAISESTATE], world, game)
        other.flags = info[Info::MI_FLAGS]
        other.health = info[Info::MI_SPAWNHEALTH]
        other.height = info[Info::MI_HEIGHT]
        other.radius = info[Info::MI_RADIUS]
        other.target = nil
        other.alive = true
        other.z = other.floorz
        return true
      end
      false
    end

    def vile_attack(world, mo, game)
      dest = mo.target
      return if dest.nil? || !Collision.check_sight(world, mo, dest)

      game.start_sound('vilatk')
      game.damage_mobj(dest, mo, 20)
      radius_attack(world, dest, mo, 70, game)
    end

    def pain_shoot_skull(world, actor, game, ang)
      count = world.mobjs.count { |other| other.type == Info::MT_SKULL && other.health.positive? }
      return if count >= MAX_SKULLS

      pre = 4 * Defs::FRACUNIT + 3 * actor.radius / 2
      x = actor.x + Compat.fixed_mul(pre, Tables.fine_cos(ang))
      y = actor.y + Compat.fixed_mul(pre, Tables.fine_sin(ang))
      skull = Thinker.spawn_mobj(world, x, y, actor.z, Info::MT_SKULL, game)
      skull.angle = ang
      if Collision.check_position(world, skull, skull.x, skull.y).blocked
        game.damage_mobj(skull, actor, 10_000, actor)
        return
      end
      skull.target = actor.target
      skull_attack(skull, game)
    end

    def skull_attack(mo, game)
      dest = mo.target
      return if dest.nil?

      mo.flags |= Defs::MF_SKULLFLY
      game.start_sound('sklatk')
      face_target(mo, dest)
      mo.momx = Compat.fixed_mul(Defs::SKULLSPEED, Tables.fine_cos(mo.angle))
      mo.momy = Compat.fixed_mul(Defs::SKULLSPEED, Tables.fine_sin(mo.angle))
      dist = Collision.approx_distance(dest.x - mo.x, dest.y - mo.y)
      steps = Defs::SKULLSPEED.zero? ? 1 : dist / Defs::SKULLSPEED
      steps = 1 if steps < 1
      mo.momz = (dest.z + (dest.height >> 1) - mo.z) / steps
    end

    def pain_die(world, mo, game)
      [Defs::ANG90, Defs::ANG90 * 2, Defs::ANG270].each do |da|
        pain_shoot_skull(world, mo, game, Compat.as_u32(mo.angle + da))
      end
    end

    def alive_of_type(world, typ)
      world.mobjs.any? { |other| other.type == typ && other.health.positive? }
    end

    def commercial(game)
      game.wad.check_num_for_name('MAP01') >= 0
    end

    def boss_death(world, mo, game)
      return if alive_of_type(world, mo.type)

      spec = game.specials
      return if spec.nil?

      if commercial(game) && game.mapn == 7
        if mo.type == Info::MT_FATSO
          spec.do_floor_tag(666, spec.method(:lowest_floor), -1)
        elsif mo.type == Info::MT_BABY
          spec.raise_to_texture_tag(667)
        end
        return
      end
      return if commercial(game)

      if game.episode == 1 && game.mapn == 8 && mo.type == Info::MT_BRUISER
        spec.do_floor_tag(666, spec.method(:lowest_floor), -1)
      elsif game.episode == 2 && game.mapn == 8 && mo.type == Info::MT_CYBORG
        spec.exit_requested = true
      elsif game.episode == 3 && game.mapn == 8 && mo.type == Info::MT_SPIDER
        spec.exit_requested = true
      elsif game.episode == 4 && game.mapn == 6 && mo.type == Info::MT_CYBORG
        spec.do_floor_tag(666, spec.method(:lowest_floor), -1)
      elsif game.episode == 4 && game.mapn == 8 && mo.type == Info::MT_BRUISER
        spec.do_floor_tag(666, spec.method(:lowest_floor), -1)
      end
    end

    def keen_die(world, mo, game)
      return if alive_of_type(world, Info::MT_KEEN)

      game.specials&.do_door_tag(666, Defs::VLD_BLAZEOPEN)
    end

    def brain_awake(world, game)
      @brain_targets = world.mobjs.select { |m| m.type == Info::MT_BOSSTARGET }
      @brain_target_on = 0
      game.start_sound('bossit')
    end

    def brain_spit(world, actor, game)
      if game.skill <= Defs::SK_EASY
        actor.easy_skip = !actor.easy_skip
        return if actor.easy_skip
      end
      targs = @brain_targets
      targs = world.mobjs.select { |m| m.type == Info::MT_BOSSTARGET } if targs.nil? || targs.empty?
      return if targs.empty?

      dest = targs[@brain_target_on % targs.length]
      @brain_target_on += 1
      game.start_sound('bospit')
      miss = spawn_missile_mt(world, actor, dest, Info::MT_SPAWNSHOT, game)
      miss.target = dest
      st = miss.tics.zero? ? 1 : miss.tics
      miss.reactiontime = ((dest.y - actor.y) / miss.momy) / st unless miss.momy.zero?
    end

    def spawn_fly(world, cube, game)
      dest = cube.target || cube
      r = p_random
      typ = if r < 50 then Info::MT_TROOP
            elsif r < 90 then Info::MT_SERGEANT
            elsif r < 120 then Info::MT_SHADOWS
            elsif r < 130 then Info::MT_PAIN
            elsif r < 160 then Info::MT_HEAD
            elsif r < 162 then Info::MT_VILE
            elsif r < 172 then Info::MT_UNDEAD
            elsif r < 192 then Info::MT_BABY
            elsif r < 222 then Info::MT_FATSO
            elsif r < 246 then Info::MT_KNIGHT
            else Info::MT_BRUISER
            end
      game.start_sound('telept')
      spawned = Thinker.spawn_mobj(world, dest.x, dest.y, dest.z, typ, game)
      spawned.angle = dest.angle
      Thinker.remove_mobj(world, cube)
    end

    def spawn_fly_tic(world, mo, game)
      mo.reactiontime -= 1
      return if mo.reactiontime != 0

      spawn_fly(world, mo, game)
    end

    def hitscan(world, mo, game, sound, pellets)
      return if mo.target.nil?

      face_target(mo, mo.target)
      slope = Collision.aim_slope(world, mo, mo.angle, Defs::MISSILERANGE)
      game.start_sound(sound)
      saved = mo.angle
      pellets.times do
        mo.angle = Compat.as_u32(saved + ((p_random - p_random) << 20))
        Collision.line_attack(world, mo, ((p_random % 5) + 1) * 3, game, Defs::MISSILERANGE, mo.angle, slope)
      end
      mo.angle = saved
    end

    def call_action(name, mo, world, game)
      pl = game&.player&.mo
      case name
      when 'Look'
        look(world, mo, pl, game)
      when 'Chase'
        chase(world, mo, pl, game)
      when 'FaceTarget'
        face_target(mo, mo.target) if mo.target
      when 'Fall'
        mo.flags &= ~Defs::MF_SOLID
      when 'Scream'
        play_death_sound(mo, game)
      when 'XScream'
        game.start_sound('slop')
      when 'Pain'
        sound = info_of(mo)[Info::MI_PAINSOUND]
        game.start_sound(sound) unless sound.nil? || sound.empty?
      when 'Explode'
        radius_attack(world, mo, mo.target, 128, game)
      when 'PosAttack'
        hitscan(world, mo, game, 'pistol', 1)
      when 'SPosAttack'
        hitscan(world, mo, game, 'shotgn', 3)
      when 'CPosAttack'
        hitscan(world, mo, game, 'shotgn', 1)
      when 'CPosRefire', 'SpidRefire'
        face_target(mo, mo.target) if mo.target
        keep = name == 'CPosRefire' ? 40 : 10
        return if p_random < keep
        if mo.target.nil? || mo.target.health <= 0 || !Collision.check_sight(world, mo, mo.target)
          Thinker.set_mobj_state(mo, info_of(mo)[Info::MI_SEESTATE], world, game)
        end
      when 'TroopAttack'
        return if mo.target.nil?

        face_target(mo, mo.target)
        dist = Collision.approx_distance(mo.target.x - mo.x, mo.target.y - mo.y)
        if dist < Defs::MELEERANGE + mo.radius
          game.start_sound('claw')
          game.damage_mobj(mo.target, mo, ((p_random % 8) + 1) * 3)
        else
          spawn_missile_mt(world, mo, mo.target, Info::MT_TROOPSHOT, game)
        end
      when 'SargAttack'
        return if mo.target.nil?

        face_target(mo, mo.target)
        dist = Collision.approx_distance(mo.target.x - mo.x, mo.target.y - mo.y)
        game.damage_mobj(mo.target, mo, ((p_random % 8) + 1) * 4) if dist < Defs::MELEERANGE + mo.radius
      when 'HeadAttack'
        return if mo.target.nil?

        face_target(mo, mo.target)
        dist = Collision.approx_distance(mo.target.x - mo.x, mo.target.y - mo.y)
        if dist < Defs::MELEERANGE + mo.radius
          game.damage_mobj(mo.target, mo, ((p_random % 8) + 1) * 10)
        else
          spawn_missile_mt(world, mo, mo.target, Info::MT_HEADSHOT, game)
        end
      when 'BruisAttack'
        return if mo.target.nil?

        face_target(mo, mo.target)
        dist = Collision.approx_distance(mo.target.x - mo.x, mo.target.y - mo.y)
        if dist < Defs::MELEERANGE + mo.radius
          game.damage_mobj(mo.target, mo, ((p_random % 8) + 1) * 10)
        else
          spawn_missile_mt(world, mo, mo.target, Info::MT_BRUISERSHOT, game)
        end
      when 'SkullAttack'
        skull_attack(mo, game)
      when 'CyberAttack'
        return if mo.target.nil?

        face_target(mo, mo.target)
        spawn_missile_mt(world, mo, mo.target, Info::MT_ROCKET, game)
      when 'BspiAttack'
        return if mo.target.nil?

        face_target(mo, mo.target)
        spawn_missile_mt(world, mo, mo.target, Info::MT_ARACHPLAZ, game)
      when 'Metal'
        game.start_sound('metal')
        chase(world, mo, pl, game)
      when 'BabyMetal'
        game.start_sound('bspwlk')
        chase(world, mo, pl, game)
      when 'Hoof'
        game.start_sound('hoof')
        chase(world, mo, pl, game)
      when 'PainAttack'
        return if mo.target.nil?

        face_target(mo, mo.target)
        pain_shoot_skull(world, mo, game, mo.angle)
      when 'PainDie'
        mo.flags &= ~Defs::MF_SOLID
        pain_die(world, mo, game)
      when 'KeenDie'
        mo.flags &= ~Defs::MF_SOLID
        keen_die(world, mo, game)
      when 'BossDeath'
        boss_death(world, mo, game)
      when 'VileChase'
        chase(world, mo, pl, game) unless vile_chase(world, mo, game)
      when 'VileStart'
        game.start_sound('vilatk')
      when 'VileTarget'
        return if mo.target.nil?

        face_target(mo, mo.target)
        fog = Thinker.spawn_mobj(world, mo.target.x, mo.target.y, mo.target.z, Info::MT_FIRE, game)
        mo.tracer = fog
        fog.target = mo
        fog.tracer = mo.target
      when 'VileAttack'
        vile_attack(world, mo, game)
      when 'StartFire', 'Fire', 'FireCrackle'
        game.start_sound('flamst') if name == 'StartFire'
        game.start_sound('flame') if name == 'FireCrackle'
        dest = mo.tracer
        return if dest.nil? || mo.target.nil?

        mo.x = dest.x
        mo.y = dest.y
        mo.z = dest.z
      when 'Tracer'
        return if (game.leveltime & 3) != 0

        tracer_home(mo)
      when 'SkelWhoosh'
        return if mo.target.nil?

        face_target(mo, mo.target)
        game.start_sound('skeswg')
      when 'SkelFist'
        return if mo.target.nil?

        face_target(mo, mo.target)
        dist = Collision.approx_distance(mo.target.x - mo.x, mo.target.y - mo.y)
        if dist < Defs::MELEERANGE + mo.radius
          game.start_sound('skepch')
          game.damage_mobj(mo.target, mo, ((p_random % 8) + 1) * 6)
        end
      when 'SkelMissile'
        return if mo.target.nil?

        face_target(mo, mo.target)
        miss = spawn_missile_mt(world, mo, mo.target, Info::MT_TRACER, game)
        miss.tracer = mo.target
        miss.z += 16 * Defs::FRACUNIT
      when 'FatRaise'
        face_target(mo, mo.target) if mo.target
        game.start_sound('manatk')
      when 'FatAttack1'
        return if mo.target.nil?

        face_target(mo, mo.target)
        mo.angle = Compat.as_u32(mo.angle + FATSPREAD)
        spawn_missile_mt(world, mo, mo.target, Info::MT_FATSHOT, game)
        miss = spawn_missile_mt(world, mo, mo.target, Info::MT_FATSHOT, game)
        miss.angle = Compat.as_u32(miss.angle + FATSPREAD)
        miss.momx = Compat.fixed_mul(info_of(miss)[Info::MI_SPEED], Tables.fine_cos(miss.angle))
        miss.momy = Compat.fixed_mul(info_of(miss)[Info::MI_SPEED], Tables.fine_sin(miss.angle))
      when 'FatAttack2'
        return if mo.target.nil?

        face_target(mo, mo.target)
        mo.angle = Compat.as_u32(mo.angle - FATSPREAD)
        spawn_missile_mt(world, mo, mo.target, Info::MT_FATSHOT, game)
        miss = spawn_missile_mt(world, mo, mo.target, Info::MT_FATSHOT, game)
        miss.angle = Compat.as_u32(miss.angle - FATSPREAD * 2)
        miss.momx = Compat.fixed_mul(info_of(miss)[Info::MI_SPEED], Tables.fine_cos(miss.angle))
        miss.momy = Compat.fixed_mul(info_of(miss)[Info::MI_SPEED], Tables.fine_sin(miss.angle))
      when 'FatAttack3'
        return if mo.target.nil?

        face_target(mo, mo.target)
        miss = spawn_missile_mt(world, mo, mo.target, Info::MT_FATSHOT, game)
        miss.angle = Compat.as_u32(mo.angle - FATSPREAD / 2)
        miss.momx = Compat.fixed_mul(info_of(miss)[Info::MI_SPEED], Tables.fine_cos(miss.angle))
        miss.momy = Compat.fixed_mul(info_of(miss)[Info::MI_SPEED], Tables.fine_sin(miss.angle))
        miss = spawn_missile_mt(world, mo, mo.target, Info::MT_FATSHOT, game)
        miss.angle = Compat.as_u32(mo.angle + FATSPREAD / 2)
        miss.momx = Compat.fixed_mul(info_of(miss)[Info::MI_SPEED], Tables.fine_cos(miss.angle))
        miss.momy = Compat.fixed_mul(info_of(miss)[Info::MI_SPEED], Tables.fine_sin(miss.angle))
      when 'BrainPain'
        game.start_sound('bospn')
      when 'BrainScream'
        game.start_sound('bosdth')
      when 'BrainDie'
        game.specials.exit_requested = true if game.specials
      when 'BrainAwake'
        brain_awake(world, game)
      when 'BrainSpit'
        brain_spit(world, mo, game)
      when 'SpawnSound'
        game.start_sound('boscub')
        spawn_fly_tic(world, mo, game)
      when 'SpawnFly'
        spawn_fly_tic(world, mo, game)
      when 'BFGSpray'
        bfg_spray(world, mo, game)
      when 'PlayerScream'
        game&.start_sound('pldeth')
      end
    end
  end
end
