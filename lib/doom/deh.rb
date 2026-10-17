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
# DeHackEd e os cheats iddqd, idkfa, idclip, idclev, idmus e idbehold.

module Doom
  module Deh
    SIGS = [
      'Patch File for DeHackEd v2.3',
      'Patch File for DeHackEd v3.0'
    ].freeze
    THING_DOOMED = {
      2 => 3004, 3 => 9, 4 => 64, 6 => 66, 9 => 67, 12 => 3001, 13 => 3002, 15 => 3005,
      16 => 3003, 18 => 69, 19 => 3006, 20 => 7, 21 => 68, 22 => 16, 23 => 71, 24 => 84,
      25 => 72, 31 => 2035
    }.freeze
    BEX_STRINGS = {
      'STSTR_DQDON' => 'Degreelessness Mode On',
      'STSTR_DQDOFF' => 'Degreelessness Mode Off',
      'STSTR_KFAADDED' => 'Very Happy Ammo Added',
      'STSTR_FAADDED' => 'Ammo Added',
      'STSTR_NCON' => 'No Clipping Mode ON',
      'STSTR_NCOFF' => 'No Clipping Mode OFF',
      'STSTR_BEHOLD' => 'invin visis rad allmap lite amp',
      'STSTR_BEHOLDX' => 'Power-up Toggled',
      'STSTR_CHOPPERS' => "... doesn't suck - GM",
      'STSTR_CLEV' => 'Changing Level...',
      'STSTR_MUS' => 'Music Change',
      'STSTR_NOMUS' => 'IMPOSSIBLE SELECTION',
      'AMSTR_FOLLOWON' => 'Follow Mode ON',
      'AMSTR_FOLLOWOFF' => 'Follow Mode OFF',
      'AMSTR_GRIDON' => 'Grid ON',
      'AMSTR_GRIDOFF' => 'Grid OFF',
      'AMSTR_MARKSCLEARED' => 'All Marks Cleared',
      'MSGOFF' => 'Messages Off',
      'MSGON' => 'Messages On',
      'DETAILHI' => 'High detail',
      'DETAILLO' => 'Low detail',
      'GGSAVED' => 'game saved.'
    }.freeze
    MISC_KEYS = {
      'Initial Health' => :initial_health,
      'Initial Bullets' => :initial_bullets,
      'Max Health' => :max_health,
      'Max Armor' => :max_armor,
      'Green Armor Class' => :green_armor_class,
      'Blue Armor Class' => :blue_armor_class,
      'Max Soulsphere' => :max_soulsphere,
      'Soulsphere Health' => :soulsphere_health,
      'Megasphere Health' => :megasphere_health,
      'God Mode Health' => :god_mode_health,
      'IDFA Armor' => :idfa_armor,
      'IDFA Armor Class' => :idfa_armor_class,
      'IDKFA Armor' => :idkfa_armor,
      'IDKFA Armor Class' => :idkfa_armor_class,
      'BFG Cells/Shot' => :bfg_cells_per_shot
    }.freeze

    class CheatSeq
      attr_accessor :action, :sequence, :param_chars, :deh_name, :chars_read, :param_buf

      def initialize(action, sequence, param_chars = 0, deh_name = nil)
        @action = action
        @sequence = sequence
        @param_chars = param_chars
        @deh_name = deh_name
        @chars_read = 0
        @param_buf = ''
      end

      def feed(ch)
        seq = @sequence
        return nil if seq.nil? || seq.empty?

        if @chars_read < seq.length
          if ch == seq[@chars_read]
            @chars_read += 1
          else
            @chars_read = ch == seq[0] ? 1 : 0
          end
          return nil if @chars_read < seq.length
          if @param_chars <= 0
            @chars_read = 0
            return ''
          end

          return nil
        end
        @param_buf += ch if @param_buf.length < @param_chars
        return nil if @param_buf.length < @param_chars

        buf = @param_buf
        @chars_read = 0
        @param_buf = ''
        buf
      end
    end

    class Patch
      attr_accessor :files, :nodeh, :apply_cheats, :cheats, :initial_health, :initial_bullets,
                    :max_health, :max_armor, :green_armor_class, :blue_armor_class, :max_soulsphere,
                    :soulsphere_health, :megasphere_health, :god_mode_health, :idfa_armor,
                    :idfa_armor_class, :idkfa_armor, :idkfa_armor_class, :bfg_cells_per_shot,
                    :species_infighting, :maxammo, :clipammo

      def initialize
        @files = []
        @nodeh = false
        @apply_cheats = true
        @allow_long_strings = false
        @allow_long_cheats = false
        @allow_extended_strings = false
        @replacements = {}
        @cheats = make_cheats
        @initial_health = 100
        @initial_bullets = 50
        @max_health = 200
        @max_armor = 200
        @green_armor_class = 1
        @blue_armor_class = 2
        @max_soulsphere = 200
        @soulsphere_health = 100
        @megasphere_health = 200
        @god_mode_health = 100
        @idfa_armor = 200
        @idfa_armor_class = 2
        @idkfa_armor = 200
        @idkfa_armor_class = 2
        @bfg_cells_per_shot = 40
        @species_infighting = 0
        @maxammo = [200, 50, 300, 50]
        @clipammo = [10, 4, 20, 1]
      end

      def string(text)
        @replacements.fetch(text, text)
      end

      def load_after_iwad(wad)
        unless @nodeh
          wad.each_lump do |index, name|
            load_lump(wad, index) if name == 'DEHACKED'
          end
        end
        @files.each do |path|
          if File.file?(path)
            load_file(path)
          else
            puts "DEH_LoadFile: Unable to open #{path}"
          end
        end
      end

      def load_file(path)
        data = File.binread(path).force_encoding('ISO-8859-1').encode('UTF-8', invalid: :replace, undef: :replace)
        puts " loading #{path}"
        parse(data, path)
      end

      def load_lump(wad, index)
        raw = wad.cache_lump_num(index)
        name = wad.lump_name(index)
        puts " loading lump #{name}"
        parse(raw.force_encoding('ISO-8859-1').encode('UTF-8', invalid: :replace, undef: :replace), name)
      end

      private

      def make_cheats
        [
          CheatSeq.new('god', 'iddqd', 0, 'iddqd'),
          CheatSeq.new('kfa', 'idkfa', 0, 'idkfa'),
          CheatSeq.new('fa', 'idfa', 0, 'idfa'),
          CheatSeq.new('noclip2', 'idclip', 0, 'idclip'),
          CheatSeq.new('noclip', 'idspispopd', 0, 'idspispopd'),
          CheatSeq.new('iddt', 'iddt'),
          CheatSeq.new('beholdv', 'idbeholdv'),
          CheatSeq.new('beholds', 'idbeholds'),
          CheatSeq.new('beholdi', 'idbeholdi'),
          CheatSeq.new('beholdr', 'idbeholdr'),
          CheatSeq.new('beholda', 'idbeholda'),
          CheatSeq.new('beholdl', 'idbeholdl'),
          CheatSeq.new('behold', 'idbehold', 0, 'idbehold'),
          CheatSeq.new('choppers', 'idchoppers', 0, 'idchoppers'),
          CheatSeq.new('mypos', 'idmypos', 0, 'idmypos'),
          CheatSeq.new('clev', 'idclev', 2, 'idclev'),
          CheatSeq.new('mus', 'idmus', 2, 'idmus')
        ]
      end

      def parse(data, name)
        @allow_long_strings = false
        @allow_long_cheats = false
        @allow_extended_strings = false
        pos = 0
        first, pos = read_line(data, pos, false)
        unless first && SIGS.include?(first.strip)
          puts "#{name}: This is not a valid dehacked patch file!"
          return
        end
        section = nil
        tag = nil
        while pos <= data.length
          line, pos = read_line(data, pos, section == '[STRINGS]')
          break if line.nil?

          stripped = line.sub(/\A[ \t]+/, '')
          if stripped.start_with?('#')
            comment(stripped)
            next
          end
          if stripped.strip.empty?
            section = nil
            tag = nil
            next
          end
          if section
            parse_line(data, section, stripped, tag, pos)
            pos = @text_pos if @text_pos
            @text_pos = nil
          else
            word = stripped.split(nil, 2).first
            if word.to_s.upcase == '[STRINGS]' && !@allow_extended_strings
              section = nil
              next
            end
            section = word
            tag = start_section(data, word, stripped, pos)
            pos = @text_pos if @text_pos
            @text_pos = nil
          end
        end
      end

      def read_line(data, pos, extended)
        return [nil, pos] if pos >= data.length

        parts = []
        loop do
          nl = data.index("\n", pos) || data.length
          line = data[pos...nl].delete("\r")
          pos = nl < data.length ? nl + 1 : data.length
          if extended && line.end_with?('\\')
            parts << "#{line[0...-1]}\n"
            break if pos >= data.length

            next
          end
          parts << line
          break
        end
        [parts.join, pos]
      end

      def comment(text)
        @allow_long_strings = true if text.include?('*allow-long-strings*')
        @allow_long_cheats = true if text.include?('*allow-long-cheats*')
        @allow_extended_strings = true if text.include?('*allow-extended-strings*')
      end

      def start_section(data, word, line, pos)
        key = word.to_s.downcase
        if key == 'thing' || key == 'ammo'
          return Integer(line.split[1])
        end
        parse_text(data, line, pos) if key == 'text'
        nil
      rescue ArgumentError, IndexError
        nil
      end

      def parse_line(data, section, line, tag, pos)
        key = section.to_s.downcase
        case key
        when 'misc' then parse_misc(line)
        when 'thing' then parse_thing(line, tag)
        when 'ammo' then parse_ammo(line, tag)
        when 'cheat' then parse_cheat(line)
        when '[strings]' then parse_bex(line)
        when 'text' then parse_text(data, line, pos)
        end
      end

      def assignment(line)
        eq = line.index('=')
        return nil if eq.nil?

        [line[0...eq].strip, line[(eq + 1)..].strip]
      end

      def parse_misc(line)
        asg = assignment(line)
        return unless asg

        name, raw = asg
        value = Integer(raw)
        if name.casecmp('monsters infight').zero?
          @species_infighting = value == 221 ? 1 : 0
          return
        end
        MISC_KEYS.each do |label, attr|
          next unless label.casecmp(name).zero?

          send("#{attr}=", value)
          break
        end
      rescue ArgumentError
        nil
      end

      def parse_thing(line, tag)
        asg = assignment(line)
        return unless asg && tag.is_a?(Integer)

        name, raw = asg
        return unless name.casecmp('hit points').zero?

        value = Integer(raw)
        doomed = THING_DOOMED[tag]
        return if doomed.nil?

        typ = Info.mobj_type_for_doomednum(doomed)
        Info::MOBJINFO[typ][Info::MI_SPAWNHEALTH] = value if typ >= 0
      rescue ArgumentError
        nil
      end

      def parse_ammo(line, tag)
        asg = assignment(line)
        return unless asg && tag.is_a?(Integer) && tag.between?(0, 3)

        name, raw = asg
        value = Integer(raw)
        if name.casecmp('max ammo').zero?
          @maxammo[tag] = value
        elsif name.casecmp('per ammo').zero?
          @clipammo[tag] = value
        end
      rescue ArgumentError
        nil
      end

      def parse_cheat(line)
        return unless @apply_cheats

        asg = assignment(line)
        return unless asg

        cheat = @cheats.find { |item| item.deh_name == asg[0].downcase }
        return unless cheat

        seq = +''
        asg[1].each_char.with_index(1) do |ch, i|
          code = ch.ord
          break if code.zero? || code == 0xFF
          break if !@allow_long_cheats && i > cheat.sequence.length

          seq << ch
        end
        cheat.sequence = seq
        cheat.chars_read = 0
        cheat.param_buf = ''
      end

      def parse_bex(line)
        asg = assignment(line)
        return unless asg

        original = BEX_STRINGS[asg[0].upcase]
        return unless original

        @replacements[original] = asg[1].gsub('\\n', "\n")
      end

      def parse_text(data, line, pos)
        parts = line.split
        return if parts.length < 3

        n_from = Integer(parts[1])
        n_to = Integer(parts[2])
        src = data[pos, n_from].to_s
        dst = data[pos + src.length, n_to].to_s
        @replacements[src] = dst
        @text_pos = pos + src.length + dst.length
      rescue ArgumentError
        nil
      end
    end

    module_function

    def current
      @current ||= Patch.new
    end

    def string(text)
      current.string(text)
    end
  end
end
