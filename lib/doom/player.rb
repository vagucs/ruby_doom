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
# Andar, atirar e morrer. Ctrl dispara. As teclas 1 a 7 trocam a arma.

module Doom
  FORWARDMOVE = [0x19, 0x32].freeze
  SIDEMOVE = [0x18, 0x28].freeze
  ANGLETURN = [640, 1280, 320].freeze

  class Ticcmd
    attr_accessor :forwardmove, :sidemove, :angleturn, :buttons

    def initialize
      @forwardmove = @sidemove = @angleturn = @buttons = 0
    end
  end

  class Mobj
    attr_accessor :x, :y, :z, :angle, :momx, :momy, :momz, :radius, :height,
                  :floorz, :ceilingz, :flags, :health, :player,
                  :sprite, :frame, :type, :doomednum, :alive,
                  :tmx, :tmy, :bnext, :bprev, :bindex, :blocklinked, :reactiontime,
                  :lastlook, :target, :movedir, :movecount, :threshold, :tics, :istate,
                  :damage, :tracer, :spawnpoint, :easy_skip, :info

    def initialize
      @x = @y = @z = @angle = 0
      @momx = @momy = @momz = 0
      @radius = Defs::PLAYER_RADIUS
      @height = Defs::PLAYER_HEIGHT
      @floorz = @ceilingz = 0
      @flags = Defs::MF_SOLID | Defs::MF_SHOOTABLE | Defs::MF_PICKUP | Defs::MF_DROPOFF
      @health = 100
      @player = nil
      @sprite = ''
      @frame = 0
      @type = 0
      @doomednum = -1
      @alive = true
      @reactiontime = 0
      @lastlook = 0
      @target = nil
      @movedir = 8
      @movecount = 0
      @threshold = 0
      @tics = -1
      @istate = 0
      @damage = 0
      @tracer = nil
      @spawnpoint = nil
      @easy_skip = false
      @info = nil
      @tmx = @tmy = 0
      @bnext = @bprev = nil
      @bindex = -1
      @blocklinked = false
    end
  end

  class Player
    attr_accessor :mo, :cmd, :viewz, :viewheight, :deltaviewheight, :bob, :health,
                  :cards, :message, :usedown, :playerstate, :secretcount, :didsecret,
                  :ammo, :maxammo, :weaponowned, :pendingweapon, :readyweapon,
                  :attackdown, :damagecount, :bonuscount, :attacker, :extralight,
                  :fixedcolormap, :refire, :killcount, :armorpoints, :armortype,
                  :cheats, :powers, :itemcount, :message_tics, :psprite_y, :psprite_sy, :psprite_state,
                  :psprite_tics, :psprite_step, :psprite_body, :psprite_flash, :flash_tics

    def initialize
      @mo = nil
      @cmd = Ticcmd.new
      @viewz = 0
      @viewheight = Defs::VIEWHEIGHT
      @deltaviewheight = 0
      @bob = 0
      @health = 100
      @cards = [false] * 6
      @message = ''
      @usedown = false
      @playerstate = Defs::PST_LIVE
      @secretcount = 0
      @didsecret = false
      @ammo = [50, 0, 0, 0]
      @maxammo = [200, 50, 300, 50]
      @weaponowned = [true, true] + [false] * 7
      @pendingweapon = Defs::WP_NOCHANGE
      @readyweapon = Defs::WP_PISTOL
      @attackdown = false
      @damagecount = 0
      @bonuscount = 0
      @attacker = nil
      @extralight = 0
      @fixedcolormap = 0
      @refire = 0
      @killcount = 0
      @armorpoints = 0
      @armortype = 0
      @cheats = 0
      @powers = [0] * 6
      @itemcount = 0
      @message_tics = 0
      @psprite_y = 32
      @psprite_sy = 128 * Defs::FRACUNIT
      @psprite_state = 'up'
      @psprite_tics = 0
      @psprite_step = 0
      @psprite_body = ''
      @psprite_flash = ''
      @flash_tics = 0
    end

    def set_message(text)
      @message = Deh.string(text.to_s)
      @message_tics = 4 * Defs::TICRATE
      puts @message unless @message.empty?
    end
  end

  module Actors
    module_function

    def spawn_player(world, start)
      x = start.x * Defs::FRACUNIT
      y = start.y * Defs::FRACUNIT
      sub = world.point_in_subsector(x, y)
      mo = Mobj.new
      mo.x = x
      mo.y = y
      mo.z = sub.sector.floorheight
      mo.angle = Compat.as_u32((start.angle / 45) * 0x20000000)
      mo.floorz = sub.sector.floorheight
      mo.ceilingz = sub.sector.ceilingheight
      player = Player.new
      player.mo = mo
      player.health = Deh.current.initial_health
      mo.health = player.health
      player.ammo = [Deh.current.initial_bullets, 0, 0, 0]
      player.maxammo = Deh.current.maxammo.dup
      player.viewz = mo.z + Defs::VIEWHEIGHT
      mo.type = Info::MT_PLAYER
      mo.doomednum = -1
      mo.lastlook = Rng.p_random % 4
      mo.player = player
      world.mobjs << mo
      Collision.set_thing_position(world, mo)
      player
    end

    def thrust(mo, angle, move)
      mo.momx += Compat.fixed_mul(move, Tables.fine_cos(angle))
      mo.momy += Compat.fixed_mul(move, Tables.fine_sin(angle))
    end

    def think(world, player, leveltime, game = nil)
      if player.playerstate == Defs::PST_DEAD
        death_think(world, player, game, leveltime)
        return
      end

      Tables.init_tables
      mo = player.mo
      cmd = player.cmd
      mo.angle = Compat.as_u32(mo.angle + (cmd.angleturn << 16))
      onground = mo.z <= mo.floorz
      thrust(mo, mo.angle, cmd.forwardmove * 2048) if cmd.forwardmove != 0 && onground
      thrust(mo, Compat.as_u32(mo.angle - Defs::ANG90), cmd.sidemove * 2048) if cmd.sidemove != 0 && onground
      xy_movement(world, mo, game)
      z_movement(mo)
      calc_height(player, leveltime)
      if (cmd.buttons & Defs::BT_USE) != 0
        unless player.usedown
          Collision.use_lines(world, player)
          player.usedown = true
        end
      else
        player.usedown = false
      end
      special_sector(world, player, leveltime)
      if (cmd.buttons & Defs::BT_CHANGE) != 0
        neww = (cmd.buttons & Defs::BT_WEAPONMASK) >> Defs::BT_WEAPONSHIFT
        if neww >= 0 && neww <= Defs::WP_SUPERSHOTGUN && player.weaponowned[neww] && neww != player.readyweapon
          player.pendingweapon = neww
        end
      end
      weapon_think(player, game) if game
      tick_powers(player)
    end

    def death_think(world, player, game, leveltime)
      mo = player.mo
      cmd = player.cmd
      player.viewheight -= Defs::FRACUNIT if player.viewheight > 6 * Defs::FRACUNIT
      player.viewheight = 6 * Defs::FRACUNIT if player.viewheight < 6 * Defs::FRACUNIT
      player.deltaviewheight = 0
      xy_movement(world, mo, game)
      z_movement(mo)
      calc_height(player, leveltime)
      if player.attacker && !player.attacker.equal?(mo)
        angle = Collision.angle_to(mo.x, mo.y, player.attacker.x, player.attacker.y)
        delta = Compat.as_u32(angle - mo.angle)
        ang5 = Defs::ANG90 / 18
        if delta < Compat.as_u32(ang5) || delta > Compat.as_u32(-ang5)
          mo.angle = angle
          player.damagecount -= 1 if player.damagecount != 0
        elsif delta < Compat.as_u32(Defs::ANG180)
          mo.angle = Compat.as_u32(mo.angle + ang5)
        else
          mo.angle = Compat.as_u32(mo.angle - ang5)
        end
      elsif player.damagecount != 0
        player.damagecount -= 1
      end
      weapon_think(player, game) if game
      player.playerstate = Defs::PST_REBORN if (cmd.buttons & Defs::BT_USE) != 0
    end

    def tick_powers(player)
      player.powers[Defs::PW_STRENGTH] += 1 if player.powers[Defs::PW_STRENGTH] != 0
      if player.powers[Defs::PW_INVULNERABILITY] != 0
        player.powers[Defs::PW_INVULNERABILITY] -= 1
      end
      if player.powers[Defs::PW_INVISIBILITY] != 0
        player.powers[Defs::PW_INVISIBILITY] -= 1
        player.mo.flags &= ~Defs::MF_SHADOW if player.powers[Defs::PW_INVISIBILITY].zero? && player.mo
      end
      player.powers[Defs::PW_INFRARED] -= 1 if player.powers[Defs::PW_INFRARED] != 0
      player.powers[Defs::PW_IRONFEET] -= 1 if player.powers[Defs::PW_IRONFEET] != 0
      inv = player.powers[Defs::PW_INVULNERABILITY]
      ir = player.powers[Defs::PW_INFRARED]
      if inv != 0
        player.fixedcolormap = inv > 4 * 32 || (inv & 8) != 0 ? Defs::INVERSECOLORMAP : 0
      elsif ir != 0
        player.fixedcolormap = ir > 4 * 32 || (ir & 8) != 0 ? 1 : 0
      else
        player.fixedcolormap = 0
      end
      player.damagecount -= 1 if player.damagecount != 0
      player.bonuscount -= 1 if player.bonuscount != 0
      if player.message_tics != 0
        player.message_tics -= 1
        player.message = '' if player.message_tics <= 0
      end
    end

    def give_power(player, power)
      if power == Defs::PW_INVULNERABILITY
        player.powers[power] = Defs::INVULNTICS
        return true
      end
      if power == Defs::PW_INVISIBILITY
        player.powers[power] = Defs::INVISTICS
        player.mo.flags |= Defs::MF_SHADOW if player.mo
        return true
      end
      if power == Defs::PW_INFRARED
        player.powers[power] = Defs::INFRATICS
        return true
      end
      if power == Defs::PW_IRONFEET
        player.powers[power] = Defs::IRONTICS
        return true
      end
      if power == Defs::PW_STRENGTH
        if player.health < Defs::MAXHEALTH
          player.health = [Defs::MAXHEALTH, player.health + 100].min
          player.mo.health = player.health if player.mo
        end
        player.powers[power] = 1
        return true
      end
      return false if player.powers[power] != 0

      player.powers[power] = 1
      true
    end

    def special_sector(world, player, leveltime)
      mo = player.mo
      sector = world.point_in_subsector(mo.x, mo.y).sector
      return if mo.z != sector.floorheight || sector.special.zero?

      spec = sector.special
      if spec == 9
        player.secretcount += 1
        sector.special = 0
        return
      end
      return unless [5, 7, 4, 16, 11].include?(spec)
      return unless (leveltime & 0x1F).zero?

      damage = spec == 7 ? 5 : (spec == 5 ? 10 : 20)
      player.health -= damage
      mo.health = player.health
      world.specials.exit_requested = true if spec == 11 && player.health <= 10 && world.specials
      return if player.health.positive?

      player.health = 0
      mo.health = 0
      player.playerstate = Defs::PST_DEAD
      mo.flags &= ~(Defs::MF_SOLID | Defs::MF_SHOOTABLE)
    end

    def trunc2(n)
      n = Compat.as_i32(n)
      n.negative? ? -((-n) / 2) : n / 2
    end

    def xy_movement(world, mo, game = nil)
      return if mo.momx.zero? && mo.momy.zero?

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
          xmove = 0
          ymove = 0
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
        else
          mo.momx = 0
          mo.momy = 0
        end
      end
      return if mo.z > mo.floorz

      player = mo.player
      stopped = -Defs::STOPSPEED < mo.momx && mo.momx < Defs::STOPSPEED &&
                -Defs::STOPSPEED < mo.momy && mo.momy < Defs::STOPSPEED
      if player && stopped && player.cmd.forwardmove.zero? && player.cmd.sidemove.zero?
        mo.momx = 0
        mo.momy = 0
      else
        mo.momx = Compat.fixed_mul(mo.momx, Defs::FRICTION)
        mo.momy = Compat.fixed_mul(mo.momy, Defs::FRICTION)
      end
    end

    def z_movement(mo)
      player = mo.player
      if player && mo.z < mo.floorz
        player.viewheight -= mo.floorz - mo.z
        player.deltaviewheight = Compat.shar(Defs::VIEWHEIGHT - player.viewheight, 3)
      end
      mo.z += mo.momz
      if mo.z <= mo.floorz
        if mo.momz.negative?
          player.deltaviewheight = Compat.shar(mo.momz, 3) if player && mo.momz < -Defs::GRAVITY * 8
          mo.momz = 0
        end
        mo.z = mo.floorz
      elsif (mo.flags & Defs::MF_NOGRAVITY).zero?
        mo.momz = mo.momz.zero? ? -Defs::GRAVITY * 2 : mo.momz - Defs::GRAVITY
      end
      return unless mo.z + mo.height > mo.ceilingz

      mo.momz = 0 if mo.momz.positive?
      mo.z = mo.ceilingz - mo.height
    end

    def calc_height(player, leveltime)
      mo = player.mo
      player.bob = (Compat.fixed_mul(mo.momx, mo.momx) + Compat.fixed_mul(mo.momy, mo.momy)) / 4
      player.bob = Defs::MAXBOB if player.bob > Defs::MAXBOB
      unless mo.z <= mo.floorz
        player.viewz = mo.z + player.viewheight
        player.viewz = mo.ceilingz - 4 * Defs::FRACUNIT if player.viewz > mo.ceilingz - 4 * Defs::FRACUNIT
        return
      end
      angle = ((Defs::FINEANGLES / 20) * leveltime) & Defs::FINEMASK
      bob = Compat.fixed_mul(player.bob / 2, Tables.finesine[angle] || 0)
      player.viewheight += player.deltaviewheight
      if player.viewheight > Defs::VIEWHEIGHT
        player.viewheight = Defs::VIEWHEIGHT
        player.deltaviewheight = 0
      end
      if player.viewheight < Defs::VIEWHEIGHT / 2
        player.viewheight = Defs::VIEWHEIGHT / 2
        player.deltaviewheight = 1 if player.deltaviewheight <= 0
      end
      player.deltaviewheight += Defs::FRACUNIT / 4 if player.deltaviewheight != 0
      player.viewz = mo.z + player.viewheight + bob
      player.viewz = mo.ceilingz - 4 * Defs::FRACUNIT if player.viewz > mo.ceilingz - 4 * Defs::FRACUNIT
    end

    WEAPON_AMMO = {
      Defs::WP_PISTOL => Defs::AM_CLIP,
      Defs::WP_SHOTGUN => Defs::AM_SHELL,
      Defs::WP_SUPERSHOTGUN => Defs::AM_SHELL,
      Defs::WP_CHAINGUN => Defs::AM_CLIP,
      Defs::WP_MISSILE => Defs::AM_MISL,
      Defs::WP_PLASMA => Defs::AM_CELL,
      Defs::WP_BFG => Defs::AM_CELL
    }.freeze
    WEAPON_PATCH = {
      Defs::WP_FIST => 'PUNGA0',
      Defs::WP_PISTOL => 'PISGA0',
      Defs::WP_SHOTGUN => 'SHTGA0',
      Defs::WP_CHAINGUN => 'CHGGA0',
      Defs::WP_MISSILE => 'MISGA0',
      Defs::WP_PLASMA => 'PLSGA0',
      Defs::WP_BFG => 'BFGGA0',
      Defs::WP_CHAINSAW => 'SAWGC0',
      Defs::WP_SUPERSHOTGUN => 'SHT2A0'
    }.freeze
    WEAPON_FIRE_BODY = {
      Defs::WP_FIST => 'PUNGC0',
      Defs::WP_PISTOL => 'PISGB0',
      Defs::WP_SHOTGUN => 'SHTGA0',
      Defs::WP_CHAINGUN => 'CHGGB0',
      Defs::WP_MISSILE => 'MISGB0',
      Defs::WP_PLASMA => 'PLSGA0',
      Defs::WP_BFG => 'BFGGB0',
      Defs::WP_CHAINSAW => 'SAWGA0',
      Defs::WP_SUPERSHOTGUN => 'SHT2A0'
    }.freeze
    WEAPON_ATK = {
      Defs::WP_FIST => [
        ['PUNGB0', 4, false, '', 0, 0],
        ['PUNGC0', 4, true, '', 0, 0],
        ['PUNGD0', 5, false, '', 0, 0],
        ['PUNGC0', 4, false, '', 0, 0],
        ['PUNGB0', 5, false, '', 0, 0]
      ],
      Defs::WP_PISTOL => [
        ['PISGA0', 4, false, '', 0, 0],
        ['PISGB0', 6, true, 'PISFA0', 7, 1],
        ['PISGC0', 4, false, '', 0, 0],
        ['PISGB0', 5, false, '', 0, 0]
      ],
      Defs::WP_SHOTGUN => [
        ['SHTGA0', 3, false, '', 0, 0],
        ['SHTGA0', 7, true, 'SHTFA0', 7, 1],
        ['SHTGB0', 5, false, '', 0, 0],
        ['SHTGC0', 5, false, '', 0, 0],
        ['SHTGD0', 4, false, '', 0, 0],
        ['SHTGC0', 5, false, '', 0, 0],
        ['SHTGB0', 5, false, '', 0, 0],
        ['SHTGA0', 3, false, '', 0, 0],
        ['SHTGA0', 7, false, '', 0, 0]
      ],
      Defs::WP_CHAINGUN => [
        ['CHGGA0', 4, true, 'CHGFA0', 5, 1],
        ['CHGGB0', 4, true, 'CHGFB0', 5, 2]
      ],
      Defs::WP_MISSILE => [
        ['MISGB0', 8, false, 'MISFA0', 15, 1],
        ['MISGB0', 12, true, '', 0, 2]
      ],
      Defs::WP_PLASMA => [
        ['PLSGA0', 3, true, 'PLSFA0', 4, 1],
        ['PLSGB0', 20, false, '', 0, 0, true]
      ],
      Defs::WP_BFG => [
        ['BFGGA0', 20, false, '', 0, 0],
        ['BFGGB0', 10, false, 'BFGFA0', 17, 1],
        ['BFGGB0', 10, true, '', 0, 2],
        ['BFGGB0', 20, false, '', 0, 0]
      ],
      Defs::WP_CHAINSAW => [
        ['SAWGA0', 4, true, '', 0, 0],
        ['SAWGB0', 4, true, '', 0, 0]
      ],
      Defs::WP_SUPERSHOTGUN => [
        ['SHT2A0', 3, false, '', 0, 0],
        ['SHT2A0', 7, true, 'SHT2I0', 9, 1],
        ['SHT2B0', 7, false, '', 0, 0],
        ['SHT2C0', 7, false, '', 0, 0],
        ['SHT2D0', 7, false, '', 0, 0],
        ['SHT2E0', 7, false, '', 0, 0],
        ['SHT2F0', 7, false, '', 0, 0],
        ['SHT2G0', 6, false, '', 0, 0],
        ['SHT2H0', 6, false, '', 0, 0],
        ['SHT2A0', 5, false, '', 0, 0]
      ]
    }.freeze
    WEAPON_READY = {
      Defs::WP_CHAINSAW => [['SAWGC0', 4, 'sawidl'], ['SAWGD0', 4, '']]
    }.freeze
    WEAPONTOP = 32 * Defs::FRACUNIT
    WEAPONBOTTOM = 128 * Defs::FRACUNIT
    LOWERSPEED = 6 * Defs::FRACUNIT
    RAISESPEED = 6 * Defs::FRACUNIT

    def weapon_patch(player)
      return player.psprite_body unless player.psprite_body.empty?
      if player.psprite_state == 'atk' || player.psprite_state == 'fire'
        return WEAPON_FIRE_BODY[player.readyweapon] || WEAPON_PATCH[player.readyweapon] || 'PISGA0'
      end

      WEAPON_PATCH[player.readyweapon] || 'PISGA0'
    end

    def ammo_needed(weapon)
      weapon == Defs::WP_BFG ? Deh.current.bfg_cells_per_shot : 1
    end

    def weapon_think(player, game)
      if player.playerstate == Defs::PST_DEAD || player.health <= 0
        lower_weapon(player, game)
        return
      end
      firing = (player.cmd.buttons & Defs::BT_ATTACK) != 0
      ammo_type = WEAPON_AMMO[player.readyweapon]
      can_fire = true
      if ammo_type && player.ammo[ammo_type] < ammo_needed(player.readyweapon)
        can_fire = player.readyweapon == Defs::WP_FIST || player.readyweapon == Defs::WP_CHAINSAW
        unless can_fire
          [Defs::WP_PISTOL, Defs::WP_SHOTGUN, Defs::WP_CHAINGUN, Defs::WP_MISSILE, Defs::WP_PLASMA, Defs::WP_BFG, Defs::WP_FIST].each do |w|
            at = WEAPON_AMMO[w]
            next unless player.weaponowned[w] && (at.nil? || player.ammo[at] >= ammo_needed(w))

            player.pendingweapon = w
            break
          end
          ammo_type = WEAPON_AMMO[player.readyweapon]
          can_fire = ammo_type.nil? || player.ammo[ammo_type] >= ammo_needed(player.readyweapon)
        end
      end
      if player.flash_tics.positive?
        player.flash_tics -= 1
        if player.flash_tics <= 0
          player.psprite_flash = ''
          player.extralight = 0
        end
      end
      player.psprite_state = 'atk' if player.psprite_state == 'fire'
      if player.psprite_state == 'atk'
        player.attackdown = true if firing
        player.psprite_tics -= 1 if player.psprite_tics.positive?
        return if player.psprite_tics.positive?

        player.psprite_step += 1
        enter_atk_step(player, game, ammo_type, firing, can_fire)
        return
      end
      if player.pendingweapon != Defs::WP_NOCHANGE || player.psprite_state == 'down'
        lower_weapon(player, game)
        return
      end
      if player.psprite_state == 'up'
        raise_weapon(player, game)
        return
      end
      if firing && can_fire
        ready_gate = !player.attackdown || ![Defs::WP_MISSILE, Defs::WP_BFG].include?(player.readyweapon)
        if ready_gate
          player.psprite_state = 'atk'
          player.psprite_step = 0
          player.psprite_sy = WEAPONTOP
          player.attackdown = true
          enter_atk_step(player, game, ammo_type, firing, can_fire)
          return
        end
      end
      unless player.psprite_state == 'ready'
        start_ready(player, game)
        return
      end
      tick_ready(player, game)
      return if firing

      player.attackdown = false
      player.refire = 0
    end

    def lower_weapon(player, game)
      player.psprite_state = 'down'
      player.psprite_body = WEAPON_PATCH[player.readyweapon] || 'PISGA0' if player.psprite_body.empty?
      player.psprite_sy += LOWERSPEED
      return if player.psprite_sy < WEAPONBOTTOM

      player.psprite_sy = WEAPONBOTTOM
      return if player.playerstate == Defs::PST_DEAD || player.health <= 0

      if player.pendingweapon != Defs::WP_NOCHANGE
        player.readyweapon = player.pendingweapon
        player.pendingweapon = Defs::WP_NOCHANGE
      end
      game.start_sound('sawup') if player.readyweapon == Defs::WP_CHAINSAW
      player.psprite_state = 'up'
      player.psprite_body = WEAPON_PATCH[player.readyweapon] || 'PISGA0'
    end

    def raise_weapon(player, game)
      player.psprite_sy -= RAISESPEED
      player.psprite_body = WEAPON_PATCH[player.readyweapon] || 'PISGA0' if player.psprite_body.empty?
      return if player.psprite_sy > WEAPONTOP

      player.psprite_sy = WEAPONTOP
      start_ready(player, game)
    end

    def start_ready(player, game)
      player.psprite_state = 'ready'
      player.psprite_step = 0
      seq = WEAPON_READY[player.readyweapon]
      unless seq
        player.psprite_body = WEAPON_PATCH[player.readyweapon] || 'PISGA0'
        player.psprite_tics = 0
        return
      end
      body, tics, sfx = seq[0]
      player.psprite_body = body
      player.psprite_tics = tics
      game.start_sound(sfx) unless sfx.empty?
    end

    def tick_ready(player, game)
      seq = WEAPON_READY[player.readyweapon]
      unless seq
        player.psprite_body = WEAPON_PATCH[player.readyweapon] || 'PISGA0'
        return
      end
      if player.psprite_tics.positive?
        player.psprite_tics -= 1
        return if player.psprite_tics.positive?

        player.psprite_step = (player.psprite_step + 1) % seq.length
      end
      body, tics, sfx = seq[player.psprite_step]
      player.psprite_body = body
      player.psprite_tics = tics
      game.start_sound(sfx) unless sfx.empty?
    end

    def enter_atk_step(player, game, ammo_type, firing, can_fire)
      seq = WEAPON_ATK[player.readyweapon] || WEAPON_ATK[Defs::WP_PISTOL]
      loop do
        if player.psprite_step >= seq.length
          if firing && can_fire && player.pendingweapon == Defs::WP_NOCHANGE
            player.psprite_step = 0
            next
          end
          start_ready(player, game)
          unless firing
            player.attackdown = false
            player.refire = 0
          end
          return
        end
        step = seq[player.psprite_step]
        body, tics, do_fire, flash, flash_tics, light = step
        if step.length > 6 && step[6] && firing && can_fire && player.pendingweapon == Defs::WP_NOCHANGE && player.health.positive?
          player.psprite_step = 0
          next
        end
        player.psprite_body = body
        player.psprite_tics = tics
        if flash_tics != 0
          player.psprite_flash = flash
          player.flash_tics = flash_tics
        end
        player.extralight = light if light != 0
        do_shot(player, game, ammo_type) if do_fire
        return if tics.positive?

        player.psprite_step += 1
      end
    end

    def gun_shot(player, game, accurate)
      mo = player.mo
      slope = Collision.bullet_slope(game.world, mo)
      damage = 5 * ((Rng.p_random % 3) + 1)
      angle = mo.angle
      angle = Compat.as_u32(angle + (Rng.p_random - Rng.p_random) * 262_144) unless accurate
      Collision.line_attack(game.world, mo, damage, game, Defs::MISSILERANGE, angle, slope)
    end

    def do_shot(player, game, ammo_type)
      need = ammo_needed(player.readyweapon)
      if ammo_type
        return if player.ammo[ammo_type] < need

        player.ammo[ammo_type] -= need
      end
      mo = player.mo
      weapon = player.readyweapon
      if mo && [Defs::WP_MISSILE, Defs::WP_PLASMA, Defs::WP_BFG].include?(weapon)
        if weapon == Defs::WP_PLASMA
          player.psprite_flash = (Rng.p_random & 1) != 0 ? 'PLSFB0' : 'PLSFA0'
          player.flash_tics = 4
        end
        if weapon == Defs::WP_MISSILE
          Enemy.spawn_player_missile(game.world, mo, 'MISL', 20 * Defs::FRACUNIT, 20, 'rocket')
          game.start_sound('rlaunc')
        elsif weapon == Defs::WP_PLASMA
          Enemy.spawn_player_missile(game.world, mo, 'PLSS', 25 * Defs::FRACUNIT, 5, 'plasma')
          game.start_sound('plasma')
        else
          Enemy.spawn_player_missile(game.world, mo, 'BFS1', 25 * Defs::FRACUNIT, 100, 'bfg')
          game.start_sound('bfg')
        end
        player.refire += 1
        player.attackdown = true
        Enemy.noise_alert(game.world, mo, game)
        return
      end
      if mo && weapon == Defs::WP_FIST
        damage = ((Rng.p_random % 10) + 1) * 2
        damage *= 10 if player.powers[Defs::PW_STRENGTH] != 0
        angle = Compat.as_u32(mo.angle + (Rng.p_random - Rng.p_random) * 262_144)
        game.start_sound('punch') if Collision.line_attack(game.world, mo, damage, game, Defs::MELEERANGE, angle)
      elsif mo && weapon == Defs::WP_CHAINSAW
        damage = 2 * ((Rng.p_random % 10) + 1)
        angle = Compat.as_u32(mo.angle + (Rng.p_random - Rng.p_random) * 262_144)
        hit = Collision.line_attack(game.world, mo, damage, game, Defs::MELEERANGE + 1, angle)
        game.start_sound(hit ? 'sawhit' : 'sawful')
      elsif mo && weapon == Defs::WP_SHOTGUN
        game.start_sound('shotgn')
        7.times { gun_shot(player, game, false) }
      elsif mo && weapon == Defs::WP_SUPERSHOTGUN
        game.start_sound('dshtgn')
        slope = Collision.bullet_slope(game.world, mo)
        20.times do
          damage = 5 * ((Rng.p_random % 3) + 1)
          angle = Compat.as_u32(mo.angle + (Rng.p_random - Rng.p_random) * 524_288)
          pellet = slope + (Rng.p_random - Rng.p_random) * 32
          Collision.line_attack(game.world, mo, damage, game, Defs::MISSILERANGE, angle, pellet)
        end
      elsif mo
        game.start_sound('pistol')
        gun_shot(player, game, player.refire.zero?)
      end
      player.refire += 1
      player.attackdown = true
      Enemy.noise_alert(game.world, mo, game) if mo
    end
  end
end
