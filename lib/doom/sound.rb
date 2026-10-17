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
# Efeitos DS* no mixer do SDL2. A musica vira MIDI e o Windows toca.

require 'tempfile'
require 'ffi'

module Doom
  module Winmm
    extend FFI::Library

    def self.load!
      return if @loaded

      ffi_lib 'winmm'
      attach_function :mciSendStringA, %i[string pointer uint32 pointer], :uint32
      @loaded = true
    rescue LoadError, FFI::NotFoundError
      @loaded = false
    end

    def self.ready?
      load!
      @loaded == true
    end
  end

  class Sound
    DOOM2_MUSIC = %w[
      runnin stalks countd betwee doom the_da shawn ddtblu
      in_cit dead stlks2 theda2 doom2 ddtbl2 runni2 dead2
      stlks3 romero shawn2 messag count2 ddtbl3 ampie theda3
      adrian messg2 romer2 tense shawn3 openin evil ultima
    ].freeze
    MIX_RATE = 11_025

    def initialize
      @cache = {}
      @enabled = true
      @music_enabled = true
      @music = ''
      @looping = false
      @playing = false
      @said = false
      @file = nil
      @sfx_volume = 8
      @music_volume = 8
    end

    attr_reader :sfx_volume, :music_volume

    def init(wad, video)
      @wad = wad
      @video = video
      set_sfx_volume(@sfx_volume)
      set_music_volume(@music_volume)
    end

    def set_sfx_volume(vol)
      @sfx_volume = vol.clamp(0, 15)
      @video.sfx_volume = @sfx_volume if @video
    end

    def set_music_volume(vol)
      @music_volume = vol.clamp(0, 15)
      mci("setaudio doommus volume to #{@music_volume * 1000 / 15}") if @playing
    end

    def play(name)
      return unless @enabled && name && !name.to_s.empty?

      pcm = self.pcm(name)
      @video&.mix_pcm(pcm, name.to_s.downcase) if pcm
    end

    def pcm(name)
      return nil if name.nil? || name.to_s.empty?

      key = name.to_s.downcase
      return @cache[key] if @cache.key?(key)
      return @cache[key] = nil unless @wad

      lump = "DS#{key.upcase[0, 6]}"
      number = @wad.check_num_for_name(lump)
      return @cache[key] = nil if number.negative?

      @cache[key] = self.class.decode(@wad.cache_lump_num(number))
    end

    def self.decode(data)
      return nil if data.nil? || data.bytesize < 8
      return nil if data.getbyte(0) != 3 || data.getbyte(1) != 0

      rate = data.getbyte(2) | (data.getbyte(3) << 8)
      length = data.byteslice(4, 4).unpack1('V')
      return nil if rate <= 0 || length > data.bytesize - 8 || length <= 48

      samples = data.byteslice(16, length - 32)
      return nil if samples.nil? || samples.empty?

      src_n = samples.bytesize
      count = rate == MIX_RATE ? src_n : (src_n * MIX_RATE) / rate
      count = 1 if count < 1
      pcm = String.new(encoding: Encoding::ASCII_8BIT)
      pcm << "\0".b * (count * 2)
      count.times do |i|
        at = i * src_n / count
        at = src_n - 1 if at >= src_n
        sample = (samples.getbyte(at) - 128) << 8
        pcm.setbyte(i * 2, sample & 0xFF)
        pcm.setbyte((i * 2) + 1, (sample >> 8) & 0xFF)
      end
      pcm
    end

    def play_title
      return unless @wad

      if @wad.check_num_for_name('MAP01') >= 0
        change_music('dm2ttl', false)
      elsif @wad.check_num_for_name('D_INTROA') >= 0
        change_music('introa', false)
      else
        change_music('intro', false)
      end
    end

    def play_level(episode, mapn)
      return unless @wad

      name = if @wad.check_num_for_name('MAP01') >= 0
               DOOM2_MUSIC[((mapn < 1 ? 1 : mapn) - 1) % DOOM2_MUSIC.length]
             else
               "e#{episode}m#{mapn}"
             end
      change_music(name, true)
    end

    def has_music(name)
      return false unless @wad && name && !name.empty?

      @wad.check_num_for_name("D_#{name.upcase[0, 6]}") >= 0
    end

    def change_music(name, looping = true)
      return unless @music_enabled && @wad && name && !name.empty?
      return if name.downcase == @music

      lump = "D_#{name.upcase[0, 6]}"
      number = @wad.check_num_for_name(lump)
      return if number.negative?

      midi = Mus.mus2mid(@wad.cache_lump_num(number))
      return if midi.nil? || midi.empty?

      stop_music
      @video&.silence
      file = Tempfile.create(['doom', '.mid'])
      file.binmode
      file.write(midi)
      file.close
      @file = file
      @music = name.downcase
      @looping = looping
      quoted = file.path.tr('/', '\\')
      mci('close doommus')
      opened = mci(%(open "#{quoted}" type sequencer alias doommus)).zero? || mci(%(open "#{quoted}" alias doommus)).zero?
      @playing = opened && mci('play doommus from 0').zero?
      if @playing
        mci("setaudio doommus volume to #{@music_volume * 1000 / 15}")
      else
        fail_once
      end
    end

    def update
      return unless @playing && @looping

      mci('play doommus from 0') if mci_text('status doommus mode').downcase == 'stopped'
    end

    def stop_music
      mci('close doommus') if @playing
      @playing = false
      @music = ''
      return unless @file

      path = @file.path
      @file.close
      File.delete(path) if path && File.file?(path)
    rescue StandardError
      nil
    ensure
      @file = nil
    end

    private

    def fail_once
      return if @said

      @said = true
      puts 'sem musica'
    end

    def mci(cmd)
      return 1 unless Winmm.ready?

      Winmm.mciSendStringA(cmd, nil, 0, nil)
    rescue StandardError
      1
    end

    def mci_text(cmd)
      return '' unless Winmm.ready?

      buf = FFI::MemoryPointer.new(:char, 64)
      return '' unless Winmm.mciSendStringA(cmd, buf, 64, nil).zero?

      buf.read_string
    rescue StandardError
      ''
    end
  end
end
