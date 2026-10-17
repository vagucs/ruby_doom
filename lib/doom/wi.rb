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
# Contagem da fase e o mapa da proxima.

module Doom
  WI_TITLEY = 2
  SP_STATSX = 50
  SP_STATSY = 50
  SP_TIMEX = 16
  SP_TIMEY = Defs::SCREENHEIGHT - 32
  SHOWNEXTLOCDELAY = 4
  WI_NO_STATE = -1
  WI_STAT_COUNT = 0
  WI_SHOW_NEXT = 1
  ANIM_ALWAYS = 0
  ANIM_LEVEL = 2
  PARS = [
    [0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
    [0, 30, 75, 120, 90, 165, 180, 180, 30, 165],
    [0, 90, 90, 90, 120, 90, 360, 240, 30, 170],
    [0, 90, 45, 90, 150, 90, 90, 165, 30, 135]
  ].freeze
  CPARS = [
    30, 90, 120, 120, 90, 150, 120, 120, 270, 90,
    210, 150, 150, 150, 210, 150, 420, 150, 210, 150,
    240, 150, 180, 150, 150, 300, 330, 420, 300, 180,
    120, 30
  ].freeze
  LNODES = [
    [[185, 164], [148, 143], [69, 122], [209, 102], [116, 89], [166, 55], [71, 56], [135, 29], [71, 24]],
    [[254, 25], [97, 50], [188, 64], [128, 78], [214, 92], [133, 130], [208, 136], [148, 140], [235, 158]],
    [[156, 168], [48, 154], [174, 95], [265, 75], [130, 48], [279, 23], [198, 48], [140, 25], [281, 136]]
  ].freeze
  ANIMS = [
    [
      [ANIM_ALWAYS, Defs::TICRATE / 3, 3, 224, 104, 0],
      [ANIM_ALWAYS, Defs::TICRATE / 3, 3, 184, 160, 0],
      [ANIM_ALWAYS, Defs::TICRATE / 3, 3, 112, 136, 0],
      [ANIM_ALWAYS, Defs::TICRATE / 3, 3, 72, 112, 0],
      [ANIM_ALWAYS, Defs::TICRATE / 3, 3, 88, 96, 0],
      [ANIM_ALWAYS, Defs::TICRATE / 3, 3, 64, 48, 0],
      [ANIM_ALWAYS, Defs::TICRATE / 3, 3, 192, 40, 0],
      [ANIM_ALWAYS, Defs::TICRATE / 3, 3, 136, 16, 0],
      [ANIM_ALWAYS, Defs::TICRATE / 3, 3, 80, 16, 0],
      [ANIM_ALWAYS, Defs::TICRATE / 3, 3, 64, 24, 0]
    ],
    [
      [ANIM_LEVEL, Defs::TICRATE / 3, 1, 128, 136, 1],
      [ANIM_LEVEL, Defs::TICRATE / 3, 1, 128, 136, 2],
      [ANIM_LEVEL, Defs::TICRATE / 3, 1, 128, 136, 3],
      [ANIM_LEVEL, Defs::TICRATE / 3, 1, 128, 136, 4],
      [ANIM_LEVEL, Defs::TICRATE / 3, 1, 128, 136, 5],
      [ANIM_LEVEL, Defs::TICRATE / 3, 1, 128, 136, 6],
      [ANIM_LEVEL, Defs::TICRATE / 3, 1, 128, 136, 7],
      [ANIM_ALWAYS, Defs::TICRATE / 3, 3, 192, 144, 8],
      [ANIM_LEVEL, Defs::TICRATE / 3, 1, 128, 136, 8]
    ],
    [
      [ANIM_ALWAYS, Defs::TICRATE / 3, 3, 104, 168, 0],
      [ANIM_ALWAYS, Defs::TICRATE / 3, 3, 40, 136, 0],
      [ANIM_ALWAYS, Defs::TICRATE / 3, 3, 160, 96, 0],
      [ANIM_ALWAYS, Defs::TICRATE / 3, 3, 104, 80, 0],
      [ANIM_ALWAYS, Defs::TICRATE / 3, 3, 120, 32, 0],
      [ANIM_ALWAYS, Defs::TICRATE / 4, 3, 40, 0, 0]
    ]
  ].freeze

  module_function

  def partime(episode, mapn, commercial)
    if commercial
      i = (mapn - 1).clamp(0, CPARS.length - 1)
      return Defs::TICRATE * CPARS[i]
    end
    return Defs::TICRATE * PARS[episode][mapn] if episode.between?(1, 3) && mapn.between?(1, 9)
    return Defs::TICRATE * CPARS[[CPARS.length - 1, mapn].min] if mapn.between?(1, 9)

    Defs::TICRATE * 30
  end

  def percent(value, maximum)
    (value * 100) / [1, maximum].max
  end

  class Anim
    attr_accessor :type, :period, :nanims, :x, :y, :data1, :patches, :ctr, :nexttic

    def initialize(type, period, nanims, x, y, data1)
      @type = type
      @period = period
      @nanims = nanims
      @x = x
      @y = y
      @data1 = data1
      @patches = []
      @ctr = -1
      @nexttic = 0
    end
  end

  class WbStart
    attr_accessor :epsd, :last, :nxt, :maxkills, :maxitems, :maxsecret, :partime,
                  :skills, :sitems, :ssecret, :stime, :didsecret, :commercial

    def initialize(fields)
      fields.each { |key, value| send("#{key}=", value) }
    end
  end

  class Intermission
    attr_reader :done

    def initialize(wad, sound, wbs)
      @wad = wad
      @sound = sound
      @wbs = wbs
      @state = WI_STAT_COUNT
      @accelerate = 0
      @sp_state = 1
      @cnt_kills = -1
      @cnt_items = -1
      @cnt_secret = -1
      @cnt_time = -1
      @cnt_par = -1
      @cnt_pause = Defs::TICRATE
      @cnt = 0
      @bcnt = 0
      @snl_pointeron = false
      @done = false
      @anims = []
      @patches = {}
      {
        'finished' => 'WIF', 'entering' => 'WIENTER', 'kills' => 'WIOSTK', 'items' => 'WIOSTI',
        'sp_secret' => 'WISCRT2', 'percent' => 'WIPCNT', 'colon' => 'WICOLON', 'time' => 'WITIME',
        'par' => 'WIPAR', 'sucks' => 'WISUCKS', 'minus' => 'WIMINUS', 'splat' => 'WISPLAT',
        'yah0' => 'WIURH0', 'yah1' => 'WIURH1'
      }.each { |key, lump| @patches[key] = load_lump(lump) }
      @num = (0..9).map { |i| load_lump("WINUM#{i}") }
      bg = if wbs.commercial || wbs.epsd == 3
             'INTERPIC'
           else
             "WIMAP#{wbs.epsd}"
           end
      @background = load_lump(bg) || load_lump('INTERPIC')
      nmaps = wbs.commercial ? 32 : 9
      @lnames = Array.new(nmaps) do |i|
        load_lump(wbs.commercial ? format('CWILV%02d', i) : "WILV#{wbs.epsd}#{i}")
      end
      load_anims unless wbs.commercial || wbs.epsd >= 3
      init_animated
    end

    def ticker(menu:, attack:, use:, enter:, player:)
      @bcnt += 1
      if @bcnt == 1
        @sound.change_music(@wbs.commercial ? 'dm2int' : 'inter', true)
      end
      check_accelerate(menu, attack, use, enter, player)
      case @state
      when WI_STAT_COUNT then update_stats
      when WI_SHOW_NEXT then update_show_next
      when WI_NO_STATE then update_no_state
      end
    end

    def draw(fb)
      if @state == WI_STAT_COUNT
        draw_stats(fb)
      else
        draw_show_next(fb)
      end
    end

    private

    def load_lump(name)
      number = @wad.check_num_for_name(name)
      return nil if number.negative?

      @wad.cache_lump_num(number)
    end

    def load_anims
      ANIMS[@wbs.epsd].each_with_index do |spec, j|
        anim = Anim.new(*spec)
        anim.nanims.times do |i|
          anim.patches << if @wbs.epsd == 1 && j == 8 && @anims.length > 4
                            @anims[4].patches[i]
                          else
                            load_lump(format('WIA%d%02d%02d', @wbs.epsd, j, i))
                          end
        end
        @anims << anim
      end
    end

    def init_animated
      return if @wbs.commercial || @wbs.epsd > 2

      @anims.each do |anim|
        anim.ctr = -1
        anim.nexttic = if anim.type == ANIM_ALWAYS
                         @bcnt + 1 + rand([1, anim.period].max)
                       else
                         @bcnt + 1
                       end
      end
    end

    def update_animated
      return if @wbs.commercial || @wbs.epsd > 2

      @anims.each_with_index do |anim, i|
        next unless @bcnt == anim.nexttic

        if anim.type == ANIM_ALWAYS
          anim.ctr += 1
          anim.ctr = 0 if anim.ctr >= anim.nanims
          anim.nexttic = @bcnt + anim.period
        elsif anim.type == ANIM_LEVEL && !(@state == WI_STAT_COUNT && i == 7) && @wbs.nxt == anim.data1
          anim.ctr += 1
          anim.ctr -= 1 if anim.ctr == anim.nanims
          anim.nexttic = @bcnt + anim.period
        end
      end
    end

    def check_accelerate(menu, attack, use, enter, player)
      return if menu

      if player.nil?
        @accelerate = 1 if attack || use || enter
        return
      end
      if attack
        @accelerate = 1 unless player.attackdown
        player.attackdown = true
      else
        player.attackdown = false
      end
      if use || enter
        @accelerate = 1 unless player.usedown
        player.usedown = true
      elsif !use
        player.usedown = false
      end
    end

    def update_stats
      update_animated
      if @accelerate != 0 && @sp_state != 10
        @accelerate = 0
        @cnt_kills = Doom.percent(@wbs.skills, @wbs.maxkills)
        @cnt_items = Doom.percent(@wbs.sitems, @wbs.maxitems)
        @cnt_secret = Doom.percent(@wbs.ssecret, @wbs.maxsecret)
        @cnt_time = @wbs.stime / Defs::TICRATE
        @cnt_par = @wbs.partime / Defs::TICRATE
        @sound.play('barexp')
        @sp_state = 10
      end
      case @sp_state
      when 2 then count_stat(:kills)
      when 4 then count_stat(:items)
      when 6 then count_stat(:secret)
      when 8 then count_time
      when 10
        return if @accelerate.zero?

        @sound.play('wpnup')
        if @wbs.commercial
          init_no_state
        else
          init_show_next
        end
      else
        return if @sp_state.even?

        @cnt_pause -= 1
        return unless @cnt_pause.zero?

        @sp_state += 1
        @cnt_pause = Defs::TICRATE
        @cnt_kills = 0 if @sp_state == 2
        @cnt_items = 0 if @sp_state == 4
        @cnt_secret = 0 if @sp_state == 6
        if @sp_state == 8
          @cnt_time = 0
          @cnt_par = 0
        end
      end
    end

    def count_stat(which)
      if which == :kills
        @cnt_kills += 2
        target = Doom.percent(@wbs.skills, @wbs.maxkills)
        current = @cnt_kills
      elsif which == :items
        @cnt_items += 2
        target = Doom.percent(@wbs.sitems, @wbs.maxitems)
        current = @cnt_items
      else
        @cnt_secret += 2
        target = Doom.percent(@wbs.ssecret, @wbs.maxsecret)
        current = @cnt_secret
      end
      @sound.play('pistol') if (@bcnt & 3).zero?
      return unless current >= target

      instance_variable_set("@cnt_#{which}", target)
      @sound.play('barexp')
      @sp_state += 1
    end

    def count_time
      @sound.play('pistol') if (@bcnt & 3).zero?
      @cnt_time += 3
      ttime = @wbs.stime / Defs::TICRATE
      @cnt_time = ttime if @cnt_time >= ttime
      @cnt_par += 3
      ptime = @wbs.partime / Defs::TICRATE
      @cnt_par = ptime if @cnt_par >= ptime
      return unless @cnt_par >= ptime && @cnt_time >= ttime

      @sound.play('barexp')
      @sp_state += 1
    end

    def init_show_next
      @state = WI_SHOW_NEXT
      @accelerate = 0
      @cnt = SHOWNEXTLOCDELAY * Defs::TICRATE
      init_animated
    end

    def update_show_next
      update_animated
      @cnt -= 1
      if @cnt.zero? || @accelerate != 0
        init_no_state
      else
        @snl_pointeron = (@cnt & 31) < 20
      end
    end

    def init_no_state
      @state = WI_NO_STATE
      @accelerate = 0
      @cnt = 10
    end

    def update_no_state
      update_animated
      @cnt -= 1
      @done = true if @cnt.zero?
    end

    def draw_bg(fb)
      VVideo.draw_patch(fb, 0, 0, @background) if @background
      return if @wbs.commercial || @wbs.epsd > 2

      @anims.each do |anim|
        next unless anim.ctr >= 0 && anim.ctr < anim.patches.length && anim.patches[anim.ctr]

        VVideo.draw_patch(fb, anim.x, anim.y, anim.patches[anim.ctr])
      end
    end

    def patch_width(patch)
      return 8 unless patch

      VVideo.patch_size(patch)[0]
    end

    def patch_height(patch)
      return 16 unless patch

      VVideo.patch_size(patch)[1]
    end

    def draw_num(fb, x, y, number, digits)
      fontw = @num[0] ? patch_width(@num[0]) : 8
      if digits.negative?
        digits = number.zero? ? 1 : 0
        temp = number.abs
        while temp.positive?
          temp /= 10
          digits += 1
        end
      end
      neg = number.negative?
      number = -number if neg
      while digits.positive?
        digits -= 1
        x -= fontw
        digit = number % 10
        VVideo.draw_patch(fb, x, y, @num[digit]) if @num[digit]
        number /= 10
      end
      if neg && @patches['minus']
        x -= 8
        VVideo.draw_patch(fb, x, y, @patches['minus'])
      end
      x
    end

    def draw_percent(fb, x, y, value)
      return if value.negative?

      VVideo.draw_patch(fb, x, y, @patches['percent']) if @patches['percent']
      draw_num(fb, x, y, value, -1)
    end

    def draw_time(fb, x, y, time)
      return if time.negative?

      if time > 61 * 59
        sucks = @patches['sucks']
        VVideo.draw_patch(fb, x - patch_width(sucks), y, sucks) if sucks
        return
      end
      colon = @patches['colon']
      div = 1
      loop do
        n = (time / div) % 60
        x = draw_num(fb, x, y, n, 2) - (colon ? patch_width(colon) : 0)
        div *= 60
        VVideo.draw_patch(fb, x, y, colon) if colon && (div == 60 || (time / div).positive?)
        break if (time / div).zero?
      end
    end

    def draw_level_name(fb, y, index, entering)
      patch = @lnames[index] if index >= 0 && index < @lnames.length
      if entering && @patches['entering']
        ent = @patches['entering']
        VVideo.draw_patch(fb, (Defs::SCREENWIDTH - patch_width(ent)) / 2, y, ent)
        y += (5 * patch_height(ent)) / 4
      end
      if patch
        VVideo.draw_patch(fb, (Defs::SCREENWIDTH - patch_width(patch)) / 2, y, patch)
        y += (5 * patch_height(patch)) / 4 unless entering
      end
      y
    end

    def draw_stats(fb)
      draw_bg(fb)
      y = WI_TITLEY
      y = draw_level_name(fb, y, @wbs.last, false)
      fin = @patches['finished']
      VVideo.draw_patch(fb, (Defs::SCREENWIDTH - patch_width(fin)) / 2, y, fin) if fin
      lh = @num[0] ? (3 * patch_height(@num[0])) / 2 : 24
      VVideo.draw_patch(fb, SP_STATSX, SP_STATSY, @patches['kills']) if @patches['kills']
      draw_percent(fb, Defs::SCREENWIDTH - SP_STATSX, SP_STATSY, @cnt_kills)
      VVideo.draw_patch(fb, SP_STATSX, SP_STATSY + lh, @patches['items']) if @patches['items']
      draw_percent(fb, Defs::SCREENWIDTH - SP_STATSX, SP_STATSY + lh, @cnt_items)
      VVideo.draw_patch(fb, SP_STATSX, SP_STATSY + (2 * lh), @patches['sp_secret']) if @patches['sp_secret']
      draw_percent(fb, Defs::SCREENWIDTH - SP_STATSX, SP_STATSY + (2 * lh), @cnt_secret)
      VVideo.draw_patch(fb, SP_TIMEX, SP_TIMEY, @patches['time']) if @patches['time']
      draw_time(fb, (Defs::SCREENWIDTH / 2) - SP_TIMEX, SP_TIMEY, @cnt_time)
      return unless @wbs.epsd < 3

      VVideo.draw_patch(fb, (Defs::SCREENWIDTH / 2) + SP_TIMEX, SP_TIMEY, @patches['par']) if @patches['par']
      draw_time(fb, Defs::SCREENWIDTH - SP_TIMEX, SP_TIMEY, @cnt_par)
    end

    def draw_on_lnode(fb, n, patches)
      return if @wbs.epsd >= LNODES.length || n >= LNODES[@wbs.epsd].length

      node = LNODES[@wbs.epsd][n]
      patches.each do |patch|
        next unless patch

        w, h, left, top = VVideo.patch_size(patch)
        left_x = node[0] - left
        top_y = node[1] - top
        next unless left_x >= 0 && left_x + w < Defs::SCREENWIDTH && top_y >= 0 && top_y + h < Defs::SCREENHEIGHT

        VVideo.draw_patch(fb, node[0], node[1], patch)
        break
      end
    end

    def draw_show_next(fb)
      draw_bg(fb)
      @snl_pointeron = true if @state == WI_NO_STATE
      unless @wbs.commercial
        if @wbs.epsd > 2
          draw_entering(fb)
          return
        end
        last = @wbs.last == 8 ? @wbs.nxt - 1 : @wbs.last
        splat = [@patches['splat']]
        yah = [@patches['yah0'], @patches['yah1']]
        [0, last + 1].max.times { |i| draw_on_lnode(fb, i, splat) }
        draw_on_lnode(fb, 8, splat) if @wbs.didsecret
        draw_on_lnode(fb, @wbs.nxt, yah) if @snl_pointeron
      end
      draw_entering(fb) if !@wbs.commercial || @wbs.nxt != 30
    end

    def draw_entering(fb)
      y = WI_TITLEY
      ent = @patches['entering']
      if ent
        VVideo.draw_patch(fb, (Defs::SCREENWIDTH - patch_width(ent)) / 2, y, ent)
        y += (5 * patch_height(ent)) / 4
      end
      patch = @lnames[@wbs.nxt] if @wbs.nxt >= 0 && @wbs.nxt < @lnames.length
      return unless patch

      VVideo.draw_patch(fb, (Defs::SCREENWIDTH - patch_width(patch)) / 2, y, patch)
    end
  end
end
