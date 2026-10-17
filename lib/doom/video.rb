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
# Janela SDL2. A gem ffi chama a DLL. O motor nao entra aqui.

require 'ffi'

module Doom
  module SDL
    extend FFI::Library

    SDL_INIT_AUDIO = 0x00000010
    SDL_INIT_VIDEO = 0x00000020
    SDL_INIT_EVENTS = 0x00004000
    AUDIO_S16LSB = 0x8010
    SDL_WINDOWPOS_CENTERED = 0x2FFF0000
    SDL_WINDOW_SHOWN = 0x00000004
    SDL_RENDERER_ACCELERATED = 0x00000002
    SDL_RENDERER_PRESENTVSYNC = 0x00000004
    SDL_PIXELFORMAT_ARGB8888 = 0x16362004
    SDL_TEXTUREACCESS_STREAMING = 1
    SDL_QUIT = 0x100
    SDL_KEYDOWN = 0x300
    SDL_KEYUP = 0x301
    SDL_MOUSEMOTION = 0x400
    SDL_MOUSEBUTTONDOWN = 0x401
    SDL_MOUSEBUTTONUP = 0x402
    SDL_WINDOW_FULLSCREEN_DESKTOP = 0x00001001

    def self.load!
      return if @loaded

      root = File.expand_path('../..', __dir__)
      candidates = [
        ENV.fetch('SDL2_PATH', nil),
        File.join(root, 'lib', 'SDL2.dll'),
        'C:/msys64/ucrt64/bin/SDL2.dll'
      ].compact
      path = candidates.find { |item| File.file?(item) } || 'SDL2'
      ffi_lib path
      attach_function :SDL_Init, [:uint32], :int
      attach_function :SDL_Quit, [], :void
      attach_function :SDL_GetError, [], :string
      attach_function :SDL_GetTicks, [], :uint32
      attach_function :SDL_Delay, [:uint32], :void
      attach_function :SDL_ShowCursor, [:int], :int
      attach_function :SDL_CreateWindow, %i[string int int int int uint32], :pointer
      attach_function :SDL_DestroyWindow, [:pointer], :void
      attach_function :SDL_CreateRenderer, %i[pointer int uint32], :pointer
      attach_function :SDL_DestroyRenderer, [:pointer], :void
      attach_function :SDL_RenderSetLogicalSize, %i[pointer int int], :int
      attach_function :SDL_RenderClear, [:pointer], :int
      attach_function :SDL_RenderCopy, %i[pointer pointer pointer pointer], :int
      attach_function :SDL_RenderPresent, [:pointer], :void
      attach_function :SDL_CreateTexture, %i[pointer uint32 int int int], :pointer
      attach_function :SDL_DestroyTexture, [:pointer], :void
      attach_function :SDL_UpdateTexture, %i[pointer pointer pointer int], :int
      attach_function :SDL_PollEvent, [:pointer], :int
      attach_function :SDL_InitSubSystem, [:uint32], :int
      attach_function :SDL_OpenAudioDevice, %i[pointer int pointer pointer int], :uint32
      attach_function :SDL_CloseAudioDevice, [:uint32], :void
      attach_function :SDL_PauseAudioDevice, %i[uint32 int], :void
      attach_function :SDL_QueueAudio, %i[uint32 pointer uint32], :int
      attach_function :SDL_GetQueuedAudioSize, [:uint32], :uint32
      attach_function :SDL_ClearQueuedAudio, [:uint32], :void
      attach_function :SDL_SetWindowSize, %i[pointer int int], :void
      attach_function :SDL_SetWindowPosition, %i[pointer int int], :void
      attach_function :SDL_SetWindowFullscreen, %i[pointer uint32], :int
      attach_function :SDL_SetRelativeMouseMode, [:int], :int
      @loaded = true
    end
  end

  class Video
    def initialize
      @scale = 2
      @down = {}
      @palette = "\0" * 768
      @pair = []
      @pixels = ("\0" * (Defs::SCREENWIDTH * Defs::SCREENHEIGHT * 4)).b
      @pixel_ptr = nil
      @audio = 0
      @channels = Array.new(8) { {} }
      @audio_said = false
      @fullscreen = false
      @sfx_volume = 8
      @mouse_dx = 0
      @mouse_dy = 0
      @mouse_fire = false
      @relative = 0
    end

    attr_accessor :sfx_volume
    attr_reader :scale, :fullscreen, :mouse_fire

    def init(scale: 2, vsync: true)
      SDL.load!
      @scale = scale.clamp(1, 6)
      rc = SDL.SDL_Init(SDL::SDL_INIT_VIDEO | SDL::SDL_INIT_EVENTS)
      raise "SDL_Init: #{error}" if rc != 0

      @window = SDL.SDL_CreateWindow(
        'DOOM',
        SDL::SDL_WINDOWPOS_CENTERED,
        SDL::SDL_WINDOWPOS_CENTERED,
        Defs::SCREENWIDTH * @scale,
        Defs::SCREENHEIGHT * @scale,
        SDL::SDL_WINDOW_SHOWN
      )
      raise "SDL_CreateWindow: #{error}" if @window.null?

      flags = SDL::SDL_RENDERER_ACCELERATED
      flags |= SDL::SDL_RENDERER_PRESENTVSYNC if vsync
      @renderer = SDL.SDL_CreateRenderer(@window, -1, flags)
      @renderer = SDL.SDL_CreateRenderer(@window, -1, 0) if @renderer.null?
      raise "SDL_CreateRenderer: #{error}" if @renderer.null?

      SDL.SDL_RenderSetLogicalSize(@renderer, Defs::SCREENWIDTH, Defs::SCREENHEIGHT)
      @texture = SDL.SDL_CreateTexture(
        @renderer,
        SDL::SDL_PIXELFORMAT_ARGB8888,
        SDL::SDL_TEXTUREACCESS_STREAMING,
        Defs::SCREENWIDTH,
        Defs::SCREENHEIGHT
      )
      raise "SDL_CreateTexture: #{error}" if @texture.null?

      @event = FFI::MemoryPointer.new(:uint8, 64)
      @pixel_ptr = FFI::MemoryPointer.new(:uint8, @pixels.bytesize)
      SDL.SDL_ShowCursor(0)
      open_audio
    end

    def set_palette(pal)
      pal = pal.byteslice(0, 768).b
      return if !@pair.empty? && pal == @palette

      @palette = pal
      lut = Array.new(256) do |i|
        at = i * 3
        [pal.getbyte(at + 2), pal.getbyte(at + 1), pal.getbyte(at), 255].pack('C4')
      end
      @pair = Array.new(65536)
      256.times do |p0|
        base = p0 << 8
        left = lut[p0]
        256.times { |p1| @pair[base | p1] = left + lut[p1] }
      end
    end

    def upload(fb)
      n = (Defs::SCREENWIDTH * Defs::SCREENHEIGHT) >> 1
      pix = @pixels
      pair = @pair
      n.times do |i|
        key = (fb.getbyte(i * 2) << 8) | fb.getbyte(i * 2 + 1)
        pix[i * 8, 8] = pair[key]
      end
      @pixel_ptr.put_bytes(0, pix)
    end

    def mix_pcm(pcm, key = '')
      return if @audio.zero? || pcm.nil? || pcm.bytesize < 2

      name = key.to_s
      @channels.each do |ch|
        next if ch[:pcm].nil? || ch[:name] != name || name.empty?
        next if ch[:pos] >= ch[:n]
        next unless ch[:pos] < 2000

        ch[:pos] = 0
        return
      end
      slot = 0
      most = -1
      @channels.each_with_index do |ch, i|
        if ch[:pcm].nil? || ch[:pos] >= ch[:n]
          slot = i
          break
        end
        next unless ch[:pos] > most

        most = ch[:pos]
        slot = i
      end
      @channels[slot] = { pcm: pcm, name: name, pos: 0, n: pcm.bytesize / 2 }
    end

    def silence
      @channels = Array.new(8) { {} }
      SDL.SDL_ClearQueuedAudio(@audio) unless @audio.zero?
    end

    def present(fb)
      pump_audio
      upload(fb)
      SDL.SDL_UpdateTexture(@texture, nil, @pixel_ptr, Defs::SCREENWIDTH * 4)
      SDL.SDL_RenderClear(@renderer)
      SDL.SDL_RenderCopy(@renderer, @texture, nil, nil)
      SDL.SDL_RenderPresent(@renderer)
    end

    def poll
      keys = []
      while SDL.SDL_PollEvent(@event) != 0
        type = @event.read_uint32
        if type == SDL::SDL_QUIT
          keys << -1
          break
        end
        if type == SDL::SDL_MOUSEMOTION
          @mouse_dx += @event.get_int32(24)
          @mouse_dy += -@event.get_int32(28)
          next
        end
        if type == SDL::SDL_MOUSEBUTTONDOWN
          @mouse_fire = true if @event.get_uint8(12) == 1
          next
        end
        if type == SDL::SDL_MOUSEBUTTONUP
          @mouse_fire = false if @event.get_uint8(12) == 1
          next
        end
        next unless type == SDL::SDL_KEYDOWN || type == SDL::SDL_KEYUP

        sym = @event.get_int32(20)
        if type == SDL::SDL_KEYUP
          @down.delete(sym)
          keys << [:up, sym]
          next
        end

        @down[sym] = true
        keys << sym if @event.get_uint8(13).zero?
      end
      keys
    end

    def down?(sym)
      @down[sym] == true
    end

    def release_keys
      @down.clear
    end

    def take_mouse
      dx = @mouse_dx
      dy = @mouse_dy
      @mouse_dx = 0
      @mouse_dy = 0
      [dx, dy]
    end

    def change_scale(delta)
      return false if @fullscreen

      new_scale = (@scale + delta).clamp(1, 6)
      return false if new_scale == @scale

      @scale = new_scale
      SDL.SDL_SetWindowSize(@window, Defs::SCREENWIDTH * @scale, Defs::SCREENHEIGHT * @scale)
      SDL.SDL_SetWindowPosition(@window, SDL::SDL_WINDOWPOS_CENTERED, SDL::SDL_WINDOWPOS_CENTERED)
      true
    end

    def toggle_fullscreen
      @fullscreen = !@fullscreen
      flag = @fullscreen ? SDL::SDL_WINDOW_FULLSCREEN_DESKTOP : 0
      SDL.SDL_SetWindowFullscreen(@window, flag)
    end

    def set_relative_mouse(on)
      flag = on ? 1 : 0
      return if @relative == flag

      @relative = flag
      SDL.SDL_SetRelativeMouseMode(flag)
      SDL.SDL_ShowCursor(on ? 0 : 1)
    end

    def ticks
      SDL.SDL_GetTicks
    end

    def delay(ms)
      SDL.SDL_Delay(ms)
    end

    def shutdown
      SDL.SDL_CloseAudioDevice(@audio) unless @audio.zero?
      @audio = 0
      SDL.SDL_DestroyTexture(@texture) if @texture && !@texture.null?
      SDL.SDL_DestroyRenderer(@renderer) if @renderer && !@renderer.null?
      SDL.SDL_DestroyWindow(@window) if @window && !@window.null?
      SDL.SDL_Quit
    end

    private

    def open_audio
      return unless SDL.SDL_InitSubSystem(SDL::SDL_INIT_AUDIO).zero?

      want = FFI::MemoryPointer.new(32)
      have = FFI::MemoryPointer.new(32)
      want.put_int32(0, 11_025)
      want.put_uint16(4, SDL::AUDIO_S16LSB)
      want.put_uint8(6, 1)
      want.put_uint16(8, 512)
      dev = SDL.SDL_OpenAudioDevice(nil, 0, want, have, 0)
      if dev.zero?
        puts 'sem som' unless @audio_said
        @audio_said = true
        return
      end
      @audio = dev
      SDL.SDL_PauseAudioDevice(dev, 0)
    rescue StandardError
      @audio = 0
      puts 'sem som' unless @audio_said
      @audio_said = true
    end

    def pump_audio
      return if @audio.zero?

      queued = SDL.SDL_GetQueuedAudioSize(@audio)
      limit = 512 * 2 * 4
      return if queued >= limit

      need = (limit - queued) / 2
      return if need < 1

      have = 0
      @channels.each do |ch|
        next if ch[:pcm].nil?

        left = ch[:n] - ch[:pos]
        have = left if left > have
      end
      return if have < 1

      need = have if have < need
      mix = Array.new(need, 0)
      @channels.each do |ch|
        next if ch[:pcm].nil? || ch[:pos] >= ch[:n]

        take = [ch[:n] - ch[:pos], need].min
        pcm = ch[:pcm]
        pos = ch[:pos]
        take.times do |i|
          at = (pos + i) * 2
          sample = pcm.getbyte(at) | (pcm.getbyte(at + 1) << 8)
          sample -= 65_536 if sample >= 32_768
          cur = mix[i] + ((sample * @sfx_volume) / 15)
          cur = 32_767 if cur > 32_767
          cur = -32_768 if cur < -32_768
          mix[i] = cur
        end
        ch[:pos] = pos + take
      end
      packed = mix.map { |sample| sample & 0xFFFF }.pack('v*')
      buf = FFI::MemoryPointer.new(:uint8, packed.bytesize)
      buf.put_bytes(0, packed)
      SDL.SDL_QueueAudio(@audio, buf, packed.bytesize)
    end

    def error
      msg = SDL.SDL_GetError
      msg.nil? || msg.empty? ? 'erro desconhecido' : msg
    end
  end
end
