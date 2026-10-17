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
# Coleta: vida, municao, armadura, chaves, armas, poderes e mochila.

module Doom
  module Items
    CLIPAMMO = [10, 4, 20, 1].freeze
    PICKUP = {
      2011 => ['health', 10],
      2012 => ['health', 25],
      2014 => ['bonus_h', 1],
      2015 => ['bonus_a', 1],
      2018 => ['armor', 1],
      2019 => ['armor', 2],
      83 => ['mega', 0],
      2013 => ['soul', 0],
      2023 => ['berserk', 0],
      2022 => ['item', 'Invulnerability'],
      2024 => ['item', 'Partial invisibility'],
      2025 => ['item', 'Radiation shielding'],
      2026 => ['item', 'Computer area map'],
      2045 => ['item', 'Light amplification visor'],
      5 => ['key', Defs::IT_BLUECARD],
      6 => ['key', Defs::IT_YELLOWCARD],
      13 => ['key', Defs::IT_REDCARD],
      40 => ['key', Defs::IT_BLUESKULL],
      39 => ['key', Defs::IT_YELLOWSKULL],
      38 => ['key', Defs::IT_REDSKULL],
      2001 => ['weapon', Defs::WP_SHOTGUN],
      82 => ['weapon', Defs::WP_SUPERSHOTGUN],
      2002 => ['weapon', Defs::WP_CHAINGUN],
      2003 => ['weapon', Defs::WP_MISSILE],
      2004 => ['weapon', Defs::WP_PLASMA],
      2005 => ['weapon', Defs::WP_CHAINSAW],
      2006 => ['weapon', Defs::WP_BFG],
      2007 => ['ammo', [Defs::AM_CLIP, 1]],
      2048 => ['ammo', [Defs::AM_CLIP, 5]],
      2008 => ['ammo', [Defs::AM_SHELL, 1]],
      2049 => ['ammo', [Defs::AM_SHELL, 5]],
      2047 => ['ammo', [Defs::AM_CELL, 1]],
      17 => ['ammo', [Defs::AM_CELL, 5]],
      2010 => ['ammo', [Defs::AM_MISL, 1]],
      2046 => ['ammo', [Defs::AM_MISL, 5]],
      8 => ['backpack', 0]
    }.freeze
    WEAPON_NAMES = {
      Defs::WP_SHOTGUN => 'Voce pegou a escopeta!',
      Defs::WP_SUPERSHOTGUN => 'Voce pegou a super escopeta!',
      Defs::WP_CHAINGUN => 'Voce pegou a metralhadora!',
      Defs::WP_MISSILE => 'Voce pegou o lancador de foguetes!',
      Defs::WP_PLASMA => 'Voce pegou o rifle de plasma!',
      Defs::WP_BFG => 'Voce pegou a BFG9000!',
      Defs::WP_CHAINSAW => 'Uma motosserra! Ache carne!'
    }.freeze
    KEY_NAMES = {
      Defs::IT_BLUECARD => 'Voce pegou um cartao azul.',
      Defs::IT_YELLOWCARD => 'Voce pegou um cartao amarelo.',
      Defs::IT_REDCARD => 'Voce pegou um cartao vermelho.',
      Defs::IT_BLUESKULL => 'Voce pegou uma caveira azul.',
      Defs::IT_YELLOWSKULL => 'Voce pegou uma caveira amarela.',
      Defs::IT_REDSKULL => 'Voce pegou uma caveira vermelha.'
    }.freeze
    POWERS = {
      'Invulnerability' => [Defs::PW_INVULNERABILITY, 'Invulnerabilidade!'],
      'Partial invisibility' => [Defs::PW_INVISIBILITY, 'Invisibilidade parcial'],
      'Radiation shielding' => [Defs::PW_IRONFEET, 'Traje contra radiacao'],
      'Computer area map' => [Defs::PW_ALLMAP, 'Mapa do computador'],
      'Light amplification visor' => [Defs::PW_INFRARED, 'Visor de luz']
    }.freeze

    module_function

    def lookup(doomednum)
      PICKUP[doomednum]
    end

    def give_ammo(player, ammo, num)
      return false if player.ammo[ammo] >= player.maxammo[ammo]

      player.ammo[ammo] = [player.maxammo[ammo], player.ammo[ammo] + Deh.current.clipammo[ammo] * num].min
      true
    end

    def touch(game, special, toucher)
      player = toucher.player
      return if player.nil? || !special.alive

      kind, extra = if special.info && !special.info[0].to_s.empty?
                      special.info
                    else
                      lookup(special.doomednum) || ['deco', nil]
                    end
      taken = true
      sfx = 'itemup'
      case kind
      when 'health'
        if player.health >= Defs::MAXHEALTH
          taken = false
        else
          player.health = [Defs::MAXHEALTH, player.health + extra.to_i].min
          player.mo.health = player.health
          player.set_message(extra.to_i == 10 ? 'Voce pegou um estimulante.' : 'Voce pegou um kit medico.')
        end
      when 'bonus_h'
        player.health = [200, player.health + 1].min
        player.mo.health = player.health
        player.set_message('Voce pegou um bonus de vida.')
      when 'bonus_a'
        player.armorpoints = [200, player.armorpoints + 1].min
        player.armortype = 1 if player.armortype.zero?
        player.set_message('Voce pegou um bonus de armadura.')
      when 'armor'
        points = extra.to_i == 1 ? 100 : 200
        if player.armorpoints >= points
          taken = false
        else
          player.armorpoints = points
          player.armortype = extra.to_i
          player.set_message(extra.to_i == 1 ? 'Voce pegou a armadura.' : 'Voce pegou a mega-armadura.')
        end
      when 'soul'
        player.health = [200, player.health + 100].min
        player.mo.health = player.health
        player.set_message('Super carga!')
      when 'mega'
        player.health = 200
        player.mo.health = 200
        player.armorpoints = 200
        player.armortype = 2
        player.set_message('Megaesfera!')
      when 'berserk'
        taken = Actors.give_power(player, Defs::PW_STRENGTH)
        if taken
          player.pendingweapon = Defs::WP_FIST if player.readyweapon != Defs::WP_FIST
          player.set_message('Berserk!')
          sfx = 'getpow'
        end
      when 'key'
        player.cards[extra.to_i] = true
        player.set_message(KEY_NAMES[extra.to_i] || 'Voce pegou uma chave.')
      when 'weapon'
        weapon = extra.to_i
        player.weaponowned[weapon] = true
        player.pendingweapon = weapon if player.readyweapon != weapon
        if [Defs::WP_SHOTGUN, Defs::WP_SUPERSHOTGUN].include?(weapon)
          give_ammo(player, Defs::AM_SHELL, 1)
        elsif weapon == Defs::WP_CHAINGUN
          give_ammo(player, Defs::AM_CLIP, 1)
        elsif weapon == Defs::WP_MISSILE
          give_ammo(player, Defs::AM_MISL, 1)
        elsif [Defs::WP_PLASMA, Defs::WP_BFG].include?(weapon)
          give_ammo(player, Defs::AM_CELL, 1)
        end
        player.set_message(WEAPON_NAMES[weapon] || 'Voce pegou uma arma!')
        game.start_sound('wpnup')
      when 'ammo'
        ammo, num = extra
        taken = give_ammo(player, ammo, num)
        player.set_message('Voce pegou municao.') if taken
      when 'backpack'
        4.times do |i|
          player.maxammo[i] = player.maxammo[i] < 400 ? player.maxammo[i] * 2 : player.maxammo[i]
          give_ammo(player, i, 1)
        end
        player.set_message('Voce pegou uma mochila cheia de municao!')
      when 'item'
        pair = POWERS[extra.to_s]
        if pair.nil?
          player.set_message(extra.to_s)
        else
          power, msg = pair
          taken = Actors.give_power(player, power)
          if taken
            player.set_message(msg)
            sfx = 'getpow'
          end
        end
      else
        taken = false
      end
      return unless taken

      game.start_sound(sfx) unless kind == 'weapon'
      player.bonuscount += 6
      player.itemcount += 1 if (special.flags & Defs::MF_COUNTITEM) != 0
      Collision.unset_thing_position(game.world, special)
      special.alive = false
      special.flags = 0
      game.world.mobjs.delete(special)
    end
  end
end
