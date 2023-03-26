# frozen_string_literal: true
require_relative 'base_screen'
require_relative '../generators/invoke_generators'

class InstallationScreen < BaseScreen
  include InvokeGenerators

  attr_accessor :entry_text

  def launch
    window('Ruby Raider', 1240, 800) {
      margined true

      horizontal_box {
        #area {
        #image(File.expand_path('/Users/apeque01/Desktop/main_folder/Projects/Open source/ruby_raider/logo_transparent_background-1.png', __dir__), width: 400, height: 600)
        #}

        grid {
          padded true
          stretchy true
          label('Project Name') {
            top 0
            halign :center
          }

          entry {
            top 1
            halign :center
            # stretchy true # Smart default option for appending to horizontal_box
            text <=> [self, :entry_text, after_write: ->(text) { @project_name = text; $stdout.flush }] # bidirectional data-binding between text property and entry_text attribute, printing after write to model.
          }

          @radio = radio_buttons {
            top 2
            halign :center
            items 'Web', 'Mobile'
            selected_item 'Web'
            on_selected do |buttons|
              if buttons.selected_item == 'Web'
                @mobile_automation.hide
                @platforms.hide
                @web_automation.show
              else
                @web_automation.hide
                @mobile_automation.show
                @platforms.show
              end
            end
          }

          @mobile_automation = combobox {
            top 3
            halign :center
            visible false
            items 'Appium'
            selected_item 'Appium'
          }

          @web_automation = combobox {
            top 3
            halign :center
            visible true
            items 'Selenium', 'Watir'
            selected_item 'Selenium'
          }

          @platforms = combobox {
            top 4
            halign :center
            visible false
            items 'Android', 'iOS', 'Cross-Platform'
            selected_item 'iOS'
          }

          @framework = combobox {
            top 5
            halign :center
            visible true
            items 'Cucumber', 'Rspec'
            selected_item 'Cucumber'

            on_selected do |items|
              if items.selected_item == 'Rspec' && @radio.selected_item != 'Mobile'
                @visual_checkbox.show
              else
                @visual_checkbox.hide
              end
            end
          }

          @visual_checkbox = checkbox('Applitools integration') {
            visible false
            top 6
            xspan 4
            halign :center
          }

          @example_checkbox = checkbox('Add example files') {
            visible true
            top 7
            xspan 4
            halign :center
          }

          button('Create Project') {
            top 8
            halign :center
            on_clicked do
              automation = if @web_automation.visible?
                             @web_automation.selected_item
                           else
                             @mobile_automation.selected_item
                           end
              structure = {
                automation: automation,
                framework: @framework.selected_item,
                generators: %w[Automation Common Helpers],
                name: @project_name,
                visual: @visual_checkbox.checked
              }
              generate_framework(structure)
            end
          }
        }
      }
    }.show
  end
end
