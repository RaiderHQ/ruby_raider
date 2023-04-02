# frozen_string_literal: true

require_relative 'base_screen'
require_relative '../generators/invoke_generators'

class InstallationScreen < BaseScreen
  include InvokeGenerators

  attr_accessor :entry_text

  def launch
    window('Ruby Raider', 800, 600) do
      margined true
      tab do
        tab_item('Installer') do
          vertical_box do
            vertical_box do
              stretchy false
              label('Project Name') do
                stretchy false
              end

              entry do
                stretchy false # Smart default option for appending to horizontal_box
                text <=> [self, :entry_text, { after_write: lambda { |text|
                  @project_name = text
                  $stdout.flush
                } }] # bidirectional data-binding between text property and entry_text attribute, printing after write to model.
              end
            end

            vertical_box do
              stretchy false

              @radio = radio_buttons do
                stretchy false

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
              end

              @mobile_automation = combobox do
                stretchy false
                visible false
                items 'Appium'
                selected_item 'Appium'
              end

              @web_automation = combobox do
                stretchy false
                visible true
                items 'Selenium', 'Watir'
                selected_item 'Selenium'
              end

              @platforms = combobox do
                stretchy false
                visible false
                items 'Android', 'iOS', 'Cross-Platform'
                selected_item 'iOS'
              end

              @framework = combobox do
                stretchy false
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
              end

              @visual_checkbox = checkbox('Applitools integration') do
                stretchy false
                visible false
              end

              @example_checkbox = checkbox('Add example files') do
                stretchy false
                visible true
              end

              button('Create Project') do
                stretchy false
                on_clicked do
                  automation = if @web_automation.visible?
                                 @web_automation.selected_item
                               else
                                 @mobile_automation.selected_item
                               end
                  structure = {
                    automation: automation,
                    examples: @example_checkbox.checked,
                    framework: @framework.selected_item,
                    generators: %w[Automation Common Helpers],
                    name: @project_name,
                    visual: @visual_checkbox.checked
                  }
                  generate_framework(structure)
                  @installation_box.text = if File.directory?(@project_name)
                                             "Your project has been created, close this window, go to the folder #{@project_name} and run 'raider open'"
                                           else
                                             'There was a problem creating your project try again'
                                           end
                end
              end
            end
            vertical_box do
              stretchy false
              @installation_box = multiline_entry do
                stretchy false
                text 'Your installation result will appear here...'
                $stdout.flush
              end
            end
          end
        end
      end
    end.show
  end
end
