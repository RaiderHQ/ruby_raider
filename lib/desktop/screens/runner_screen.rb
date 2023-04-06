# frozen_string_literal: true

require_relative '../components/runner_components'

class RunnerScreen < RunnerComponents
  def launch
    window('Ruby Raider', 1200, 800) do
      margined true
      vertical_box do
        header
        tab do
          stretchy true
          tests_tab
          config_tab
          caps_tab
          editor_tab
        end
      end
    end.show
  end
end
