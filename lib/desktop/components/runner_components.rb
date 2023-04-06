require 'open3'
require 'yaml'
require_relative 'base_component'

class RunnerComponents < BaseComponent
  attr_accessor :contacts

  CONFIG_ITEM = Struct.new(:attribute, :value)
  CAP = Struct.new(:attribute, :value)

  def header
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
          pp 'The stop feature will be implemented in a later release'
        end
      end

      @tests = combobox do
        left 2
        files = Dir.glob(File.join(@folder, @extension))
        multiple_items = files.count.positive? ? files : ['There are no tests please create a new one']
        items multiple_items
        selected_item files.first
        @file = files.count.positive? ? File.open(files.first) : ''

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
          system 'allure serve allure-reports'
        end
      end
    end
  end

  def tests_tab
    tab_item('Tests') do
      horizontal_box do
        @text_box = multiline_entry do
          text @file

          on_changed do |e|
            File.write(@tests.selected_item, e.text)
            $stdout.flush # for Windows
          end
        end

        @results = multiline_entry do
          text ''
        end
      end
    end
  end

  def config_tab
    tab_item('Configuration') do
      if File.exist?('config/config.yml')
        @config = YAML.load_file('config/config.yml')
        @config_items = @config.map { |key, value| CONFIG_ITEM.new(key, value) }
      else
        @config_items = [CONFIG_ITEM.new('Create a config file to access your attributes', '')]
      end
      vertical_box do
        refined_table(
          model_array: @config_items,
          table_columns: {
            'Attribute' => :text,
            'Value' => { text: { editable: true } }
          },
          table_editable: true,
          per_page: 20
        )
      end
    end
  end

  def caps_tab
    tab_item('Capabilities') do
      caps = File.exist?('config/capabilities.yml') ? YAML.load_file('config/capabilities.yml') : []
      caps = caps.map { |key, value| CAP.new(key, value) }
      vertical_box do
        refined_table(
          model_array: caps,
          table_columns: {
            'Attribute' => :text,
            'Value' => { text: { editable: true } }
          },
          table_editable: true,
          per_page: 20
        )
      end
    end
  end

  def editor_tab
    tab_item('Editor') do
      horizontal_box do
        vertical_box do
          horizontal_box do
            button('Create Test') do
              on_clicked do
                pp 'stop'
              end
            end
            entry do
              text 'hello'
            end
          end
          horizontal_box do
            button('Create Page') do
              on_clicked do
                pp 'stop'
              end
            end
            entry do
              text 'hello'
            end
          end
          horizontal_box do
            button('Create Component') do
              on_clicked do
                pp 'stop'
              end
            end
            entry do
              text 'hello'
            end
          end
          vertical_separator do
            stretchy false
          end
        end
        vertical_box do
          combobox do
            stretchy false
            visible true
            items 'Cucumber', 'Rspec'
            selected_item 'Cucumber'
          end
          multiline_entry do
            text 'hello'
          end
        end
      end
    end
  end
end
