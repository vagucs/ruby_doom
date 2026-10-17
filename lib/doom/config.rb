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
# default.cfg: mouse, volumes, mensagens e tamanho da tela.

module Doom
  module Config
    module_function

    def path
      File.join(Dir.pwd, 'default.cfg')
    end

    def load(game)
      return unless File.file?(path)

      File.readlines(path, encoding: 'UTF-8').each do |raw|
        line = raw.split('#', 2).first.to_s.strip
        next if line.empty?

        parts = line.split
        next if parts.length < 2

        key = parts[0]
        n = Integer(parts[1])
        case key
        when 'mouse_sensitivity' then game.mouse_sensitivity = n.clamp(0, 9)
        when 'sfx_volume' then game.sound&.set_sfx_volume(n.clamp(0, 15))
        when 'music_volume' then game.sound&.set_music_volume(n.clamp(0, 15))
        when 'show_messages' then game.show_messages = !n.zero?
        when 'use_mouse' then game.use_mouse = !n.zero?
        when 'screenblocks' then game.screen_size = (n - 3).clamp(0, 8)
        end
      end
    rescue ArgumentError, EncodingError, SystemCallError
      nil
    end

    def save(game)
      sound = game.sound
      File.write(path, [
        "mouse_sensitivity\t\t#{game.mouse_sensitivity.to_i}",
        "sfx_volume\t\t#{sound ? sound.sfx_volume.to_i : 8}",
        "music_volume\t\t#{sound ? sound.music_volume.to_i : 8}",
        "show_messages\t\t#{game.show_messages ? 1 : 0}",
        "use_mouse\t\t#{game.use_mouse ? 1 : 0}",
        "screenblocks\t\t#{game.screen_size.to_i + 3}",
        ''
      ].join("\n"), encoding: 'UTF-8')
    rescue SystemCallError
      nil
    end
  end
end
