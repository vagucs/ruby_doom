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
# Seis gravacoes doomsav0.dsg a doomsav5.dsg.

require 'json'

module Doom
  module Saveg
    SAVE_MAGIC = 'DOOMRB01'.b

    module_function

    def save_dir(game)
      path = game.iwad_path.to_s
      dir = File.dirname(File.absolute_path(path)) unless path.empty?
      dir && !dir.empty? ? dir : Dir.pwd
    end

    def save_path(game, slot)
      File.join(save_dir(game), "#{Defs::SAVEGAMENAME}#{slot.to_i}.dsg")
    end

    def read_slot_description(game, slot)
      header = File.binread(save_path(game, slot), Defs::SAVESTRINGSIZE + SAVE_MAGIC.bytesize)
      return [Defs::LOADSAVEEMPTY, false] if header.nil? || header.bytesize < Defs::SAVESTRINGSIZE + SAVE_MAGIC.bytesize
      return [Defs::LOADSAVEEMPTY, false] unless header.byteslice(Defs::SAVESTRINGSIZE, SAVE_MAGIC.bytesize) == SAVE_MAGIC

      raw = header.byteslice(0, Defs::SAVESTRINGSIZE)
      cut = raw.index("\x00")
      raw = raw.byteslice(0, cut) if cut
      desc = raw.force_encoding('ISO-8859-1').encode('UTF-8', invalid: :replace, undef: :replace).rstrip
      [desc.empty? ? Defs::LOADSAVEEMPTY : desc, true]
    rescue SystemCallError
      [Defs::LOADSAVEEMPTY, false]
    end

    def write_save(game, slot, description)
      return false if game.world.nil? || game.player.nil?

      payload = JSON.generate(dump_state(game))
      text = description.to_s.encode('ISO-8859-1', invalid: :replace, undef: :replace).byteslice(0, Defs::SAVESTRINGSIZE)
      pad = text.to_s.b
      pad = pad.byteslice(0, Defs::SAVESTRINGSIZE)
      pad += "\x00".b * (Defs::SAVESTRINGSIZE - pad.bytesize)
      path = save_path(game, slot)
      tmp = "#{path}.tmp"
      File.binwrite(tmp, pad + SAVE_MAGIC + payload.b)
      File.delete(path) if File.exist?(path)
      File.rename(tmp, path)
      true
    rescue SystemCallError, JSON::GeneratorError
      false
    end

    def read_save(game, slot)
      data = File.binread(save_path(game, slot))
      need = Defs::SAVESTRINGSIZE + SAVE_MAGIC.bytesize
      return nil if data.bytesize < need || data.byteslice(Defs::SAVESTRINGSIZE, SAVE_MAGIC.bytesize) != SAVE_MAGIC

      JSON.parse(data.byteslice(need, data.bytesize - need).force_encoding('UTF-8'))
    rescue SystemCallError, JSON::ParserError, EncodingError
      nil
    end

    def dump_state(game)
      world = game.world
      specials = game.specials
      player = game.player
      mobjs = world.mobjs
      thinkers = []
      specials&.thinkers&.each do |th|
        next if th.dead

        rec = dump_thinker(th, world)
        thinkers << rec if rec
      end
      buttons = []
      specials&.buttons&.each do |btn|
        buttons << {
          'line' => btn.line.i_line, 'where' => btn.where, 'texture' => btn.texture, 'timer' => btn.timer
        }
      end
      {
        'episode' => game.episode, 'mapn' => game.mapn, 'skill' => game.skill, 'leveltime' => game.leveltime,
        'player' => dump_player(player),
        'sectors' => world.sectors.map do |s|
          {
            'floorheight' => s.floorheight, 'ceilingheight' => s.ceilingheight, 'floorpic' => s.floorpic,
            'ceilingpic' => s.ceilingpic, 'lightlevel' => s.lightlevel, 'special' => s.special
          }
        end,
        'sides' => world.sides.map do |sd|
          {
            'textureoffset' => sd.textureoffset, 'rowoffset' => sd.rowoffset, 'toptexture' => sd.toptexture,
            'bottomtexture' => sd.bottomtexture, 'midtexture' => sd.midtexture
          }
        end,
        'lines' => world.lines.map { |ln| { 'flags' => ln.flags, 'special' => ln.special } },
        'mobjs' => mobjs.map { |mo| dump_mobj(mo, mobjs) },
        'thinkers' => thinkers,
        'buttons' => buttons,
        'totalkills' => game.totalkills.to_i,
        'totalitems' => game.totalitems.to_i,
        'totalsecret' => game.totalsecret.to_i
      }
    end

    def apply(world, data)
      (data['sectors'] || []).each_with_index do |rec, i|
        break if i >= world.sectors.length

        s = world.sectors[i]
        s.floorheight = rec.fetch('floorheight', s.floorheight)
        s.ceilingheight = rec.fetch('ceilingheight', s.ceilingheight)
        s.floorpic = rec.fetch('floorpic', s.floorpic)
        s.ceilingpic = rec.fetch('ceilingpic', s.ceilingpic)
        s.lightlevel = rec.fetch('lightlevel', s.lightlevel)
        s.special = rec.fetch('special', s.special)
        s.specialdata = nil
      end
      (data['sides'] || []).each_with_index do |rec, i|
        break if i >= world.sides.length

        sd = world.sides[i]
        sd.textureoffset = rec.fetch('textureoffset', sd.textureoffset)
        sd.rowoffset = rec.fetch('rowoffset', sd.rowoffset)
        sd.toptexture = rec.fetch('toptexture', sd.toptexture)
        sd.bottomtexture = rec.fetch('bottomtexture', sd.bottomtexture)
        sd.midtexture = rec.fetch('midtexture', sd.midtexture)
      end
      (data['lines'] || []).each_with_index do |rec, i|
        break if i >= world.lines.length

        ln = world.lines[i]
        ln.flags = rec.fetch('flags', ln.flags)
        ln.special = rec.fetch('special', ln.special)
      end
      thinkers = []
      (data['thinkers'] || []).each do |rec|
        sec_i = rec['sector'].to_i
        next unless sec_i >= 0 && sec_i < world.sectors.length

        sector = world.sectors[sec_i]
        th = build_thinker(sector, rec)
        next unless th

        sector.specialdata = th
        thinkers << th
      end
      world.specials.thinkers = thinkers
      buttons = []
      (data['buttons'] || []).each do |rec|
        li = rec['line'].to_i
        next unless li >= 0 && li < world.lines.length

        buttons << Button.new(world.lines[li], rec['where'] || 'top', rec['texture'].to_i, rec['timer'].to_i)
      end
      world.specials.buttons = buttons
      recs = data['mobjs'] || []
      mobjs = recs.map { |rec| restore_mobj(rec) }
      mobjs.each_with_index do |mo, i|
        ti = recs[i]['target']
        mo.target = mobjs[ti] if ti.is_a?(Integer) && ti >= 0 && ti < mobjs.length
      end
      world.mobjs = mobjs
      player = nil
      mobjs.each_with_index do |mo, i|
        next unless recs[i]['is_player']

        player = restore_player(data['player'] || {}, mo)
        break
      end
      raise 'save sem jogador' if player.nil?

      mobjs.each { |mo| Collision.set_thing_position(world, mo) if mo.alive && mo.flags != 0 }
      player
    end

    def dump_player(player)
      {
        'playerstate' => player.playerstate, 'viewz' => player.viewz, 'viewheight' => player.viewheight,
        'deltaviewheight' => player.deltaviewheight, 'bob' => player.bob, 'health' => player.health,
        'armorpoints' => player.armorpoints, 'armortype' => player.armortype, 'ammo' => player.ammo,
        'maxammo' => player.maxammo, 'weaponowned' => player.weaponowned, 'pendingweapon' => player.pendingweapon,
        'readyweapon' => player.readyweapon, 'cards' => player.cards, 'cheats' => player.cheats,
        'message' => player.message, 'message_tics' => player.message_tics, 'attackdown' => player.attackdown,
        'usedown' => player.usedown, 'damagecount' => player.damagecount, 'bonuscount' => player.bonuscount,
        'extralight' => player.extralight, 'refire' => player.refire, 'killcount' => player.killcount,
        'itemcount' => player.itemcount, 'secretcount' => player.secretcount, 'didsecret' => player.didsecret,
        'psprite_y' => player.psprite_y, 'psprite_sy' => player.psprite_sy, 'psprite_state' => player.psprite_state,
        'psprite_tics' => player.psprite_tics, 'psprite_step' => player.psprite_step, 'psprite_body' => player.psprite_body,
        'psprite_flash' => player.psprite_flash, 'flash_tics' => player.flash_tics
      }
    end

    def dump_mobj(mo, mobjs)
      {
        'x' => mo.x, 'y' => mo.y, 'z' => mo.z, 'angle' => mo.angle, 'momx' => mo.momx, 'momy' => mo.momy,
        'momz' => mo.momz, 'radius' => mo.radius, 'height' => mo.height, 'floorz' => mo.floorz,
        'ceilingz' => mo.ceilingz, 'flags' => mo.flags, 'health' => mo.health, 'type' => mo.type,
        'sprite' => mo.sprite, 'info' => mo.info, 'alive' => mo.alive, 'reactiontime' => mo.reactiontime,
        'target' => mobjs.index(mo.target), 'movedir' => mo.movedir, 'movecount' => mo.movecount,
        'frame' => mo.frame, 'tics' => mo.tics, 'istate' => mo.istate, 'damage' => mo.damage,
        'doomednum' => mo.doomednum, 'threshold' => mo.threshold, 'is_player' => !mo.player.nil?
      }
    end

    def dump_thinker(th, world)
      sec_i = world.sectors.index(th.sector)
      return nil if sec_i.nil?

      if th.is_a?(VerticalDoor)
        { 'kind' => 'door', 'sector' => sec_i, 'type' => th.type, 'direction' => th.direction,
          'topheight' => th.topheight, 'speed' => th.speed, 'topwait' => th.topwait, 'topcountdown' => th.topcountdown }
      elsif th.is_a?(Plat)
        { 'kind' => 'plat', 'sector' => sec_i, 'type' => th.type, 'status' => th.status, 'speed' => th.speed,
          'low' => th.low, 'high' => th.high, 'wait' => th.wait, 'count' => th.count }
      elsif th.is_a?(FloorMove)
        { 'kind' => 'floor', 'sector' => sec_i, 'direction' => th.direction, 'dest' => th.dest, 'speed' => th.speed,
          'crush' => th.crush, 'floorpic' => th.floorpic }
      end
    end

    def build_thinker(sector, rec)
      case rec['kind']
      when 'door'
        VerticalDoor.new(sector: sector, type: rec['type'].to_i, direction: rec['direction'].to_i,
                         topheight: rec['topheight'].to_i, speed: rec['speed'].to_i, topwait: rec['topwait'].to_i,
                         topcountdown: rec['topcountdown'].to_i)
      when 'plat'
        Plat.new(sector: sector, type: rec['type'].to_i, status: rec['status'].to_i, speed: rec['speed'].to_i,
                 low: rec['low'].to_i, high: rec['high'].to_i, wait: rec['wait'].to_i, count: rec['count'].to_i)
      when 'floor'
        FloorMove.new(sector: sector, direction: rec['direction'].to_i, dest: rec['dest'].to_i, speed: rec['speed'].to_i,
                      crush: rec['crush'] ? true : false, floorpic: rec['floorpic'])
      end
    end

    def restore_mobj(rec)
      mo = Mobj.new
      %w[x y z angle momx momy momz radius height floorz ceilingz flags health type reactiontime movedir movecount
         frame tics istate damage doomednum threshold].each do |key|
        mo.send("#{key}=", rec[key]) if rec.key?(key)
      end
      mo.sprite = rec['sprite'].to_s
      mo.info = rec['info']
      mo.alive = rec.fetch('alive', true)
      mo
    end

    def restore_player(rec, mo)
      player = Player.new
      player.mo = mo
      %w[playerstate viewz viewheight deltaviewheight bob health armorpoints armortype pendingweapon readyweapon
         cheats message_tics damagecount bonuscount extralight refire killcount itemcount secretcount
         psprite_y psprite_sy psprite_tics psprite_step flash_tics].each do |key|
        player.send("#{key}=", rec[key]) if rec.key?(key)
      end
      player.ammo = rec['ammo'] if rec['ammo']
      player.maxammo = rec['maxammo'] if rec['maxammo']
      player.weaponowned = rec['weaponowned'] if rec['weaponowned']
      player.cards = rec['cards'] if rec['cards']
      player.message = rec['message'].to_s
      player.attackdown = rec['attackdown'] ? true : false
      player.usedown = rec['usedown'] ? true : false
      player.didsecret = rec['didsecret'] ? true : false
      player.psprite_state = rec['psprite_state'] || player.psprite_state
      player.psprite_body = rec['psprite_body'].to_s
      player.psprite_flash = rec['psprite_flash'].to_s
      mo.player = player
      mo.health = player.health
      player
    end
  end
end
