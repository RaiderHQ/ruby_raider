require 'glimmer-dsl-libui'

module HeaderBar
  include Glimmer

  def add_header
    grid do
      stretchy false

      button('▶') do
        left 0
        on_clicked do
          output = Open3.popen3("#{@framework} #{@tests.selected_item}") do |_stdin, stdout, _stderr|
            stdout.read
          end
          system "rspec #{@tests.selected_item}"
          @results.text = output
        end
      end
      button('■') do
        left 1
        on_clicked do
          pp 'stop'
        end
      end

      @tests = combobox do
        left 2
        files = Dir.glob(File.join(@folder, @extension))
        items files
        selected_item files.first
        @file = File.open(files.first)

        on_selected do |items|
          @results.text = ''
          path = items.selected_item
          @file = File.open(path)
          @text_box.text = @file.read
        end
      end

      button('Open Dashboard') do
        left 3
        halign :end
        on_clicked do
          pp 'stop'
        end
      end
    end
  end
end
