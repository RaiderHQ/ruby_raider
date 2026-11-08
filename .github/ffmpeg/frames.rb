# frozen_string_literal: true

# Writes sample "screenshots" and the concat list the generated VideoHelper builds:
#   ruby frames.rb <dir> [width] [height] [count]
# RGBA PNGs with odd dimensions (so scale='min(1280,iw)':-2 has to round), stdlib only.
require 'zlib'

dir, width, height, count = ARGV
width = (width || 1366).to_i
height = (height || 657).to_i
count = (count || 12).to_i

def chunk(type, data)
  [data.bytesize].pack('N') + type + data + [Zlib.crc32(type + data)].pack('N')
end

def png(width, height, shift)
  rows = Array.new(height) do |y|
    row = Array.new(width) do |x|
      [(x + shift * 20) % 256, (y + shift * 7) % 256, (x ^ y) % 256, 255].pack('C4')
    end
    "\x00#{row.join}"
  end
  "\x89PNG\r\n\x1A\n".b +
    chunk('IHDR', [width, height, 8, 6, 0, 0, 0].pack('NNCCCCC')) +
    chunk('IDAT', Zlib::Deflate.deflate(rows.join, 1)) +
    chunk('IEND', '')
end

# Same shape as VideoHelper#concat_list: each frame lasts until the next, clamped to [1/fps, 2.0].
names = Array.new(count) { |i| format('frame-%06d.png', i + 1) }
names.each_with_index { |name, i| File.binwrite(File.join(dir, name), png(width, height, i)) }
lines = names.each_with_index.flat_map { |name, i| ["file '#{name}'", format('duration %.3f', i.even? ? 0.2 : 1.1)] }
File.write(File.join(dir, 'list.txt'), (lines << "file '#{names.last}'").join("\n") << "\n")
