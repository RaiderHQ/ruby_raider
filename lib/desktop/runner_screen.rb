# frozen_string_literal: true

require 'open3'
require 'yaml'
require_relative 'base_screen'

class RunnerScreen < BaseScreen
  attr_accessor :contacts

  CONFIG_ITEM = Struct.new(:attribute, :value)
  CAP = Struct.new(:attribute, :value)

  if File.directory?('spec')
    @folder = 'spec'
    @framework = 'rspec'
    @extension = '*_spec.rb'
  else
    @folder = 'features'
    @framework = 'cucumber'
    @extension = '*.features'
  end

  window('Ruby Raider', 1200, 800) do
    margined true
    vertical_box do
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
          files = Dir.glob(File.join(@folder, @extension)) || ['No Files are created']
          items files
          selected_item files.first
          @file = File.open(files.first) unless files.first == 'No Files are created'

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

      tab do
        stretchy true

        tab_item('Tests') do
          horizontal_box do
            @text_box = multiline_entry do
              text @file.read

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

        tab_item('Configuration') do
          @config = YAML.load_file('config/config.yml')
          config_items = @config.map { |key, value| CONFIG_ITEM.new(key, value) }
          vertical_box do
            refined_table(
              model_array: config_items,
              table_columns: {
                'Attribute' => :text,
                'Value' => { text: { editable: true } }
              },
              table_editable: true,
              per_page: 20
            )
          end
        end
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
    end
  end.show
end