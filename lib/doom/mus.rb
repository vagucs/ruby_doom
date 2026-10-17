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
# MUS do WAD para MIDI, como em doom/mus2mid.py.

module Doom
  module Mus
    NUM_CHANNELS = 16
    MIDI_PERCUSSION_CHAN = 9
    MUS_PERCUSSION_CHAN = 15
    MUS_RELEASEKEY = 0x00
    MUS_PRESSKEY = 0x10
    MUS_PITCHWHEEL = 0x20
    MUS_SYSTEMEVENT = 0x30
    MUS_CHANGECONTROLLER = 0x40
    MUS_SCOREEND = 0x60
    MIDI_HEADER = [
      0x4D, 0x54, 0x68, 0x64, 0x00, 0x00, 0x00, 0x06,
      0x00, 0x00, 0x00, 0x01, 0x00, 0x46, 0x4D, 0x54,
      0x72, 0x6B, 0x00, 0x00, 0x00, 0x00
    ].pack('C*').b.freeze
    CONTROLLER_MAP = [0x00, 0x20, 0x01, 0x07, 0x0A, 0x0B, 0x5B, 0x5D, 0x40, 0x43, 0x78, 0x7B, 0x7E, 0x7F, 0x79].freeze

    class Track
      attr_reader :body, :tracksize
      attr_accessor :queued

      def initialize
        @body = String.new(encoding: Encoding::ASCII_8BIT)
        @queued = 0
        @tracksize = 0
        @velocities = [127] * NUM_CHANNELS
        @channel_map = [-1] * NUM_CHANNELS
      end

      def write_time(time)
        buffer = time & 0x7F
        t = time
        while (t >>= 7) != 0
          buffer = (buffer << 8) | (t & 0x7F) | 0x80
        end
        loop do
          @body << (buffer & 0xFF)
          @tracksize += 1
          if (buffer & 0x80) != 0
            buffer >>= 8
          else
            @queued = 0
            return
          end
        end
      end

      def write(data)
        write_time(@queued)
        @body << data
        @tracksize += data.bytesize
      end

      def allocate_channel
        result = @channel_map.max + 1
        result += 1 if result == MIDI_PERCUSSION_CHAN
        result
      end

      def midi_channel(mus_channel)
        return MIDI_PERCUSSION_CHAN if mus_channel == MUS_PERCUSSION_CHAN
        return @channel_map[mus_channel] unless @channel_map[mus_channel] == -1

        @channel_map[mus_channel] = allocate_channel
        write([(0xB0 | @channel_map[mus_channel]), 0x7B, 0].pack('C3'))
        @channel_map[mus_channel]
      end

      def velocity(channel)
        @velocities[channel]
      end

      def velocity=(pair)
        channel, value = pair
        @velocities[channel] = value
      end
    end

    module_function

    def mus2mid(mus)
      mus = mus.b
      return mus if mus.bytesize >= 4 && mus.byteslice(0, 4) == 'MThd'.b
      return nil if mus.bytesize < 16 || mus.byteslice(0, 4) != "MUS\x1a".b

      pos = mus.byteslice(6, 2).unpack1('v')
      out = Track.new
      hitscoreend = false
      read_u8 = lambda do
        return nil if pos >= mus.bytesize

        byte = mus.getbyte(pos)
        pos += 1
        byte
      end

      until hitscoreend
        until hitscoreend
          descriptor = read_u8.call
          return nil if descriptor.nil?

          channel = out.midi_channel(descriptor & 0x0F)
          event = descriptor & 0x70
          if event == MUS_RELEASEKEY
            key = read_u8.call
            return nil if key.nil?

            out.write([(0x80 | channel), key & 0x7F, 0].pack('C3'))
          elsif event == MUS_PRESSKEY
            key = read_u8.call
            return nil if key.nil?

            if (key & 0x80) != 0
              vel = read_u8.call
              return nil if vel.nil?

              out.velocity = [channel, vel & 0x7F]
            end
            out.write([(0x90 | channel), key & 0x7F, out.velocity(channel)].pack('C3'))
          elsif event == MUS_PITCHWHEEL
            key = read_u8.call
            break if key.nil?

            wheel = key * 64
            out.write([(0xE0 | channel), wheel & 0x7F, (wheel >> 7) & 0x7F].pack('C3'))
          elsif event == MUS_SYSTEMEVENT
            ctrl = read_u8.call
            return nil if ctrl.nil? || ctrl < 10 || ctrl > 14

            out.write([(0xB0 | channel), CONTROLLER_MAP[ctrl], 0].pack('C3'))
          elsif event == MUS_CHANGECONTROLLER
            ctrl = read_u8.call
            val = read_u8.call
            return nil if ctrl.nil? || val.nil?

            if ctrl.zero?
              out.write([(0xC0 | channel), val & 0x7F].pack('C2'))
            else
              return nil if ctrl < 1 || ctrl > 9

              working = (val & 0x80) != 0 ? 0x7F : val
              out.write([(0xB0 | channel), CONTROLLER_MAP[ctrl], working].pack('C3'))
            end
          elsif event == MUS_SCOREEND
            hitscoreend = true
          else
            return nil
          end
          break if (descriptor & 0x80) != 0
        end
        next if hitscoreend

        timedelay = 0
        loop do
          working = read_u8.call
          return nil if working.nil?

          timedelay = (timedelay * 128) + (working & 0x7F)
          break if (working & 0x80).zero?
        end
        out.queued += timedelay
      end

      out.write_time(out.queued)
      out.body << "\xFF\x2F\x00".b
      out.instance_variable_set(:@tracksize, out.tracksize + 3)
      header = MIDI_HEADER.dup
      size = out.tracksize
      header.setbyte(18, (size >> 24) & 0xFF)
      header.setbyte(19, (size >> 16) & 0xFF)
      header.setbyte(20, (size >> 8) & 0xFF)
      header.setbyte(21, size & 0xFF)
      header + out.body
    end
  end
end
