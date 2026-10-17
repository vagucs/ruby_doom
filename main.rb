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
# Esta etapa abre o mapa, os cheats, a gravacao, a configuracao, a demo e o DeHackEd.

$stdout.sync = true

require_relative 'lib/doom'

module Doom
  IWAD_NAMES = %w[
    DOOM1.WAD doom1.wad DOOM.WAD doom.wad DOOM2.WAD doom2.wad
    PLUTONIA.WAD TNT.WAD freedoom1.wad freedoom2.wad
  ].freeze
  KEY_ESCAPE = 27
  KEY_RETURN = 13
  KEY_KP_ENTER = 1_073_741_912
  KEY_RIGHT = 1_073_741_903
  KEY_LEFT = 1_073_741_904
  KEY_DOWN = 1_073_741_905
  KEY_UP = 1_073_741_906
  KEY_LSHIFT = 1_073_742_049
  KEY_RSHIFT = 1_073_742_053
  KEY_SPACE = 32
  KEY_E = 101
  KEY_LCTRL = 1_073_742_048
  KEY_RCTRL = 1_073_742_052
  KEY_LALT = 1_073_742_050
  KEY_RALT = 1_073_742_054
  KEY_COMMA = 44
  KEY_PERIOD = 46
  KEY_MINUS = 45
  KEY_EQUALS = 61
  KEY_PLUS = 43
  KEY_KP_MINUS = 1_073_741_910
  KEY_KP_PLUS = 1_073_741_911
  KEY_PAUSE = 1_073_741_896
  KEY_F11 = 1_073_741_892
  TIC_MS = 28

  module_function

  def check_math
    raise "ponto fixo #{Compat.fixed_mul(65536, 196608)}" unless Compat.fixed_mul(65536, 196608) == 196608
    raise "estouro #{Compat.as_i32(-1)}" unless Compat.as_i32(-1) == -1
    raise "negativo #{Compat.fixed_mul(-65536, 2)}" unless Compat.fixed_mul(-65536, 2) == -2
  end

  def find_iwad(explicit)
    if explicit
      return explicit if File.file?(explicit)

      raise "IWAD nao encontrado: #{explicit}"
    end

    env = ENV.fetch('DOOMWADDIR', nil) || ENV.fetch('DOOMWADPATH', nil)
    here = File.expand_path(__dir__)
    roots = [Dir.pwd, here, File.dirname(here), File.dirname(File.dirname(here))]
    roots.unshift(env) if env
    roots.each do |root|
      IWAD_NAMES.each do |name|
        path = File.join(root, name)
        return path if File.file?(path)
      end
    end
    raise 'Nenhum IWAD. Coloque doom1.wad nesta pasta ou passe -iwad arquivo.wad'
  end

  def parse_args(argv)
    opt = {
      iwad: nil, warp: false, episode: 1, mapn: 1, skill: nil, fast: false, respawn: false,
      nomonsters: false, pwads: [], deh: [], nodeh: false, nocheats: false,
      record: nil, playdemo: nil, timedemo: nil, fps: false
    }
    i = 0
    while i < argv.length
      arg = argv[i].to_s
      if arg.casecmp('-iwad').zero?
        i += 1
        opt[:iwad] = argv[i]
      elsif arg.casecmp('-warp').zero?
        opt[:warp] = true
        if i + 2 < argv.length && argv[i + 1].to_s.match?(/\A\d+\z/) && argv[i + 2].to_s.match?(/\A\d+\z/)
          opt[:episode] = argv[i + 1].to_i
          opt[:mapn] = argv[i + 2].to_i
          i += 2
        end
      elsif arg.casecmp('-skill').zero?
        i += 1
        opt[:skill] = argv[i].to_i
      elsif arg.casecmp('-fast').zero?
        opt[:fast] = true
      elsif arg.casecmp('-respawn').zero?
        opt[:respawn] = true
      elsif arg.casecmp('-nomonsters').zero?
        opt[:nomonsters] = true
      elsif arg.casecmp('-file').zero?
        i += 1
        i += 1 while i < argv.length && !argv[i].to_s.start_with?('-') && opt[:pwads] << argv[i]
        next
      elsif arg.casecmp('-deh').zero?
        i += 1
        i += 1 while i < argv.length && !argv[i].to_s.start_with?('-') && opt[:deh] << argv[i]
        next
      elsif arg.casecmp('-nodeh').zero?
        opt[:nodeh] = true
      elsif arg.casecmp('-nocheats').zero?
        opt[:nocheats] = true
      elsif arg.casecmp('-record').zero?
        i += 1
        opt[:record] = argv[i]
      elsif arg.casecmp('-playdemo').zero?
        i += 1
        opt[:playdemo] = argv[i]
      elsif arg.casecmp('-fps').zero?
        opt[:fps] = true
      elsif arg.casecmp('-timedemo').zero?
        i += 1
        opt[:timedemo] = argv[i]
      elsif arg.downcase.end_with?('.wad') && !arg.start_with?('-')
        opt[:iwad] = arg
      end
      i += 1
    end
    opt
  end

  def open_level(wad, sound, episode = 1, mapn = 1, skill = Defs::SK_MEDIUM, screen = 7, detail = 0, carry = nil)
    play = Play.new
    play.skill = skill
    play.fastparm = @fastparm ? true : false
    play.respawnparm = @respawnparm ? true : false
    play.nomonsters = @nomonsters ? true : false
    Thinker.apply_fast(play)
    res = Resources.new(wad)
    res.init
    world = World.new
    world.setup_level(wad, res, episode, mapn)
    start = world.player_start
    raise 'sem ponto de partida' unless start

    player = Actors.spawn_player(world, start)
    kills, items = Things.spawn_map_things(world, skill, play)
    Rng.reset
    Enemy.reset_brain
    world.specials = Specials.new(world, res, sound)
    play.episode = episode
    play.mapn = mapn
    play.totalkills = kills
    play.totalitems = items
    play.totalsecret = world.sectors.count { |sector| sector.special == 9 }
    carry_player(player, carry) if carry
    player.killcount = 0
    player.itemcount = 0
    player.secretcount = 0
    play.wad = wad
    play.res = res
    play.world = world
    play.player = player
    play.specials = world.specials
    play.sound = sound
    sound&.play_level(episode, mapn)
    renderer = Renderer.new(res)
    renderer.set_view_size(screen + 3, detail)
    status = StatusBar.new(wad)
    status.reset(player)
    [world, player, renderer, play, status]
  end

  def carry_player(player, prev)
    player.health = prev.health
    player.mo.health = prev.health if player.mo
    player.armorpoints = prev.armorpoints
    player.armortype = prev.armortype
    player.ammo = prev.ammo.dup
    player.maxammo = prev.maxammo.dup
    player.weaponowned = prev.weaponowned.dup
    player.pendingweapon = Defs::WP_NOCHANGE
    player.readyweapon = prev.readyweapon
    player.psprite_state = 'up'
    player.psprite_sy = 128 * Defs::FRACUNIT
    player.psprite_body = ''
    player.cheats = prev.cheats
    player.didsecret = prev.didsecret
    player.cards = [false] * 6
    player.powers = [0] * 6
    player.damagecount = 0
    player.bonuscount = 0
    player.extralight = 0
    player.playerstate = Defs::PST_LIVE
  end

  def commercial?(wad)
    wad.check_num_for_name('MAP01') >= 0
  end

  def next_map_number(play, secret, commercial)
    mapn = play.mapn
    nxt = if commercial
            if secret && mapn == 15
              30
            elsif secret && mapn == 31
              31
            elsif [31, 32].include?(mapn)
              15
            else
              mapn
            end
          elsif secret
            8
          elsif mapn == 9
            { 1 => 3, 2 => 5, 3 => 6, 4 => 2 }[play.episode] || 0
          else
            mapn
          end
    nxt + 1
  end

  def draw_level(world, player, renderer, status, show_messages = true, automap = nil, play = nil)
    fb = VVideo.blank
    if automap&.active && play
      automap.drawer(fb, play)
      status&.draw(fb, player, show_messages: show_messages)
      return fb
    end
    mo = player.mo
    renderer.setup_frame(mo.x, mo.y, player.viewz, mo.angle, player.extralight, player.fixedcolormap)
    renderer.render(world, fb)
    Sprites.draw(renderer, world, fb)
    renderer.draw_masked
    Sprites.draw_weapon(renderer, player, fb, world.leveltime || 0)
    status.draw(fb, player, show_messages: show_messages) if status && renderer.viewheight < Defs::SCREENHEIGHT
    fb
  end

  def restore_save(wad, sound, data, screen, detail, iwad_path)
    episode = data['episode'].to_i
    mapn = data['mapn'].to_i
    skill = data['skill'].to_i
    play = Play.new
    play.skill = skill
    play.fastparm = @fastparm ? true : false
    play.respawnparm = @respawnparm ? true : false
    play.nomonsters = @nomonsters ? true : false
    Thinker.apply_fast(play)
    res = Resources.new(wad)
    res.init
    world = World.new
    world.setup_level(wad, res, episode, mapn)
    world.specials = Specials.new(world, res, sound)
    player = Saveg.apply(world, data)
    play.episode = episode
    play.mapn = mapn
    play.leveltime = data['leveltime'].to_i
    play.totalkills = data['totalkills'].to_i
    play.totalitems = data['totalitems'].to_i
    play.totalsecret = data['totalsecret'].to_i
    play.wad = wad
    play.res = res
    play.world = world
    play.player = player
    play.specials = world.specials
    play.sound = sound
    play.iwad_path = iwad_path
    sound&.play_level(episode, mapn)
    renderer = Renderer.new(res)
    renderer.set_view_size(screen + 3, detail)
    status = StatusBar.new(wad)
    status.reset(player)
    [world, player, renderer, play, status, play.leveltime]
  end

  def feed_cheat(ch, player, play, wad, sound, automap, start_level)
    return if play.nil? || player.nil?
    return unless ch.length == 1 && (ch.match?(/[a-z]/) || ch.match?(/\d/))

    nightmare = play.skill == Defs::SK_NIGHTMARE
    Deh.current.cheats.each do |cheat|
      param = cheat.feed(ch)
      next if param.nil?
      next if nightmare && !%w[clev iddt].include?(cheat.action)

      do_cheat(cheat.action, param, player, play, wad, sound, automap, start_level)
    end
  end

  def do_cheat(action, param, player, play, wad, sound, automap, start_level)
    deh = Deh.current
    case action
    when 'god'
      player.cheats ^= Defs::CF_GODMODE
      if (player.cheats & Defs::CF_GODMODE) != 0
        player.health = deh.god_mode_health
        player.mo.health = deh.god_mode_health if player.mo
        player.set_message('Degreelessness Mode On')
      else
        player.set_message('Degreelessness Mode Off')
      end
    when 'kfa', 'fa'
      keys = action == 'kfa'
      player.armorpoints = keys ? deh.idkfa_armor : deh.idfa_armor
      player.armortype = keys ? deh.idkfa_armor_class : deh.idfa_armor_class
      player.weaponowned = [true] * player.weaponowned.length
      player.maxammo = deh.maxammo.dup
      player.ammo = player.maxammo.dup
      player.cards = [true] * 6 if keys
      player.set_message(keys ? 'Very Happy Ammo Added' : 'Ammo Added')
    when 'noclip', 'noclip2'
      player.cheats ^= Defs::CF_NOCLIP
      if (player.cheats & Defs::CF_NOCLIP) != 0
        player.mo.flags |= Defs::MF_NOCLIP
        player.set_message('No Clipping Mode ON')
      else
        player.mo.flags &= ~Defs::MF_NOCLIP
        player.set_message('No Clipping Mode OFF')
      end
    when 'iddt'
      automap.cycle_iddt if automap&.active
    when 'behold'
      player.set_message('invin visis rad allmap lite amp')
    when 'choppers'
      player.weaponowned[Defs::WP_CHAINSAW] = true
      player.pendingweapon = Defs::WP_CHAINSAW
      player.powers[0] = 1
      player.set_message("... doesn't suck - GM")
    when 'mypos'
      mo = player.mo
      player.set_message("ang=0x#{(mo.angle & 0xFFFFFFFF).to_s(16)};x,y=(0x#{mo.x.to_s(16)},0x#{mo.y.to_s(16)})")
    when 'clev'
      cheat_clev(param, play, wad, start_level, player)
    when 'mus'
      cheat_mus(param, play, wad, sound, player)
    else
      if action.start_with?('behold') && action.length == 7
        pw = 'vsiral'.index(action[6])
        cheat_behold(player, pw) if pw
      end
    end
  end

  def cheat_behold(player, pw)
    return if pw.negative?

    if player.powers[pw].zero?
      Actors.give_power(player, pw)
      player.pendingweapon = Defs::WP_FIST if pw == Defs::PW_STRENGTH && player.readyweapon != Defs::WP_FIST
    elsif pw == Defs::PW_STRENGTH
      player.powers[pw] = 0
    else
      player.powers[pw] = 1
    end
    player.set_message('Power-up Toggled')
  end

  def cheat_clev(param, play, wad, start_level, player)
    return if param.length < 2 || !param.match?(/\A\d\d/)

    a = param[0].to_i
    b = param[1].to_i
    if commercial?(wad)
      episode = 1
      mapn = (a * 10) + b
      lump = format('MAP%02d', mapn)
    else
      episode = a
      mapn = b
      lump = "E#{episode}M#{mapn}"
    end
    return if episode < 1 || mapn < 1 || wad.check_num_for_name(lump).negative?

    player.set_message('Changing Level...')
    start_level.call(play.skill, episode, mapn)
  end

  def cheat_mus(param, play, wad, sound, player)
    return if param.length < 2 || !param.match?(/\A\d\d/)

    a = param[0].to_i
    b = param[1].to_i
    if commercial?(wad)
      mapn = (a * 10) + b
      if mapn < 1 || mapn > Sound::DOOM2_MUSIC.length
        player.set_message('IMPOSSIBLE SELECTION')
        return
      end
      name = Sound::DOOM2_MUSIC[mapn - 1]
    else
      if a < 1 || b < 1 || b > 9
        player.set_message('IMPOSSIBLE SELECTION')
        return
      end
      name = "e#{a}m#{b}"
    end
    unless sound.has_music(name)
      player.set_message('IMPOSSIBLE SELECTION')
      return
    end
    sound.change_music(name, true)
    player.set_message('Music Change')
    play
  end

  def draw_fps(fb, wad, text, cache)
    glyphs = []
    width = 0
    text.upcase.each_char do |ch|
      if ch == ' '
        glyphs << nil
        width += 4
        next
      end
      code = ch.ord
      patch = cache[code]
      if patch.nil?
        number = wad.check_num_for_name(format('STCFN%03d', code))
        patch = number.negative? ? false : wad.cache_lump_num(number)
        cache[code] = patch
      end
      glyphs << patch
      width += patch ? VVideo.patch_size(patch)[0] : 4
    end
    x = Defs::SCREENWIDTH - 4 - width
    x = 0 if x.negative?
    glyphs.each do |patch|
      if patch
        VVideo.draw_patch(fb, x, 1, patch)
        x += VVideo.patch_size(patch)[0]
      else
        x += 4
      end
    end
  end

  def draw_pause(fb, wad, renderer)
    number = wad.check_num_for_name('M_PAUSE')
    return if number.negative?

    patch = wad.cache_lump_num(number)
    width, height = VVideo.patch_size(patch)
    x = renderer.viewwindowx + ((renderer.scaledviewwidth - width) / 2)
    y = renderer.viewwindowy + ((renderer.viewheight - height) / 2)
    VVideo.draw_patch(fb, x, y, patch)
  end

  def build_cmd(video, turnheld, player = nil, session = nil)
    cmd = Ticcmd.new
    speed = video.down?(KEY_LSHIFT) || video.down?(KEY_RSHIFT) ? 1 : 0
    strafe = video.down?(KEY_LALT) || video.down?(KEY_RALT)
    turning = !strafe && (video.down?(KEY_RIGHT) || video.down?(KEY_LEFT))
    turnheld = turning ? turnheld + 1 : 0
    tspeed = turnheld < 6 ? 2 : speed
    if strafe
      cmd.sidemove += SIDEMOVE[speed] if video.down?(KEY_RIGHT)
      cmd.sidemove -= SIDEMOVE[speed] if video.down?(KEY_LEFT)
    else
      cmd.angleturn -= ANGLETURN[tspeed] if video.down?(KEY_RIGHT)
      cmd.angleturn += ANGLETURN[tspeed] if video.down?(KEY_LEFT)
    end
    cmd.forwardmove += FORWARDMOVE[speed] if video.down?(KEY_UP)
    cmd.forwardmove -= FORWARDMOVE[speed] if video.down?(KEY_DOWN)
    cmd.sidemove -= SIDEMOVE[speed] if video.down?(KEY_COMMA)
    cmd.sidemove += SIDEMOVE[speed] if video.down?(KEY_PERIOD)
    cmd.buttons |= Defs::BT_USE if video.down?(KEY_SPACE) || video.down?(KEY_E)
    cmd.buttons |= Defs::BT_ATTACK if video.down?(KEY_LCTRL) || video.down?(KEY_RCTRL)
    if video.down?(49)
      w1 = if player && player.readyweapon == Defs::WP_CHAINSAW
             Defs::WP_FIST
           elsif player && player.weaponowned[Defs::WP_CHAINSAW]
             Defs::WP_CHAINSAW
           else
             Defs::WP_FIST
           end
      cmd.buttons |= Defs::BT_CHANGE | (w1 << Defs::BT_WEAPONSHIFT)
    else
      { 50 => Defs::WP_PISTOL, 51 => Defs::WP_SHOTGUN, 52 => Defs::WP_CHAINGUN,
        53 => Defs::WP_MISSILE, 54 => Defs::WP_PLASMA, 55 => Defs::WP_BFG }.each do |key, weapon|
        next unless video.down?(key)

        cmd.buttons |= Defs::BT_CHANGE | (weapon << Defs::BT_WEAPONSHIFT)
        break
      end
    end
    if session&.use_mouse
      mx, my = video.take_mouse
      sens = (session.mouse_sensitivity + 5) / 10.0
      mx = (mx * sens).to_i
      my = (my * sens).to_i
      cmd.forwardmove = (cmd.forwardmove + my).clamp(-127, 127)
      if strafe
        cmd.sidemove = (cmd.sidemove + (mx * 2)).clamp(-127, 127)
      else
        cmd.angleturn -= mx * 8
      end
      cmd.buttons |= Defs::BT_ATTACK if video.mouse_fire
    else
      video.take_mouse
    end
    [cmd, turnheld]
  end

  def run(argv)
    check_math
    opt = parse_args(argv)
    @fastparm = opt[:fast]
    @respawnparm = opt[:respawn]
    @nomonsters = opt[:nomonsters]
    path = find_iwad(opt[:iwad])
    puts "IWAD: #{path}"
    wad = Wad.new
    wad.add_file(path)
    opt[:pwads].each do |extra|
      puts "PWAD: #{extra}"
      wad.add_file(extra)
    end
    Deh.current.nodeh = opt[:nodeh]
    Deh.current.apply_cheats = !opt[:nocheats]
    Deh.current.files = opt[:deh]
    Deh.current.load_after_iwad(wad)
    title = wad.cache_lump_name('TITLEPIC')
    pal = wad.cache_lump_name('PLAYPAL')
    title_fb = VVideo.blank
    VVideo.draw_patch(title_fb, 0, 0, title)
    credit_num = wad.check_num_for_name('CREDIT')
    credit_num = wad.check_num_for_name('HELP2') if credit_num.negative?
    credit_fb = title_fb
    if credit_num >= 0
      credit_fb = VVideo.blank
      VVideo.draw_patch(credit_fb, 0, 0, wad.cache_lump_num(credit_num))
    end
    world = player = renderer = play = status = nil
    leveltime = 0
    turnheld = 0
    paused = false
    mode = :title
    fb = title_fb
    video = Video.new
    video.init
    video.set_palette(pal)
    sound = Sound.new
    sound.init(wad, video)
    session = MenuGame.new
    session.sound = sound
    session.iwad_path = path
    Config.load(session)
    menu = Menu.new(wad, sound, session)
    automap = Automap.new
    demo_play = nil
    demo_rec = nil
    demo_playback = false
    demo_recording = !opt[:record].nil?
    demo_sequence = -1
    advancedemo = opt[:playdemo].nil? && opt[:timedemo].nil? && !opt[:warp]
    page_tic = 0
    page_kind = :title
    shown_page = :title
    singledemo = !opt[:playdemo].nil? || !opt[:timedemo].nil?
    timingdemo = !opt[:timedemo].nil?
    gametic = 0
    timedemo_start = 0
    fps_on = opt[:fps]
    fps_frames = 0
    fps_value = 0
    fps_ready = false
    fps_stamp = 0
    fps_font = {}
    start_level = lambda do |skill, episode, mapn, carry = nil, playback = false|
      puts "entrando no E#{episode}M#{mapn}"
      world, player, renderer, play, status = open_level(
        wad, sound, episode, mapn, skill, session.screen_size, session.detail_level, carry
      )
      play.iwad_path = path
      automap.reset_level
      session.player = player
      session.in_level = true
      mode = :level
      paused = false
      demo_playback = playback
      advancedemo = false
      leveltime = 0
      clock = video.ticks
      video.release_keys
      if demo_recording && !playback && demo_rec.nil?
        demo_rec = Demo.begin_record(skill, episode, mapn, @respawnparm, @fastparm, @nomonsters)
      end
    end
    back_to_title = lambda do
      mode = :title
      page_kind = :title
      paused = false
      demo_playback = false
      demo_play = nil
      world = nil
      player = nil
      session.player = nil
      session.in_level = false
      automap.reset_level
      menu.clear
      demo_sequence = -1
      advancedemo = true
      sound.play_title
      video.release_keys
    end
    inter = nil
    finale = nil
    next_mapn = 1
    wipe = Wipe.new
    shown_mode = :title
    force_wipe = false
    finish_level = lambda do
      secret = world.specials&.secret_exit ? true : false
      player.didsecret = true if secret || play.mapn == 9
      is_commercial = commercial?(wad)
      if !is_commercial && play.mapn == 8
        finale = Finale.new(wad, sound, play.res, play.episode, play.mapn, path)
        inter = nil
        mode = :finale
        return
      end
      next_mapn = next_map_number(play, secret, is_commercial)
      stats = WbStart.new(
        epsd: play.episode - 1, last: play.mapn - 1, nxt: next_mapn - 1,
        maxkills: play.totalkills.zero? ? 1 : play.totalkills,
        maxitems: play.totalitems.zero? ? 1 : play.totalitems,
        maxsecret: play.totalsecret.zero? ? 1 : play.totalsecret,
        partime: partime(play.episode, play.mapn, is_commercial),
        skills: player.killcount, sitems: player.itemcount, ssecret: player.secretcount,
        stime: leveltime, didsecret: player.didsecret, commercial: is_commercial
      )
      player.cards = [false] * 6
      player.damagecount = 0
      player.bonuscount = 0
      player.extralight = 0
      inter = Intermission.new(wad, sound, stats)
      finale = nil
      mode = :inter
    end
    go_next = lambda do |from_finale|
      secret = world.specials&.secret_exit ? true : false
      if !from_finale && commercial?(wad) && FinaleText.commercial_finale?(play.mapn, secret)
        finale = Finale.new(wad, sound, play.res, play.episode, play.mapn, path)
        inter = nil
        mode = :finale
        return
      end
      lump = commercial?(wad) ? format('MAP%02d', next_mapn) : "E#{play.episode}M#{next_mapn}"
      if wad.check_num_for_name(lump).negative?
        back_to_title.call
      else
        kept = player
        start_level.call(play.skill, play.episode, next_mapn, kept)
        inter = nil
        finale = nil
      end
    end
    session.on_new_game = start_level
    session.on_title = back_to_title
    session.on_view = lambda do
      renderer&.set_view_size(session.screen_size + 3, session.detail_level)
    end
    session.on_save = lambda do |slot, description|
      next false unless mode == :level && play && player

      play.leveltime = leveltime
      ok = Saveg.write_save(play, slot, description)
      player.set_message('game saved.') if ok
      ok
    end
    session.on_load = lambda do |slot|
      data = Saveg.read_save(session, slot)
      next false unless data

      world, player, renderer, play, status, leveltime = restore_save(
        wad, sound, data, session.screen_size, session.detail_level, path
      )
      automap.reset_level
      session.player = player
      session.in_level = true
      mode = :level
      demo_playback = false
      advancedemo = false
      paused = false
      clock = video.ticks
      player.set_message('game loaded.')
      puts "Loaded E#{play.episode}M#{play.mapn}"
      true
    end
    advance_demo = lambda do
      advancedemo = false
      demo_playback = false
      demo_sequence = (demo_sequence + 1) % 6
      commercial = commercial?(wad)
      case demo_sequence
      when 0
        page_tic = commercial ? Defs::TICRATE * 11 : 170
        page_kind = :title
        mode = :title
        session.in_level = false
        sound.play_title
      when 2
        page_tic = 200
        page_kind = :credit
        mode = :title
        session.in_level = false
      when 4
        page_tic = commercial ? Defs::TICRATE * 11 : 200
        page_kind = :title
        mode = :title
        session.in_level = false
        sound.play_title if commercial
      else
        name = { 1 => 'demo1', 3 => 'demo2', 5 => 'demo3' }[demo_sequence]
        raw = Demo.load_bytes(wad, name)
        if raw.nil? || raw.bytesize < 13
          advancedemo = true
        else
          demo_play = Demo.new(raw)
          skill, episode, mapn = demo_play.header
          skill = Defs::SK_MEDIUM unless skill <= 4
          episode = 1 if episode < 1
          mapn = 1 if mapn < 1
          start_level.call(skill, episode, mapn, nil, true)
          timedemo_start = video.ticks if timingdemo
          gametic = 0
        end
      end
    end
    skill0 = opt[:skill].nil? ? Defs::SK_MEDIUM : opt[:skill]
    if opt[:timedemo] || opt[:playdemo]
      raw = Demo.load_bytes(wad, opt[:timedemo] || opt[:playdemo])
      if raw && raw.bytesize >= 13
        demo_play = Demo.new(raw)
        skill, episode, mapn = demo_play.header
        start_level.call(skill <= 4 ? skill : skill0, episode < 1 ? 1 : episode, mapn < 1 ? 1 : mapn, nil, true)
        timedemo_start = video.ticks if timingdemo
      else
        puts 'demo nao encontrada'
        start_level.call(skill0, opt[:episode], opt[:mapn])
      end
    elsif opt[:warp]
      start_level.call(skill0, opt[:episode], opt[:mapn])
    else
      sound.play_title
    end
    clock = video.ticks
    menu_clock = clock
    running = true
    while running && session.running
      video.poll.each do |key|
        if key.is_a?(Array)
          automap.release_key(key[1])
          next
        end
        if key.negative?
          running = false
          next
        end
        if (key == KEY_RETURN || key == KEY_KP_ENTER) && (video.down?(KEY_LALT) || video.down?(KEY_RALT))
          video.toggle_fullscreen
          next
        end
        typed = key.between?(32, 126) ? key.chr : ''
        next if menu.responder(key, typed)
        next if automap.responder(key, play)
        if key == KEY_F11
          fps_on = !fps_on
          next
        end

        if [KEY_EQUALS, KEY_KP_PLUS, KEY_PLUS].include?(key) || [KEY_MINUS, KEY_KP_MINUS].include?(key)
          grow = [KEY_EQUALS, KEY_KP_PLUS, KEY_PLUS].include?(key)
          changed = false
          if grow && session.screen_size < 8
            session.screen_size += 1
            changed = true
          elsif !grow && session.screen_size.positive?
            session.screen_size -= 1
            changed = true
          end
          if changed
            session.apply_view_size
            sound.play('stnmov')
            if mode == :level && world && player && renderer
              fb = draw_level(world, player, renderer, status, session.show_messages, automap, play)
            end
          end
        elsif mode == :finale && finale && [KEY_LCTRL, KEY_RCTRL, KEY_SPACE, KEY_E, KEY_RETURN, KEY_KP_ENTER].include?(key)
          finale.cast_hit
        elsif demo_playback || mode == :title
          skill_now = play ? play.skill : (opt[:skill] || Defs::SK_MEDIUM)
          episode_now = play ? play.episode : opt[:episode]
          map_now = play ? play.mapn : opt[:mapn]
          start_level.call(skill_now, episode_now, map_now)
        elsif key == KEY_PAUSE && mode == :level
          paused = !paused
          video.release_keys
        elsif mode == :level && player
          feed_cheat(typed.downcase, player, play, wad, sound, automap, start_level)
        end
      end
      video.set_relative_mouse(session.use_mouse && mode == :level && !menu.active && !paused && !demo_playback)
      steps = 0
      advance_demo.call if advancedemo && !wipe.active
      if wipe.active
        now = video.ticks
        while now - clock >= TIC_MS && steps < 6 && wipe.active
          wipe.tick(1, fb)
          clock += TIC_MS
          steps += 1
        end
        clock = now if steps == 6 && now - clock > TIC_MS * 2
      elsif mode == :level && !paused
        now = video.ticks
        while now - clock >= TIC_MS && steps < 6
          menu.ticker
          player.cmd, turnheld = if demo_playback
                                   cmd = demo_play&.read_cmd
                                   if cmd.nil?
                                     demo_playback = false
                                     if singledemo
                                       if timingdemo
                                         real = [1, ((video.ticks - timedemo_start) * Defs::TICRATE) / 1000].max
                                         puts "timed #{gametic} gametics in #{real} realtics"
                                       end
                                       running = false
                                     else
                                       advancedemo = true
                                       mode = :title
                                       session.in_level = false
                                     end
                                     break
                                   end
                                   gametic += 1
                                   [cmd, turnheld]
                                 elsif menu.active
                                   [Ticcmd.new, turnheld]
                                 else
                                   cmd, held = build_cmd(video, turnheld, player, session)
                                   demo_rec.write_cmd(cmd) if demo_recording && demo_rec
                                   [cmd, held]
                                 end
          play.leveltime = leveltime
          world.leveltime = leveltime
          Actors.think(world, player, leveltime, play)
          if player.playerstate == Defs::PST_REBORN
            puts 'renascendo'
            start_level.call(play.skill, play.episode, play.mapn)
            break
          end
          Enemy.tick(world, play)
          world.specials&.tick
          automap.ticker(play)
          status&.ticker(player)
          if world.specials&.exit_requested
            puts world.specials.secret_exit ? 'saida secreta' : 'fase concluida'
            sound.play('swtchx')
            finish_level.call
            break
          end
          leveltime += 1
          clock += TIC_MS
          steps += 1
        end
        clock = now if steps == 6 && now - clock > TIC_MS * 2
      elsif !wipe.active && (mode == :inter || mode == :finale)
        now = video.ticks
        skip = !menu.active && (video.down?(KEY_LCTRL) || video.down?(KEY_RCTRL) || video.down?(KEY_SPACE) ||
          video.down?(KEY_E) || video.down?(KEY_RETURN) || video.down?(KEY_KP_ENTER))
        while now - clock >= TIC_MS && steps < 6
          menu.ticker
          if mode == :inter && inter
            inter.ticker(menu: menu.active, attack: video.down?(KEY_LCTRL) || video.down?(KEY_RCTRL),
                         use: video.down?(KEY_SPACE) || video.down?(KEY_E),
                         enter: video.down?(KEY_RETURN) || video.down?(KEY_KP_ENTER), player: player)
            if inter.done
              go_next.call(false)
              break
            end
          elsif mode == :finale && finale
            finale.ticker(skip)
            force_wipe = true if finale.force_wipe
            finale.force_wipe = false
            if finale.done
              finale.action == 'title' ? back_to_title.call : go_next.call(true)
              break
            end
          end
          clock += TIC_MS
          steps += 1
        end
        clock = now if steps == 6 && now - clock > TIC_MS * 2
      elsif menu.active
        now = video.ticks
        while now - menu_clock >= TIC_MS && steps < 6
          menu.ticker
          menu_clock += TIC_MS
          steps += 1
        end
        menu_clock = now if now - menu_clock > TIC_MS * 2
      elsif mode == :title && !wipe.active
        now = video.ticks
        while now - clock >= TIC_MS && steps < 6
          menu.ticker if menu.active
          page_tic -= 1
          if page_tic.negative?
            advancedemo = true
            break
          end
          clock += TIC_MS
          steps += 1
        end
        clock = now if steps == 6 && now - clock > TIC_MS * 2
      end
      unless wipe.active
        fresh = nil
        if mode == :level && steps.positive? && world && player && renderer
          fresh = draw_level(world, player, renderer, status, session.show_messages, automap, play)
        elsif mode == :inter && inter && steps.positive?
          fresh = VVideo.blank
          inter.draw(fresh)
        elsif mode == :finale && finale && steps.positive?
          fresh = VVideo.blank
          finale.draw(fresh)
        elsif mode == :title && (shown_mode != :title || shown_page != page_kind)
          fresh = page_kind == :credit ? credit_fb : title_fb
        end
        if fresh && (mode != shown_mode || force_wipe || (mode == :title && shown_page != page_kind))
          force_wipe = false
          wipe.capture_start(fb)
          wipe.capture_end(fresh)
          wipe.begin_wipe(fb)
          shown_mode = mode
          shown_page = page_kind
        elsif fresh
          fb = fresh
          shown_mode = mode
          shown_page = page_kind
        end
      end
      shown = fb
      if (paused && mode == :level) || menu.active
        shown = fb.dup
        draw_pause(shown, wad, renderer) if paused && mode == :level && renderer
        menu.draw(shown)
      end
      index = mode == :level && status && player ? status.palette_index(player) : 0
      video.set_palette(pal.byteslice(index * 768, 768))
      if fps_on
        fps_stamp = video.ticks if fps_stamp.zero?
        fps_frames += 1
        gone = (video.ticks - fps_stamp) & 0xFFFFFFFF
        if gone >= 1000
          fps_value = fps_frames
          fps_frames = 0
          fps_stamp = video.ticks
          fps_ready = true
        end
        if fps_ready
          shown = shown.dup if shown.equal?(fb)
          draw_fps(shown, wad, "#{fps_value} FPS", fps_font)
        end
      end
      video.present(shown)
      sound.update
      video.delay(steps.positive? ? 1 : 16)
    end
  ensure
    if demo_recording && demo_rec && opt && opt[:record]
      file = demo_rec.finish(opt[:record])
      puts "Demo #{file} recorded"
    end
    Config.save(session) if session
    sound&.stop_music
    video&.shutdown
  end
end

if __FILE__ == $0
  code = Doom.run(ARGV)
  exit(code.is_a?(Integer) ? code : 0)
end
