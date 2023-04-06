require_relative 'base_component'

class InstallationComponents < BaseComponent
  def visual_checkbox
    checkbox('Applitools integration') do
      stretchy false
      visible false
    end
  end

  def example_checkbox
    checkbox('Add example files') do
      stretchy false
      visible true
    end
  end

  def automation_options
    radio_buttons do
      stretchy false

      items 'Web', 'Mobile'
      selected_item 'Web'
      on_selected do |buttons|
        if buttons.selected_item == 'Web'
          @mobile.hide
          @platforms.hide
          @web.show
        else
          @web.hide
          @mobile.show
          @platforms.show
        end
      end
    end
  end

  def web_dropdown_options
    combobox do
      stretchy false
      visible true
      items 'Selenium', 'Watir'
      selected_item 'Selenium'
    end
  end

  def mobile_dropdown_options
    combobox do
      stretchy false
      visible false
      items 'Appium'
      selected_item 'Appium'
    end
  end

  def mobile_platforms_dropdown
    combobox do
      stretchy false
      visible false
      items 'Android', 'iOS', 'Cross-Platform'
      selected_item 'iOS'
    end
  end

  def frameworks_dropdown
    combobox do
      stretchy false
      visible true
      items 'Cucumber', 'Rspec'
      selected_item 'Cucumber'

      on_selected do |items|
        if items.selected_item == 'Rspec' && automation.selected_item != 'Mobile'
          @visual.show
        else
          @visual.hide
        end
      end
    end
  end

  def button_component(name)
    button(name) do
      stretchy false
      on_clicked do
        if File.directory?('spec')
          RunnerScreen.new.launch
          pp window.methods
        else
          automation = if @web.visible?
                         @web.selected_item
                       else
                         @mobile.selected_item
                       end
          structure = {
            automation: automation,
            examples: @example.checked,
            framework: @framework.selected_item,
            generators: %w[Automation Common Helpers],
            name: @project_name,
            visual: @visual.checked
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
  end

  def installation_results
    vertical_box do
      stretchy false
      @installation_box = multiline_entry do
        stretchy false
        message = if File.directory?('spec')
                    'You have already installed Ruby Raider, please click the "Open test runner" button, to run your tests'
                  else
                    'Your installation result will appear here...'
                  end
        text message
        $stdout.flush
      end
    end
  end

  def project_name_field
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
  end
end
