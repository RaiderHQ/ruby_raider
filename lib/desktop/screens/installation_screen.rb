# frozen_string_literal: true

require_relative '../components/installation_components'
require_relative '../../generators/invoke_generators'

class InstallationScreen < InstallationComponents
  include InvokeGenerators

  attr_accessor :entry_text

  def launch
    window('Ruby Raider', 800, 600) do
      margined true
      tab do
        tab_item('Installer') do
          vertical_box do
            project_name_field

            vertical_box do
              stretchy false

              @automation = automation_options
              @mobile = mobile_dropdown_options
              @web = web_dropdown_options
              @platforms = mobile_platforms_dropdown
              @framework = frameworks_dropdown
              @visual = visual_checkbox
              @example = example_checkbox

              button_name = File.directory?('spec') ? 'Open the test runner' : 'Create Project'
              button_component(button_name)
            end
            installation_results
          end
        end
      end
    end.show
  end
end
