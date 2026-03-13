# frozen_string_literal: true

module RubyRaider
  # Displays the Ruby Raider logo as colored pixel art in the terminal.
  # Renders a faceted gem icon alongside "RUBY RAIDER" in a pixel font,
  # using Unicode half-block characters for compact, high-detail output.
  module Logo
    # Color palette: 0 = empty, 1 = dark, 2 = medium, 3 = bright
    PALETTE = {
      1 => '130;30;48',
      2 => '180;45;65',
      3 => '230;70;90'
    }.freeze

    # Gem diamond with faceted shading (6 pixel rows × 9 cols)
    GEM = [
      [0, 0, 0, 3, 3, 3, 0, 0, 0],
      [0, 2, 3, 3, 3, 3, 3, 2, 0],
      [2, 3, 2, 3, 3, 3, 2, 3, 2],
      [2, 2, 1, 2, 2, 2, 1, 2, 2],
      [0, 1, 2, 1, 1, 1, 2, 1, 0],
      [0, 0, 0, 1, 1, 1, 0, 0, 0]
    ].freeze

    # 5-row pixel font glyphs
    GLYPHS = {
      'R' => [[1, 1, 1, 0], [1, 0, 0, 1], [1, 1, 1, 0], [1, 0, 1, 0], [1, 0, 0, 1]],
      'U' => [[1, 0, 0, 1], [1, 0, 0, 1], [1, 0, 0, 1], [1, 0, 0, 1], [0, 1, 1, 0]],
      'B' => [[1, 1, 1, 0], [1, 0, 0, 1], [1, 1, 1, 0], [1, 0, 0, 1], [1, 1, 1, 0]],
      'Y' => [[1, 0, 0, 1], [1, 0, 0, 1], [0, 1, 1, 0], [0, 0, 1, 0], [0, 0, 1, 0]],
      ' ' => [[0, 0], [0, 0], [0, 0], [0, 0], [0, 0]],
      'A' => [[0, 1, 1, 0], [1, 0, 0, 1], [1, 1, 1, 1], [1, 0, 0, 1], [1, 0, 0, 1]],
      'I' => [[1, 1, 1], [0, 1, 0], [0, 1, 0], [0, 1, 0], [1, 1, 1]],
      'D' => [[1, 1, 1, 0], [1, 0, 0, 1], [1, 0, 0, 1], [1, 0, 0, 1], [1, 1, 1, 0]],
      'E' => [[1, 1, 1, 1], [1, 0, 0, 0], [1, 1, 1, 0], [1, 0, 0, 0], [1, 1, 1, 1]]
    }.freeze

    TEXT_COLOR = 3

    def self.display
      text_rows = build_text('RUBY RAIDER')
      text_width = text_rows.first.length

      # Build 6-row text grid: blank top row centers text vertically with gem
      text_grid = [Array.new(text_width, 0)]
      text_rows.each { |row| text_grid << row.map { |px| px == 1 ? TEXT_COLOR : 0 } }

      # Compose: gem(9) + gap(2) + text
      grid = 6.times.map { |y| GEM[y] + [0, 0] + text_grid[y] }

      # Render 3 terminal rows (each encodes 2 pixel rows via half-blocks)
      3.times do |tr|
        line = +''
        top = grid[tr * 2]
        bot = grid[tr * 2 + 1]
        top.length.times { |x| line << halfblock(top[x], bot[x]) }
        puts "  #{line.rstrip}"
      end
      puts
    end

    def self.halfblock(top, bot)
      return ' ' if top.zero? && bot.zero?
      return "\e[38;2;#{PALETTE[top]}m█\e[0m" if top == bot
      return "\e[38;2;#{PALETTE[bot]}m▄\e[0m" if top.zero?
      return "\e[38;2;#{PALETTE[top]}m▀\e[0m" if bot.zero?

      "\e[38;2;#{PALETTE[top]};48;2;#{PALETTE[bot]}m▀\e[0m"
    end

    def self.build_text(str)
      rows = Array.new(5) { [] }
      str.each_char.with_index do |ch, i|
        glyph = GLYPHS.fetch(ch.upcase, GLYPHS[' '])
        5.times { |r| rows[r].push(0, 0) } if i.positive?
        5.times { |r| rows[r].concat(glyph[r]) }
      end
      rows
    end

    private_class_method :halfblock, :build_text
  end
end
