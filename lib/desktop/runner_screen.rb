# frozen_string_literal: true

require 'yaml'
require_relative 'base_screen'

class RunnerScreen < BaseScreen
  attr_accessor :contacts

  CONFIG_ITEM = Struct.new(:attribute, :value)
  CAP = Struct.new(:attribute, :value)
  TEST = Struct.new(:file_name)

  window('Ruby Raider', 800, 400) do
    margined true

    vertical_box do
      grid do
        stretchy false

        button('▶') do
          top 0
          halign :left
          on_clicked do
            pp 'None selected'
            @tests
          end
        end
        button('■') do
          top 0
          left 1
          halign :left
          on_clicked do
            pp 'stop'
          end
        end
      end

      tab do
        stretchy true

        tab_item('Tests') do
          files = Dir.glob(File.join('spec', '*_spec.rb'))
          tests = files.map { |file| TEST.new(file) }
          vertical_box do
            @tests = refined_table(
              model_array: tests,
              table_columns: {
                'File Name' => :text
              },
              table_editable: false,
              per_page: 20
            )
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
